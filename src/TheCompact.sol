// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITheCompact } from "./interfaces/ITheCompact.sol";

import { AllocatedBatchTransfer } from "./types/BatchClaims.sol";
import { AllocatedTransfer } from "./types/Claims.sol";
import { CompactCategory } from "./types/CompactCategory.sol";
import { Lock } from "./types/Lock.sol";
import { Scope } from "./types/Scope.sol";
import { ResetPeriod } from "./types/ResetPeriod.sol";
import { ForcedWithdrawalStatus } from "./types/ForcedWithdrawalStatus.sol";
import { EmissaryStatus } from "./types/EmissaryStatus.sol";
import { DepositDetails } from "./types/DepositDetails.sol";

import { TheCompactLogic } from "./lib/TheCompactLogic.sol";

import { ERC6909 } from "solady/tokens/ERC6909.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

// TODO: refactor these into logic files
import { EfficiencyLib } from "./lib/EfficiencyLib.sol";
import { HashLib } from "./lib/HashLib.sol";
import { ValidityLib } from "./lib/ValidityLib.sol";
import { IdLib } from "./lib/IdLib.sol";
import { RegistrationLib } from "./lib/RegistrationLib.sol";
import { BenchmarkERC20 } from "./lib/BenchmarkERC20.sol";
import { TransferBenchmarkLib } from "./lib/TransferBenchmarkLib.sol";

/**
 * @title The Compact
 * @custom:version 1
 * @author 0age (0age.eth)
 * @notice The Compact is an ownerless ERC6909 contract that facilitates the voluntary
 *         formation and mediation of reusable "resource locks."
 *         This contract has not yet been properly tested, audited, or reviewed.
 */
