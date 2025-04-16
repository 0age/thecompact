// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { SplitTransfer } from "../types/Claims.sol";
import { SplitBatchTransfer } from "../types/BatchClaims.sol";
import { ResetPeriod } from "../types/ResetPeriod.sol";

import {
    TransferComponent, SplitComponent, SplitByIdComponent, SplitBatchClaimComponent
} from "../types/Components.sol";

import { EfficiencyLib } from "./EfficiencyLib.sol";
import { EventLib } from "./EventLib.sol";
import { HashLib } from "./HashLib.sol";
import { IdLib } from "./IdLib.sol";
import { RegistrationLib } from "./RegistrationLib.sol";
import { ValidityLib } from "./ValidityLib.sol";
import { TransferLib } from "./TransferLib.sol";

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

/**
 * @title ComponentLib
 * @notice Library contract implementing internal functions with helper logic for
 * processing claims that incorporate split and/or batch components.
 * @dev IMPORTANT NOTE: logic for processing claims assumes that the utilized structs are
 * formatted in a very specific manner — if parameters are rearranged or new parameters
 * are inserted, much of this functionality will break. Proceed with caution when making
 * any changes.
 */
library ComponentLib {
    using TransferLib for address;
    using ComponentLib for SplitComponent[];
    using EfficiencyLib for bool;
    using EfficiencyLib for ResetPeriod;
    using EfficiencyLib for uint256;
    using EfficiencyLib for bytes32;
    using EventLib for address;
    using HashLib for uint256;
    using IdLib for uint256;
    using IdLib for ResetPeriod;
    using ValidityLib for uint256;
    using ValidityLib for uint96;
    using ValidityLib for bytes32;
    using RegistrationLib for address;
    using FixedPointMathLib for uint256;

    error Overflow();
    error NoIdsAndAmountsProvided();

    /**
     * @notice Internal function for performing a set of split transfers or withdrawals.
     * Executes the transfer or withdrawal operation targeting multiple recipients from
     * a single resource lock.
     * @param transfer  A SplitTransfer struct containing split transfer details.
     * @return          Whether the transfer was successfully processed.
     */
    function processSplitTransfer(SplitTransfer calldata transfer) internal returns (bool) {
        // Process the transfer for each split component.
        _processSplitTransferComponents(transfer.recipients, transfer.id);

        return true;
    }

    /**
     * @notice Internal function for performing a set of split batch transfers or withdrawals.
     * Executes the transfer or withdrawal operation for multiple recipients from multiple
     * resource locks.
     * @param transfer  A SplitBatchTransfer struct containing split batch transfer details.
     */
    function performSplitBatchTransfer(SplitBatchTransfer calldata transfer) internal {
        // Navigate to the split batch components array in calldata.
        SplitByIdComponent[] calldata transfers = transfer.transfers;

        // Retrieve the total number of components.
        uint256 totalIds = transfers.length;

        unchecked {
            // Iterate over each component in calldata.
            for (uint256 i = 0; i < totalIds; ++i) {
                // Navigate to location of the component in calldata.
                SplitByIdComponent calldata component = transfers[i];

                // Process transfer for each split component in the set.
                _processSplitTransferComponents(component.portions, component.id);
            }
        }
    }

    /**
     * @notice Internal function for processing qualified split claims with potentially exogenous
     * sponsor signatures. Extracts claim parameters from calldata, validates the claim,
     * validates the scope, and executes either releases of ERC6909 tokens or withdrawals of
     * underlying tokens to multiple recipients.
     * @param messageHash              The EIP-712 hash of the claim message.
     * @param calldataPointer          Pointer to the location of the associated struct in calldata.
     * @param offsetToId               Offset to segment of calldata where relevant claim parameters begin.
     * @param sponsorDomainSeparator   The domain separator for the sponsor's signature, or zero for non-exogenous claims.
     * @param typehash                 The EIP-712 typehash used for the claim message.
     * @param domainSeparator          The local domain separator.
     * @param validation               Function pointer to the _validate function.
     */
    function processClaimWithSplitComponents(
        bytes32 messageHash,
        uint256 calldataPointer,
        uint256 offsetToId,
        bytes32 sponsorDomainSeparator,
        bytes32 typehash,
        bytes32 domainSeparator,
        function(bytes32, uint96, uint256, bytes32, bytes32, bytes32, uint256[2][] memory, uint256) internal returns (address)
            validation
    ) internal {
        // Declare variables for parameters that will be extracted from calldata.
        uint256 id;
        uint256 allocatedAmount;
        SplitComponent[] calldata components;

        assembly ("memory-safe") {
            // Calculate pointer to claim parameters using provided offset.
            let calldataPointerWithOffset := add(calldataPointer, offsetToId)

            // Extract resource lock id and allocated amount.
            id := calldataload(calldataPointerWithOffset)
            allocatedAmount := calldataload(add(calldataPointerWithOffset, 0x20))

            // Extract array of split components containing claimant addresses and amounts.
            let componentsPtr := add(calldataPointer, calldataload(add(calldataPointerWithOffset, 0x40)))
            components.offset := add(0x20, componentsPtr)
            components.length := calldataload(componentsPtr)
        }

        // Initialize idsAndAmounts array.
        uint256[2][] memory idsAndAmounts = new uint256[2][](1);
        idsAndAmounts[0] = [id, allocatedAmount];

        // Validate the claim and extract the sponsor address.
        address sponsor = validation(
            messageHash,
            id.toAllocatorId(),
            calldataPointer,
            domainSeparator,
            sponsorDomainSeparator,
            typehash,
            idsAndAmounts,
            id.toResetPeriod().toSeconds()
        );

        // Verify the resource lock scope is compatible with the provided domain separator.
        sponsorDomainSeparator.ensureValidScope(id);

        // Process each split component, verifying total amount and executing operations.
        components.verifyAndProcessSplitComponents(sponsor, id, allocatedAmount);
    }

    /**
     * @notice Internal function for processing qualified split batch claims with potentially
     * exogenous sponsor signatures. Extracts split batch claim parameters from calldata,
     * validates the claim, and executes split operations for each resource lock. Uses optimized
     * validation of allocator consistency and scopes, with explicit validation on failure to
     * identify specific issues. Each resource lock can be split among multiple recipients.
     * @param messageHash              The EIP-712 hash of the claim message.
     * @param calldataPointer          Pointer to the location of the associated struct in calldata.
     * @param offsetToId               Offset to segment of calldata where relevant claim parameters begin.
     * @param sponsorDomainSeparator   The domain separator for the sponsor's signature, or zero for non-exogenous claims.
     * @param typehash                 The EIP-712 typehash used for the claim message.
     * @param domainSeparator          The local domain separator.
     * @param validation               Function pointer to the _validate function.
     */
    function processClaimWithSplitBatchComponents(
        bytes32 messageHash,
        uint256 calldataPointer,
        uint256 offsetToId,
        bytes32 sponsorDomainSeparator,
        bytes32 typehash,
        bytes32 domainSeparator,
        function(bytes32, uint96, uint256, bytes32, bytes32, bytes32, uint256[2][] memory, uint256) internal returns (address)
            validation
    ) internal {
        // Declare variable for SplitBatchClaimComponent array that will be extracted from calldata.
        SplitBatchClaimComponent[] calldata claims;
        assembly ("memory-safe") {
            // Extract array of split batch claim components.
            let claimsPtr := add(calldataPointer, calldataload(add(calldataPointer, offsetToId)))
            claims.offset := add(0x20, claimsPtr)
            claims.length := calldataload(claimsPtr)
        }

        // Parse into idsAndAmounts & extract shortest reset period & first allocatorId.
        (uint256[2][] memory idsAndAmounts, uint96 firstAllocatorId, uint256 shortestResetPeriod) =
            _buildIdsAndAmounts(claims, sponsorDomainSeparator);

        // Validate the claim and extract the sponsor address.
        address sponsor = validation(
            messageHash,
            firstAllocatorId,
            calldataPointer,
            domainSeparator,
            sponsorDomainSeparator,
            typehash,
            idsAndAmounts,
            shortestResetPeriod.asResetPeriod().toSeconds()
        );

        unchecked {
            // Process each claim component.
            for (uint256 i = 0; i < idsAndAmounts.length; ++i) {
                SplitBatchClaimComponent calldata claimComponent = claims[i];

                // Process each split component, verifying total amount and executing operations.
                claimComponent.portions.verifyAndProcessSplitComponents(
                    sponsor, claimComponent.id, claimComponent.allocatedAmount
                );
            }
        }
    }

    function _buildIdsAndAmounts(SplitBatchClaimComponent[] calldata claims, bytes32 sponsorDomainSeparator)
        internal
        pure
        returns (uint256[2][] memory idsAndAmounts, uint96 firstAllocatorId, uint256 shortestResetPeriod)
    {
        uint256 totalClaims = claims.length;
        if (totalClaims == 0) {
            revert NoIdsAndAmountsProvided();
        }

        // Extract allocator id and amount from first claim for validation.
        SplitBatchClaimComponent calldata claimComponent = claims[0];
        uint256 id = claimComponent.id;
        firstAllocatorId = id.toAllocatorId();
        shortestResetPeriod = id.toResetPeriod().asUint256();

        // Initialize idsAndAmounts array and register the first element.
        idsAndAmounts = new uint256[2][](totalClaims);
        idsAndAmounts[0] = [id, claimComponent.allocatedAmount];

        // Initialize error tracking variable.
        uint256 errorBuffer = id.scopeNotMultichain(sponsorDomainSeparator).asUint256();

        unchecked {
            // Register each additional element & accumulate potential errors.
            for (uint256 i = 1; i < totalClaims; ++i) {
                claimComponent = claims[i];
                id = claimComponent.id;

                shortestResetPeriod = shortestResetPeriod.min(id.toResetPeriod().asUint256());

                errorBuffer |= (id.toAllocatorId() != firstAllocatorId).or(
                    id.scopeNotMultichain(sponsorDomainSeparator)
                ).asUint256();

                // Include the id and amount in idsAndAmounts.
                idsAndAmounts[i] = [id, claimComponent.allocatedAmount];
            }

            // Revert if any errors occurred.
            _revertWithInvalidBatchAllocationIfError(errorBuffer);
        }
    }

    /**
     * @notice Internal function for verifying and processing split components. Ensures that the
     * sum of split amounts doesn't exceed the allocated amount, checks for arithmetic overflow,
     * and executes the specified operation for each split recipient. Reverts if the total
     * claimed amount exceeds the allocation or if arithmetic overflow occurs during summation.
     * @param claimants       Array of split components specifying recipients and their amounts.
     * @param sponsor         The address of the claim sponsor.
     * @param id              The ERC6909 token identifier of the resource lock.
     * @param allocatedAmount The total amount allocated for this claim.
     */
    function verifyAndProcessSplitComponents(
        SplitComponent[] calldata claimants,
        address sponsor,
        uint256 id,
        uint256 allocatedAmount
    ) internal {
        // Initialize tracking variables.
        uint256 totalClaims = claimants.length;
        uint256 spentAmount = 0;
        uint256 errorBuffer = (totalClaims == 0).asUint256();

        unchecked {
            // Process each split component while tracking total amount and checking for overflow.
            for (uint256 i = 0; i < totalClaims; ++i) {
                SplitComponent calldata component = claimants[i];
                uint256 amount = component.amount;

                // Track total amount claimed, checking for overflow.
                uint256 updatedSpentAmount = amount + spentAmount;
                errorBuffer |= (updatedSpentAmount < spentAmount).asUint256();
                spentAmount = updatedSpentAmount;

                sponsor.performOperation(id, component.claimant, amount);
            }
        }

        // Revert if an overflow occurred or if total claimed amount exceeds allocation.
        errorBuffer |= (allocatedAmount < spentAmount).asUint256();
        assembly ("memory-safe") {
            if errorBuffer {
                // revert AllocatedAmountExceeded(allocatedAmount, amount);
                mstore(0, 0x3078b2f6)
                mstore(0x20, allocatedAmount)
                mstore(0x40, spentAmount)
                revert(0x1c, 0x44)
            }
        }
    }

    /**
     * @notice Internal pure function for summing all amounts in a SplitComponent array.
     * @param recipients A SplitComponent struct array containing split transfer details.
     * @return sum Total amount across all components.
     */
    function aggregate(SplitComponent[] calldata recipients) internal pure returns (uint256 sum) {
        // Retrieve the total number of components.
        uint256 totalSplits = recipients.length;

        uint256 errorBuffer;
        uint256 amount;
        unchecked {
            // Iterate over each additional component in calldata.
            for (uint256 i = 0; i < totalSplits; ++i) {
                amount = recipients[i].amount;
                sum += amount;
                errorBuffer |= (sum < amount).asUint256();
            }
        }

        if (errorBuffer.asBool()) {
            revert Overflow();
        }
    }

    /**
     * @notice Private function for performing a set of split transfers or withdrawals
     * given an array of split components and an ID for an associated resource lock.
     * Executes the transfer or withdrawal operation targeting multiple recipients.
     * @param recipients A SplitComponent struct array containing split transfer details.
     * @param id         The ERC6909 token identifier of the resource lock.
     */
    function _processSplitTransferComponents(SplitComponent[] calldata recipients, uint256 id) private {
        // Retrieve the total number of components.
        uint256 totalSplits = recipients.length;

        unchecked {
            // Iterate over each additional component in calldata.
            for (uint256 i = 0; i < totalSplits; ++i) {
                // Navigate to location of the component in calldata.
                SplitComponent calldata component = recipients[i];

                // Perform the transfer or withdrawal for the portion.
                msg.sender.performOperation(id, component.claimant, component.amount);
            }
        }
    }

    /**
     * @notice Private pure function that reverts with an InvalidBatchAllocation error
     * if an error buffer is nonzero.
     * @param errorBuffer The error buffer to check.
     */
    function _revertWithInvalidBatchAllocationIfError(uint256 errorBuffer) private pure {
        // Revert if any errors occurred.
        assembly ("memory-safe") {
            if errorBuffer {
                // revert InvalidBatchAllocation()
                mstore(0, 0x3a03d3bb)
                revert(0x1c, 0x04)
            }
        }
    }
}