contract TheCompact is ITheCompact, ERC6909, TheCompactLogic {
    using ValidityLib for address;
    using ValidityLib for bytes32;
    using IdLib for address;
    using IdLib for uint96;
    using IdLib for uint256;
    using RegistrationLib for address;
    using EfficiencyLib for bool;
    using EfficiencyLib for address;
    using EfficiencyLib for uint256;
    using TransferBenchmarkLib for address;
    using TransferBenchmarkLib for bytes32;

    // Declare an immutable argument for the account of the benchmark ERC20 token.
    address private immutable _BENCHMARK_ERC20;

    constructor() {
        // Deploy reference ERC20 for benchmarking generic ERC20 token withdrawals. Note
        // that benchmark cannot be evaluated as part of contract creation as it requires
        // that the token account is not already warm as part of deriving the benchmark.
        _BENCHMARK_ERC20 = address(new BenchmarkERC20());
    }

    function depositNative(bytes12 lockTag, address recipient) external payable returns (uint256) {
        return _performCustomNativeTokenDeposit(lockTag, recipient.usingCallerIfNull());
    }

    function depositERC20(address token, bytes12 lockTag, uint256 amount, address recipient)
        external
        returns (uint256 id)
    {
        (id,) = _performCustomERC20Deposit(token, lockTag, amount, recipient.usingCallerIfNull());
    }

    function batchDeposit(uint256[2][] calldata idsAndAmounts, address recipient) external payable returns (bool) {
        _processBatchDeposit(idsAndAmounts, recipient.usingCallerIfNull(), false);

        return true;
    }

    function depositERC20ViaPermit2(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        address, // depositor
        bytes12, // lockTag
        address recipient,
        bytes calldata signature
    ) external returns (uint256) {
        return _depositViaPermit2(permit.permitted.token, recipient, signature);
    }

    function batchDepositViaPermit2(
        address, // depositor
        ISignatureTransfer.TokenPermissions[] calldata permitted,
        DepositDetails calldata,
        address recipient,
        bytes calldata signature
    ) external payable returns (uint256[] memory) {
        return _depositBatchViaPermit2(permitted, recipient, signature);
    }

    function allocatedTransfer(AllocatedTransfer calldata transfer) external returns (bool) {
        return _processSplitTransfer(transfer);
    }

    function allocatedBatchTransfer(AllocatedBatchTransfer calldata transfer) external returns (bool) {
        return _processSplitBatchTransfer(transfer);
    }

    function register(bytes32 claimHash, bytes32 typehash) external returns (bool) {
        _register(msg.sender, claimHash, typehash);

        return true;
    }

    function registerMultiple(bytes32[2][] calldata claimHashesAndTypehashes) external returns (bool) {
        return _registerBatch(claimHashesAndTypehashes);
    }

    function registerFor(
        address sponsor,
        address token,
        bytes12 lockTag,
        uint256 amount,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 typehash,
        bytes32 witness,
        bytes calldata sponsorSignature
    ) external returns (uint256 id, bytes32 claimHash) {
        // Derive resource lock ID using provided token, parameters, and allocator.
        id = token.excludingNative().toIdIfRegistered(lockTag);

        claimHash =
            HashLib.toFlatMessageHashWithWitness(sponsor, id, amount, arbiter, nonce, expires, typehash, witness);

        {
            // Initialize idsAndAmounts array.
            uint256[2][] memory idsAndAmounts = new uint256[2][](1);
            idsAndAmounts[0] = [id, amount];

            // TODO: support registering exogenous domain separators by passing notarized chainId?
            claimHash.hasValidSponsor(sponsor, sponsorSignature, _domainSeparator(), idsAndAmounts);
        }

        sponsor.registerCompact(claimHash, typehash);
    }

    function registerBatchFor(
        address sponsor,
        uint256[2][] calldata idsAndAmounts,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 typehash,
        bytes32 witness,
        bytes calldata sponsorSignature
    ) external returns (bytes32 claimHash) {
        _enforceConsistentAllocators(idsAndAmounts);

        // Note: skips replacement of provided amounts as there are no corresponding deposits.
        claimHash = HashLib.toFlatBatchClaimWithWitnessMessageHash(
            sponsor, idsAndAmounts, arbiter, nonce, expires, typehash, witness, new uint256[](0)
        );

        // TOOD: support registering exogenous domain separators by passing notarized chainId
        claimHash.hasValidSponsor(sponsor, sponsorSignature, _domainSeparator(), idsAndAmounts);

        sponsor.registerCompact(claimHash, typehash);
    }

    function depositNativeAndRegister(bytes12 lockTag, bytes32 claimHash, bytes32 typehash)
        external
        payable
        returns (uint256 id)
    {
        id = _performCustomNativeTokenDeposit(lockTag, msg.sender);

        _register(msg.sender, claimHash, typehash);
    }

    function depositNativeAndRegisterFor(
        address recipient,
        bytes12 lockTag,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 typehash,
        bytes32 witness
    ) external payable returns (uint256 id, bytes32 claimhash) {
        id = _performCustomNativeTokenDeposit(lockTag, recipient);

        claimhash = _registerUsingClaimWithWitness(recipient, id, msg.value, arbiter, nonce, expires, typehash, witness);
    }

    function depositERC20AndRegister(
        address token,
        bytes12 lockTag,
        uint256 amount,
        bytes32 claimHash,
        bytes32 typehash
    ) external returns (uint256 id) {
        (id,) = _performCustomERC20Deposit(token, lockTag, amount, msg.sender);

        _register(msg.sender, claimHash, typehash);
    }

    function depositERC20AndRegisterFor(
        address recipient,
        address token,
        bytes12 lockTag,
        uint256 amount,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 typehash,
        bytes32 witness
    ) external returns (uint256 id, bytes32 claimhash, uint256 registeredAmount) {
        (id, registeredAmount) = _performCustomERC20Deposit(token, lockTag, amount, recipient);

        claimhash =
            _registerUsingClaimWithWitness(recipient, id, registeredAmount, arbiter, nonce, expires, typehash, witness);
    }

    function batchDepositAndRegisterMultiple(
        uint256[2][] calldata idsAndAmounts,
        bytes32[2][] calldata claimHashesAndTypehashes
    ) external payable returns (bool) {
        _processBatchDeposit(idsAndAmounts, msg.sender, false);

        return _registerBatch(claimHashesAndTypehashes);
    }

    function batchDepositAndRegisterFor(
        address recipient,
        uint256[2][] calldata idsAndAmounts,
        address arbiter,
        uint256 nonce,
        uint256 expires,
        bytes32 typehash,
        bytes32 witness
    ) external payable returns (bytes32 claimhash, uint256[] memory registeredAmounts) {
        registeredAmounts = _processBatchDeposit(idsAndAmounts, recipient, true);

        claimhash = _registerUsingBatchClaimWithWitness(
            recipient, idsAndAmounts, arbiter, nonce, expires, typehash, witness, registeredAmounts
        );
    }

    function depositERC20AndRegisterViaPermit2(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        address depositor, // also recipient
        bytes12, // lockTag
        bytes32 claimHash,
        CompactCategory, // compactCategory
        string calldata witness,
        bytes calldata signature
    ) external returns (uint256) {
        return _depositAndRegisterViaPermit2(permit.permitted.token, depositor, claimHash, witness, signature);
    }

    function batchDepositAndRegisterViaPermit2(
        address depositor,
        ISignatureTransfer.TokenPermissions[] calldata permitted,
        DepositDetails calldata,
        bytes32, // claimHash
        CompactCategory, // compactCategory
        string calldata witness,
        bytes calldata signature
    ) external payable returns (uint256[] memory) {
        return _depositBatchAndRegisterViaPermit2(depositor, permitted, witness, signature);
    }

    function enableForcedWithdrawal(uint256 id) external returns (uint256) {
        return _enableForcedWithdrawal(id);
    }

    function disableForcedWithdrawal(uint256 id) external returns (bool) {
        _disableForcedWithdrawal(id);

        return true;
    }

    function forcedWithdrawal(uint256 id, address recipient, uint256 amount) external returns (bool) {
        _processForcedWithdrawal(id, recipient, amount);

        return true;
    }

    function assignEmissary(bytes12 lockTag, address emissary) external returns (bool) {
        return _assignEmissary(lockTag, emissary);
    }

    function scheduleEmissaryAssignment(bytes12 lockTag) external returns (uint256 emissaryAssignmentAvailableAt) {
        return _scheduleEmissaryAssignment(lockTag);
    }

    function consume(uint256[] calldata nonces) external returns (bool) {
        return _consume(nonces);
    }

    function __registerAllocator(address allocator, bytes calldata proof) external returns (uint96) {
        return _registerAllocator(allocator, proof);
    }

    function __benchmark(bytes32 salt) external payable {
        salt.setNativeTokenBenchmark();
        _BENCHMARK_ERC20.setERC20TokenBenchmark();
    }

    function getRequiredWithdrawalFallbackStipends()
        external
        view
        returns (uint256 nativeTokenStipend, uint256 erc20TokenStipend)
    {
        return TransferBenchmarkLib.getTokenWithdrawalBenchmarks();
    }

    function getForcedWithdrawalStatus(address account, uint256 id)
        external
        view
        returns (ForcedWithdrawalStatus, uint256)
    {
        return _getForcedWithdrawalStatus(account, id);
    }

    function getRegistrationStatus(address sponsor, bytes32 claimHash, bytes32 typehash)
        external
        view
        returns (bool isActive, uint256 registrationTimestamp)
    {
        registrationTimestamp = _getRegistrationStatus(sponsor, claimHash, typehash);
        isActive = registrationTimestamp != 0;
    }

    function getEmissaryStatus(address sponsor, bytes12 lockTag)
        external
        view
        returns (EmissaryStatus status, uint256 emissaryAssignmentAvailableAt, address currentEmissary)
    {
        return _getEmissaryStatus(sponsor, lockTag);
    }

    function getLockDetails(uint256 id) external view returns (address, address, ResetPeriod, Scope, bytes12) {
        return _getLockDetails(id);
    }

    function hasConsumedAllocatorNonce(uint256 nonce, address allocator) external view returns (bool) {
        return _hasConsumedAllocatorNonce(nonce, allocator);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /**
     * @notice Returns the name for token `id`.
     * @param id The ERC6909 token identifier to get the name for.
     * @return The name of the token.
     */
    function name(uint256 id) public view virtual override returns (string memory) {
        return _name(id);
    }

    /**
     * @notice Returns the symbol for token `id`.
     * @param id The ERC6909 token identifier to get the symbol for.
     * @return The symbol of the token.
     */
    function symbol(uint256 id) public view virtual override returns (string memory) {
        return _symbol(id);
    }

    /**
     * @notice Returns the ERC6909 Uniform Resource Identifier (URI) for token `id`.
     * @param id The ERC6909 token identifier to get the URI for.
     * @return The URI of the token.
     */
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return _tokenURI(id);
    }

    /**
     * @notice External pure function for returning the name of the contract.
     * @return A string representing the name of the contract.
     */
    function name() external pure returns (string memory) {
        // Return the name of the contract.
        assembly ("memory-safe") {
            mstore(0x20, 0x20)
            mstore(0x4b, 0x0b54686520436f6d70616374)
            return(0x20, 0x60)
        }
    }

    /**
     * @notice Hook that is called before any standard ERC6909 token transfer. Note that this hook
     *         is not called when performing allocated transfers or when processing claims, nor are
     *         standard token approvals required.
     * @param from   The address tokens are transferred from.
     * @param to     The address tokens are transferred to.
     * @param id     The ERC6909 token identifier.
     * @param amount The amount of tokens being transferred.
     */
    function _beforeTokenTransfer(address from, address to, uint256 id, uint256 amount) internal virtual override {
        _ensureAttested(from, to, id, amount);
    }

    /**
     * @notice Internal function to ensure all resource lock IDs in a batch have the same allocator.
     * @param idsAndAmounts Array of [id, amount] pairs to check for consistent allocators.
     * @dev Reverts with InconsistentAllocators if any ID has a different allocator than the first ID.
     */
    function _enforceConsistentAllocators(uint256[2][] calldata idsAndAmounts) internal view {
        // Retrieve the total number of IDs and amounts in the batch.
        uint256 totalIds = idsAndAmounts.length;

        if (totalIds == 0) {
            revert InconsistentAllocators();
        }

        // Derive current allocator ID from first resource lock ID.
        uint96 initialAllocatorId = idsAndAmounts[0][0].toRegisteredAllocatorId();

        // Declare error buffer for tracking allocator ID consistency.
        uint256 errorBuffer;

        // Iterate over remaining IDs.
        unchecked {
            for (uint256 i = 1; i < totalIds; ++i) {
                // Determine if new allocator ID differs from current allocator ID.
                errorBuffer |= (idsAndAmounts[i][0].toAllocatorId() != initialAllocatorId).asUint256();
            }
        }

        if (errorBuffer.asBool()) {
            revert InconsistentAllocators();
        }
    }
}
