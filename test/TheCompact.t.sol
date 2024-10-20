// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { TheCompact } from "../src/TheCompact.sol";
import { MockERC20 } from "../lib/solady/test/utils/mocks/MockERC20.sol";
import { Compact, BatchCompact, Allocation } from "../src/types/EIP712Types.sol";
import { ResetPeriod } from "../src/types/ResetPeriod.sol";
import { Scope } from "../src/types/Scope.sol";
import { ISignatureTransfer } from "permit2/src/interfaces/ISignatureTransfer.sol";

import { HashLib } from "../src/lib/HashLib.sol";

import {
    BasicTransfer,
    SplitTransfer,
    BasicClaim,
    QualifiedClaim,
    ClaimWithWitness,
    QualifiedClaimWithWitness,
    SplitClaim,
    QualifiedSplitClaim,
    SplitClaimWithWitness,
    QualifiedSplitClaimWithWitness
} from "../src/types/Claims.sol";
import {
    BatchTransfer,
    SplitBatchTransfer,
    BatchClaim,
    QualifiedBatchClaim,
    BatchClaimWithWitness,
    QualifiedBatchClaimWithWitness,
    SplitBatchClaim,
    SplitBatchClaimWithWitness,
    QualifiedSplitBatchClaim,
    QualifiedSplitBatchClaimWithWitness
} from "../src/types/BatchClaims.sol";

import {
    MultichainClaim,
    ExogenousMultichainClaim,
    QualifiedMultichainClaim,
    ExogenousQualifiedMultichainClaim,
    MultichainClaimWithWitness,
    ExogenousMultichainClaimWithWitness,
    QualifiedMultichainClaimWithWitness,
    ExogenousQualifiedMultichainClaimWithWitness,
    SplitMultichainClaim,
    ExogenousSplitMultichainClaim,
    QualifiedSplitMultichainClaim,
    ExogenousQualifiedSplitMultichainClaim,
    SplitMultichainClaimWithWitness,
    ExogenousSplitMultichainClaimWithWitness,
    QualifiedSplitMultichainClaimWithWitness,
    ExogenousQualifiedSplitMultichainClaimWithWitness
} from "../src/types/MultichainClaims.sol";

import {
    BatchMultichainClaim,
    ExogenousBatchMultichainClaim,
    QualifiedBatchMultichainClaim,
    ExogenousQualifiedBatchMultichainClaim,
    BatchMultichainClaimWithWitness,
    ExogenousBatchMultichainClaimWithWitness,
    QualifiedBatchMultichainClaimWithWitness,
    ExogenousQualifiedBatchMultichainClaimWithWitness,
    SplitBatchMultichainClaim,
    ExogenousSplitBatchMultichainClaim,
    QualifiedSplitBatchMultichainClaim,
    ExogenousQualifiedSplitBatchMultichainClaim,
    SplitBatchMultichainClaimWithWitness,
    ExogenousSplitBatchMultichainClaimWithWitness,
    QualifiedSplitBatchMultichainClaimWithWitness,
    ExogenousQualifiedSplitBatchMultichainClaimWithWitness
} from "../src/types/BatchMultichainClaims.sol";

import { SplitComponent, TransferComponent, SplitByIdComponent, BatchClaimComponent, SplitBatchClaimComponent } from "../src/types/Components.sol";

interface EIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract TheCompactTest is Test {
    TheCompact public theCompact;
    MockERC20 public token;
    MockERC20 public anotherToken;
    address permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 swapperPrivateKey;
    address swapper;
    uint256 allocatorPrivateKey;
    address allocator;
    bytes32 compactEIP712DomainHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 permit2EIP712DomainHash = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    function setUp() public {
        address permit2Deployer = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        address deployedPermit2Deployer;
        address permit2DeployerDeployer = address(0x3fAB184622Dc19b6109349B94811493BF2a45362);
        bytes memory permit2DeployerCreationCode =
            hex"604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";
        vm.deal(permit2DeployerDeployer, 1e18);
        vm.prank(permit2DeployerDeployer);
        assembly ("memory-safe") {
            deployedPermit2Deployer := create(0, add(permit2DeployerCreationCode, 0x20), mload(permit2DeployerCreationCode))
        }

        require(deployedPermit2Deployer != permit2Deployer, "Contract deployment failed");

        bytes memory permit2CreationCalldata =
            hex"0000000000000000000000000000000000000000d3af2663da51c1021500000060c0346100bb574660a052602081017f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86681527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a60408301524660608301523060808301526080825260a082019180831060018060401b038411176100a557826040525190206080526123c090816100c1823960805181611b47015260a05181611b210152f35b634e487b7160e01b600052604160045260246000fd5b600080fdfe6040608081526004908136101561001557600080fd5b600090813560e01c80630d58b1db1461126c578063137c29fe146110755780632a2d80d114610db75780632b67b57014610bde57806330f28b7a14610ade5780633644e51514610a9d57806336c7851614610a285780633ff9dcb1146109a85780634fe02b441461093f57806365d9723c146107ac57806387517c451461067a578063927da105146105c3578063cc53287f146104a3578063edd9444b1461033a5763fe8ec1a7146100c657600080fd5b346103365760c07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff833581811161033257610114903690860161164b565b60243582811161032e5761012b903690870161161a565b6101336114e6565b9160843585811161032a5761014b9036908a016115c1565b98909560a43590811161032657610164913691016115c1565b969095815190610173826113ff565b606b82527f5065726d697442617463685769746e6573735472616e7366657246726f6d285460208301527f6f6b656e5065726d697373696f6e735b5d207065726d69747465642c61646472838301527f657373207370656e6465722c75696e74323536206e6f6e63652c75696e74323560608301527f3620646561646c696e652c000000000000000000000000000000000000000000608083015282519a8b9181610222602085018096611f93565b918237018a8152039961025b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe09b8c8101835282611437565b5190209085515161026b81611ebb565b908a5b8181106102f95750506102f6999a6102ed9183516102a081610294602082018095611f66565b03848101835282611437565b519020602089810151858b015195519182019687526040820192909252336060820152608081019190915260a081019390935260643560c08401528260e081015b03908101835282611437565b51902093611cf7565b80f35b8061031161030b610321938c5161175e565b51612054565b61031b828661175e565b52611f0a565b61026e565b8880fd5b8780fd5b8480fd5b8380fd5b5080fd5b5091346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff9080358281116103325761038b903690830161164b565b60243583811161032e576103a2903690840161161a565b9390926103ad6114e6565b9160643590811161049f576103c4913691016115c1565b949093835151976103d489611ebb565b98885b81811061047d5750506102f697988151610425816103f9602082018095611f66565b037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08101835282611437565b5190206020860151828701519083519260208401947ffcf35f5ac6a2c28868dc44c302166470266239195f02b0ee408334829333b7668652840152336060840152608083015260a082015260a081526102ed8161141b565b808b61031b8261049461030b61049a968d5161175e565b9261175e565b6103d7565b8680fd5b5082346105bf57602090817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103325780359067ffffffffffffffff821161032e576104f49136910161161a565b929091845b848110610504578580f35b8061051a610515600193888861196c565b61197c565b61052f84610529848a8a61196c565b0161197c565b3389528385528589209173ffffffffffffffffffffffffffffffffffffffff80911692838b528652868a20911690818a5285528589207fffffffffffffffffffffffff000000000000000000000000000000000000000081541690558551918252848201527f89b1add15eff56b3dfe299ad94e01f2b52fbcb80ae1a3baea6ae8c04cb2b98a4853392a2016104f9565b8280fd5b50346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610676816105ff6114a0565b936106086114c3565b6106106114e6565b73ffffffffffffffffffffffffffffffffffffffff968716835260016020908152848420928816845291825283832090871683528152919020549251938316845260a083901c65ffffffffffff169084015260d09190911c604083015281906060820190565b0390f35b50346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336576106b26114a0565b906106bb6114c3565b916106c46114e6565b65ffffffffffff926064358481169081810361032a5779ffffffffffff0000000000000000000000000000000000000000947fda9fa7c1b00402c17d0161b249b1ab8bbec047c5a52207b9c112deffd817036b94338a5260016020527fffffffffffff0000000000000000000000000000000000000000000000000000858b209873ffffffffffffffffffffffffffffffffffffffff809416998a8d5260205283878d209b169a8b8d52602052868c209486156000146107a457504216925b8454921697889360a01b16911617179055815193845260208401523392a480f35b905092610783565b5082346105bf5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576107e56114a0565b906107ee6114c3565b9265ffffffffffff604435818116939084810361032a57338852602091600183528489209673ffffffffffffffffffffffffffffffffffffffff80911697888b528452858a20981697888a5283528489205460d01c93848711156109175761ffff9085840316116108f05750907f55eb90d810e1700b35a8e7e25395ff7f2b2259abd7415ca2284dfb1c246418f393929133895260018252838920878a528252838920888a5282528389209079ffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffff000000000000000000000000000000000000000000000000000083549260d01b16911617905582519485528401523392a480f35b84517f24d35a26000000000000000000000000000000000000000000000000000000008152fd5b5084517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b503461033657807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336578060209273ffffffffffffffffffffffffffffffffffffffff61098f6114a0565b1681528084528181206024358252845220549051908152f35b5082346105bf57817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf577f3704902f963766a4e561bbaab6e6cdc1b1dd12f6e9e99648da8843b3f46b918d90359160243533855284602052818520848652602052818520818154179055815193845260208401523392a280f35b8234610a9a5760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610a9a57610a606114a0565b610a686114c3565b610a706114e6565b6064359173ffffffffffffffffffffffffffffffffffffffff8316830361032e576102f6936117a1565b80fd5b503461033657817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657602090610ad7611b1e565b9051908152f35b508290346105bf576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf57610b1a3661152a565b90807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c36011261033257610b4c611478565b9160e43567ffffffffffffffff8111610bda576102f694610b6f913691016115c1565b939092610b7c8351612054565b6020840151828501519083519260208401947f939c21a48a8dbe3a9a2404a1d46691e4d39f6583d6ec6b35714604c986d801068652840152336060840152608083015260a082015260a08152610bd18161141b565b51902091611c25565b8580fd5b509134610336576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610c186114a0565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc360160c08112610332576080855191610c51836113e3565b1261033257845190610c6282611398565b73ffffffffffffffffffffffffffffffffffffffff91602435838116810361049f578152604435838116810361049f57602082015265ffffffffffff606435818116810361032a5788830152608435908116810361049f576060820152815260a435938285168503610bda576020820194855260c4359087830182815260e43567ffffffffffffffff811161032657610cfe90369084016115c1565b929093804211610d88575050918591610d786102f6999a610d7e95610d238851611fbe565b90898c511690519083519260208401947ff3841cd1ff0085026a6327b620b67997ce40f282c88a8e905a7a5626e310f3d086528401526060830152608082015260808152610d70816113ff565b519020611bd9565b916120c7565b519251169161199d565b602492508a51917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b5091346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc93818536011261033257610df36114a0565b9260249081359267ffffffffffffffff9788851161032a578590853603011261049f578051978589018981108282111761104a578252848301358181116103265785019036602383011215610326578382013591610e50836115ef565b90610e5d85519283611437565b838252602093878584019160071b83010191368311611046578801905b828210610fe9575050508a526044610e93868801611509565b96838c01978852013594838b0191868352604435908111610fe557610ebb90369087016115c1565b959096804211610fba575050508998995151610ed681611ebb565b908b5b818110610f9757505092889492610d7892610f6497958351610f02816103f98682018095611f66565b5190209073ffffffffffffffffffffffffffffffffffffffff9a8b8b51169151928551948501957faf1b0d30d2cab0380e68f0689007e3254993c596f2fdd0aaa7f4d04f794408638752850152830152608082015260808152610d70816113ff565b51169082515192845b848110610f78578580f35b80610f918585610f8b600195875161175e565b5161199d565b01610f6d565b80610311610fac8e9f9e93610fb2945161175e565b51611fbe565b9b9a9b610ed9565b8551917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b8a80fd5b6080823603126110465785608091885161100281611398565b61100b85611509565b8152611018838601611509565b838201526110278a8601611607565b8a8201528d611037818701611607565b90820152815201910190610e7a565b8c80fd5b84896041867f4e487b7100000000000000000000000000000000000000000000000000000000835252fd5b5082346105bf576101407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576110b03661152a565b91807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c360112610332576110e2611478565b67ffffffffffffffff93906101043585811161049f5761110590369086016115c1565b90936101243596871161032a57611125610bd1966102f6983691016115c1565b969095825190611134826113ff565b606482527f5065726d69745769746e6573735472616e7366657246726f6d28546f6b656e5060208301527f65726d697373696f6e73207065726d69747465642c6164647265737320737065848301527f6e6465722c75696e74323536206e6f6e63652c75696e7432353620646561646c60608301527f696e652c0000000000000000000000000000000000000000000000000000000060808301528351948591816111e3602085018096611f93565b918237018b8152039361121c7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe095868101835282611437565b5190209261122a8651612054565b6020878101518589015195519182019687526040820192909252336060820152608081019190915260a081019390935260e43560c08401528260e081016102e1565b5082346105bf576020807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033257813567ffffffffffffffff92838211610bda5736602383011215610bda5781013592831161032e576024906007368386831b8401011161049f57865b8581106112e5578780f35b80821b83019060807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc83360301126103265761139288876001946060835161132c81611398565b611368608461133c8d8601611509565b9485845261134c60448201611509565b809785015261135d60648201611509565b809885015201611509565b918291015273ffffffffffffffffffffffffffffffffffffffff80808093169516931691166117a1565b016112da565b6080810190811067ffffffffffffffff8211176113b457604052565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6060810190811067ffffffffffffffff8211176113b457604052565b60a0810190811067ffffffffffffffff8211176113b457604052565b60c0810190811067ffffffffffffffff8211176113b457604052565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176113b457604052565b60c4359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b600080fd5b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6024359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6044359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc01906080821261149b576040805190611563826113e3565b8082941261149b57805181810181811067ffffffffffffffff8211176113b457825260043573ffffffffffffffffffffffffffffffffffffffff8116810361149b578152602435602082015282526044356020830152606435910152565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020838186019501011161149b57565b67ffffffffffffffff81116113b45760051b60200190565b359065ffffffffffff8216820361149b57565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020808501948460061b01011161149b57565b91909160608184031261149b576040805191611666836113e3565b8294813567ffffffffffffffff9081811161149b57830182601f8201121561149b578035611693816115ef565b926116a087519485611437565b818452602094858086019360061b8501019381851161149b579086899897969594939201925b8484106116e3575050505050855280820135908501520135910152565b90919293949596978483031261149b578851908982019082821085831117611730578a928992845261171487611509565b81528287013583820152815201930191908897969594936116c6565b602460007f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b80518210156117725760209160051b010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b92919273ffffffffffffffffffffffffffffffffffffffff604060008284168152600160205282828220961695868252602052818120338252602052209485549565ffffffffffff8760a01c16804211611884575082871696838803611812575b5050611810955016926118b5565b565b878484161160001461184f57602488604051907ff96fb0710000000000000000000000000000000000000000000000000000000082526004820152fd5b7fffffffffffffffffffffffff000000000000000000000000000000000000000084846118109a031691161790553880611802565b602490604051907fd81b2f2e0000000000000000000000000000000000000000000000000000000082526004820152fd5b9060006064926020958295604051947f23b872dd0000000000000000000000000000000000000000000000000000000086526004860152602485015260448401525af13d15601f3d116001600051141617161561190e57565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601460248201527f5452414e534645525f46524f4d5f4641494c45440000000000000000000000006044820152fd5b91908110156117725760061b0190565b3573ffffffffffffffffffffffffffffffffffffffff8116810361149b5790565b9065ffffffffffff908160608401511673ffffffffffffffffffffffffffffffffffffffff908185511694826020820151169280866040809401511695169560009187835260016020528383208984526020528383209916988983526020528282209184835460d01c03611af5579185611ace94927fc6a377bfc4eb120024a8ac08eef205be16b817020812c73223e81d1bdb9708ec98979694508715600014611ad35779ffffffffffff00000000000000000000000000000000000000009042165b60a01b167fffffffffffff00000000000000000000000000000000000000000000000000006001860160d01b1617179055519384938491604091949373ffffffffffffffffffffffffffffffffffffffff606085019616845265ffffffffffff809216602085015216910152565b0390a4565b5079ffffffffffff000000000000000000000000000000000000000087611a60565b600484517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b467f000000000000000000000000000000000000000000000000000000000000000003611b69577f000000000000000000000000000000000000000000000000000000000000000090565b60405160208101907f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86682527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a604082015246606082015230608082015260808152611bd3816113ff565b51902090565b611be1611b1e565b906040519060208201927f190100000000000000000000000000000000000000000000000000000000000084526022830152604282015260428152611bd381611398565b9192909360a435936040840151804211611cc65750602084510151808611611c955750918591610d78611c6594611c60602088015186611e47565b611bd9565b73ffffffffffffffffffffffffffffffffffffffff809151511692608435918216820361149b57611810936118b5565b602490604051907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b602490604051907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b959093958051519560409283830151804211611e175750848803611dee57611d2e918691610d7860209b611c608d88015186611e47565b60005b868110611d42575050505050505050565b611d4d81835161175e565b5188611d5a83878a61196c565b01359089810151808311611dbe575091818888886001968596611d84575b50505050505001611d31565b611db395611dad9273ffffffffffffffffffffffffffffffffffffffff6105159351169561196c565b916118b5565b803888888883611d78565b6024908651907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b600484517fff633a38000000000000000000000000000000000000000000000000000000008152fd5b6024908551907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b9073ffffffffffffffffffffffffffffffffffffffff600160ff83161b9216600052600060205260406000209060081c6000526020526040600020818154188091551615611e9157565b60046040517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b90611ec5826115ef565b611ed26040519182611437565b8281527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0611f0082946115ef565b0190602036910137565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114611f375760010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b805160208092019160005b828110611f7f575050505090565b835185529381019392810192600101611f71565b9081519160005b838110611fab575050016000815290565b8060208092840101518185015201611f9a565b60405160208101917f65626cad6cb96493bf6f5ebea28756c966f023ab9e8a83a7101849d5573b3678835273ffffffffffffffffffffffffffffffffffffffff8082511660408401526020820151166060830152606065ffffffffffff9182604082015116608085015201511660a082015260a0815260c0810181811067ffffffffffffffff8211176113b45760405251902090565b6040516020808201927f618358ac3db8dc274f0cd8829da7e234bd48cd73c4a740aede1adec9846d06a1845273ffffffffffffffffffffffffffffffffffffffff81511660408401520151606082015260608152611bd381611398565b919082604091031261149b576020823592013590565b6000843b61222e5750604182036121ac576120e4828201826120b1565b939092604010156117725760209360009360ff6040608095013560f81c5b60405194855216868401526040830152606082015282805260015afa156121a05773ffffffffffffffffffffffffffffffffffffffff806000511691821561217657160361214c57565b60046040517f815e1d64000000000000000000000000000000000000000000000000000000008152fd5b60046040517f8baa579f000000000000000000000000000000000000000000000000000000008152fd5b6040513d6000823e3d90fd5b60408203612204576121c0918101906120b1565b91601b7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff84169360ff1c019060ff8211611f375760209360009360ff608094612102565b60046040517f4be6321b000000000000000000000000000000000000000000000000000000008152fd5b929391601f928173ffffffffffffffffffffffffffffffffffffffff60646020957fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0604051988997889687947f1626ba7e000000000000000000000000000000000000000000000000000000009e8f8752600487015260406024870152816044870152868601378b85828601015201168101030192165afa9081156123a857829161232a575b507fffffffff000000000000000000000000000000000000000000000000000000009150160361230057565b60046040517fb0669cbc000000000000000000000000000000000000000000000000000000008152fd5b90506020813d82116123a0575b8161234460209383611437565b810103126103365751907fffffffff0000000000000000000000000000000000000000000000000000000082168203610a9a57507fffffffff0000000000000000000000000000000000000000000000000000000090386122d4565b3d9150612337565b6040513d84823e3d90fdfea164736f6c6343000811000a";

        (bool ok,) = permit2Deployer.call(permit2CreationCalldata);
        require(ok && permit2.code.length != 0, "permit2 deployment failed");

        theCompact = new TheCompact();
        token = new MockERC20("Mock ERC20", "MOCK", 18);
        anotherToken = new MockERC20("Another Mock ERC20", "MOCK2", 18);

        (swapper, swapperPrivateKey) = makeAddrAndKey("swapper");
        (allocator, allocatorPrivateKey) = makeAddrAndKey("allocator");

        vm.deal(swapper, 2e18);
        token.mint(swapper, 1e18);
        anotherToken.mint(swapper, 1e18);

        vm.startPrank(swapper);
        token.approve(address(theCompact), 1e18);
        token.approve(permit2, 1e18);
        anotherToken.approve(address(theCompact), 1e18);
        anotherToken.approve(permit2, 1e18);
        vm.stopPrank();
    }

    function test_name() public view {
        string memory name = theCompact.name();
        assertEq(keccak256(bytes(name)), keccak256(bytes("The Compact")));
    }

    function test_domainSeparator() public view {
        bytes32 domainSeparator = keccak256(abi.encode(compactEIP712DomainHash, keccak256(bytes("The Compact")), keccak256(bytes("1")), block.chainid, address(theCompact)));
        assertEq(domainSeparator, theCompact.DOMAIN_SEPARATOR());
    }

    function test_domainSeparatorOnNewChain() public {
        uint256 currentChainId = block.chainid;
        uint256 differentChainId = currentChainId + 42;
        bytes32 domainSeparator = keccak256(abi.encode(compactEIP712DomainHash, keccak256(bytes("The Compact")), keccak256(bytes("1")), differentChainId, address(theCompact)));
        vm.chainId(differentChainId);
        assertEq(block.chainid, differentChainId);
        assertEq(domainSeparator, theCompact.DOMAIN_SEPARATOR());
        vm.chainId(currentChainId);
        assertEq(block.chainid, currentChainId);
    }

    function test_depositETHBasic() public {
        address recipient = swapper;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(0));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(0))));

        assertEq(address(theCompact).balance, amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositETHAndURI() public {
        address recipient = 0x1111111111111111111111111111111111111111;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, recipient);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(0));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(0))));

        assertEq(address(theCompact).balance, amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositERC20Basic() public {
        address recipient = swapper;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, amount);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(token));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositERC20AndURI() public {
        address recipient = 0x1111111111111111111111111111111111111111;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, resetPeriod, scope, amount, recipient);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(token));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositBatchSingleERC20() public {
        address recipient = 0x1111111111111111111111111111111111111111;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        uint256 id = ((uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        uint256[2][] memory idsAndAmounts = new uint256[2][](1);
        idsAndAmounts[0] = [id, amount];

        vm.prank(swapper);
        bool ok = theCompact.deposit(idsAndAmounts, recipient);
        assert(ok);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(token));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));

        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositERC20ViaPermit2AndURI() public {
        address recipient = 0x1111111111111111111111111111111111111111;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1000;

        bytes32 domainSeparator = keccak256(abi.encode(permit2EIP712DomainHash, keccak256(bytes("Permit2")), block.chainid, address(permit2)));

        assertEq(domainSeparator, EIP712(permit2).DOMAIN_SEPARATOR());

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domainSeparator,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,CompactDeposit witness)CompactDeposit(address depositor,address allocator,uint8 resetPeriod,uint8 scope,address recipient)TokenPermissions(address token,uint256 amount)"
                        ),
                        keccak256(abi.encode(keccak256("TokenPermissions(address token,uint256 amount)"), address(token), amount)),
                        address(theCompact), // spender
                        nonce,
                        deadline,
                        keccak256(
                            abi.encode(
                                keccak256("CompactDeposit(address depositor,address allocator,uint8 resetPeriod,uint8 scope,address recipient)"), swapper, allocator, resetPeriod, scope, recipient
                            )
                        )
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        uint256 id = theCompact.deposit(swapper, address(token), allocator, resetPeriod, scope, amount, recipient, nonce, deadline, signature);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(id);
        assertEq(derivedToken, address(token));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(id, (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(theCompact.balanceOf(recipient, id), amount);
        assert(bytes(theCompact.tokenURI(id)).length > 0);
    }

    function test_depositBatchViaPermit2SingleERC20() public {
        address recipient = 0x1111111111111111111111111111111111111111;
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1000;

        bytes32 domainSeparator = keccak256(abi.encode(permit2EIP712DomainHash, keccak256(bytes("Permit2")), block.chainid, address(permit2)));

        assertEq(domainSeparator, EIP712(permit2).DOMAIN_SEPARATOR());

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domainSeparator,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,CompactDeposit witness)CompactDeposit(address depositor,address allocator,uint8 resetPeriod,uint8 scope,address recipient)TokenPermissions(address token,uint256 amount)"
                        ),
                        keccak256(abi.encode(keccak256(abi.encode(keccak256("TokenPermissions(address token,uint256 amount)"), address(token), amount)))),
                        address(theCompact), // spender
                        nonce,
                        deadline,
                        keccak256(
                            abi.encode(
                                keccak256("CompactDeposit(address depositor,address allocator,uint8 resetPeriod,uint8 scope,address recipient)"), swapper, allocator, resetPeriod, scope, recipient
                            )
                        )
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);

        vm.prank(allocator);
        uint96 allocatorId = theCompact.__register(allocator, "");

        ISignatureTransfer.TokenPermissions[] memory tokenPermissions = new ISignatureTransfer.TokenPermissions[](1);
        tokenPermissions[0] = ISignatureTransfer.TokenPermissions({ token: address(token), amount: amount });

        uint256[] memory ids = theCompact.deposit(swapper, tokenPermissions, allocator, resetPeriod, scope, recipient, nonce, deadline, signature);

        assertEq(ids.length, 1);

        (address derivedToken, address derivedAllocator, ResetPeriod derivedResetPeriod, Scope derivedScope) = theCompact.getLockDetails(ids[0]);
        assertEq(derivedToken, address(token));
        assertEq(derivedAllocator, allocator);
        assertEq(uint256(derivedResetPeriod), uint256(resetPeriod));
        assertEq(uint256(derivedScope), uint256(scope));
        assertEq(ids[0], (uint256(scope) << 255) | (uint256(resetPeriod) << 252) | (uint256(allocatorId) << 160) | uint256(uint160(address(token))));

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(theCompact.balanceOf(recipient, ids[0]), amount);
        assert(bytes(theCompact.tokenURI(ids[0])).length > 0);
    }

    function test_basicTransfer() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipient = 0x1111111111111111111111111111111111111111;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, resetPeriod, scope, amount, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), swapper, swapper, nonce, expiration, id, amount))
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BasicTransfer memory transfer = BasicTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, id: id, amount: amount, recipient: recipient });

        vm.prank(swapper);
        bool status = theCompact.allocatedTransfer(transfer);
        assert(status);

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(token.balanceOf(recipient), 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipient, id), amount);
    }

    function test_splitTransfer() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x2222222222222222222222222222222222222222;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, resetPeriod, scope, amount, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), swapper, swapper, nonce, expiration, id, amount))
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitTransfer memory transfer = SplitTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, id: id, recipients: recipients });

        vm.prank(swapper);
        bool status = theCompact.allocatedTransfer(transfer);
        assert(status);

        assertEq(token.balanceOf(address(theCompact)), amount);
        assertEq(token.balanceOf(recipientOne), 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
    }

    function test_batchTransfer() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amountOne = 1e18;
        uint256 amountTwo = 5e17;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipient = 0x1111111111111111111111111111111111111111;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 idOne = theCompact.deposit(address(token), allocator, resetPeriod, scope, amountOne, swapper);
        uint256 idTwo = theCompact.deposit{ value: amountTwo }(allocator);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, idOne), amountOne);
        assertEq(theCompact.balanceOf(swapper, idTwo), amountTwo);

        uint256[2][] memory idsAndAmounts = new uint256[2][](2);
        idsAndAmounts[0] = [idOne, amountOne];
        idsAndAmounts[1] = [idTwo, amountTwo];

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                        swapper,
                        swapper,
                        nonce,
                        expiration,
                        keccak256(abi.encodePacked(idsAndAmounts))
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        TransferComponent[] memory transfers = new TransferComponent[](2);
        transfers[0] = TransferComponent({ id: idOne, amount: amountOne });
        transfers[1] = TransferComponent({ id: idTwo, amount: amountTwo });

        BatchTransfer memory transfer = BatchTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, transfers: transfers, recipient: recipient });

        vm.prank(swapper);
        bool status = theCompact.allocatedTransfer(transfer);
        assert(status);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(theCompact.balanceOf(swapper, idOne), 0);
        assertEq(theCompact.balanceOf(swapper, idTwo), 0);
        assertEq(theCompact.balanceOf(recipient, idOne), amountOne);
        assertEq(theCompact.balanceOf(recipient, idTwo), amountTwo);
    }

    function test_splitBatchTransfer() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amountOne = 1e18;
        uint256 amountTwo = 6e17;
        uint256 amountThree = 4e17;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 idOne = theCompact.deposit(address(token), allocator, resetPeriod, scope, amountOne, swapper);
        uint256 idTwo = theCompact.deposit{ value: amountTwo + amountThree }(allocator);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, idOne), amountOne);
        assertEq(theCompact.balanceOf(swapper, idTwo), amountTwo + amountThree);

        uint256[2][] memory idsAndAmounts = new uint256[2][](2);
        idsAndAmounts[0] = [idOne, amountOne];
        idsAndAmounts[1] = [idTwo, amountTwo + amountThree];

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                        swapper,
                        swapper,
                        nonce,
                        expiration,
                        keccak256(abi.encodePacked(idsAndAmounts))
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitByIdComponent[] memory transfers = new SplitByIdComponent[](2);

        SplitComponent[] memory portionsOne = new SplitComponent[](1);
        portionsOne[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent[] memory portionsTwo = new SplitComponent[](2);
        portionsTwo[0] = SplitComponent({ claimant: recipientOne, amount: amountTwo });
        portionsTwo[1] = SplitComponent({ claimant: recipientTwo, amount: amountThree });

        transfers[0] = SplitByIdComponent({ id: idOne, portions: portionsOne });
        transfers[1] = SplitByIdComponent({ id: idTwo, portions: portionsTwo });

        SplitBatchTransfer memory transfer = SplitBatchTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, transfers: transfers });

        vm.prank(swapper);
        bool status = theCompact.allocatedTransfer(transfer);
        assert(status);

        assertEq(token.balanceOf(recipientOne), 0);
        assertEq(token.balanceOf(recipientTwo), 0);
        assertEq(theCompact.balanceOf(swapper, idOne), 0);
        assertEq(theCompact.balanceOf(swapper, idTwo), 0);
        assertEq(theCompact.balanceOf(recipientOne, idOne), amountOne);
        assertEq(theCompact.balanceOf(recipientOne, idTwo), amountTwo);
        assertEq(theCompact.balanceOf(recipientTwo, idTwo), amountThree);
    }

    function test_basicWithdrawal() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipient = 0x1111111111111111111111111111111111111111;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, resetPeriod, scope, amount, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), swapper, swapper, nonce, expiration, id, amount))
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BasicTransfer memory transfer = BasicTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, id: id, amount: amount, recipient: recipient });

        vm.prank(swapper);
        bool status = theCompact.allocatedWithdrawal(transfer);
        assert(status);

        assertEq(token.balanceOf(address(theCompact)), 0);
        assertEq(token.balanceOf(recipient), amount);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipient, id), 0);
    }

    function test_splitWithdrawal() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x2222222222222222222222222222222222222222;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit(address(token), allocator, resetPeriod, scope, amount, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), swapper, swapper, nonce, expiration, id, amount))
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitTransfer memory transfer = SplitTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, id: id, recipients: recipients });

        vm.prank(swapper);
        bool status = theCompact.allocatedWithdrawal(transfer);
        assert(status);

        assertEq(token.balanceOf(address(theCompact)), 0);
        assertEq(token.balanceOf(recipientOne), amountOne);
        assertEq(token.balanceOf(recipientTwo), amountTwo);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), 0);
        assertEq(theCompact.balanceOf(recipientTwo, id), 0);
    }

    function test_batchWithdrawal() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amountOne = 1e18;
        uint256 amountTwo = 5e17;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipient = 0x1111111111111111111111111111111111111111;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 idOne = theCompact.deposit(address(token), allocator, resetPeriod, scope, amountOne, swapper);
        uint256 idTwo = theCompact.deposit{ value: amountTwo }(allocator);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, idOne), amountOne);
        assertEq(theCompact.balanceOf(swapper, idTwo), amountTwo);

        uint256[2][] memory idsAndAmounts = new uint256[2][](2);
        idsAndAmounts[0] = [idOne, amountOne];
        idsAndAmounts[1] = [idTwo, amountTwo];

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                        swapper,
                        swapper,
                        nonce,
                        expiration,
                        keccak256(abi.encodePacked(idsAndAmounts))
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        TransferComponent[] memory transfers = new TransferComponent[](2);
        transfers[0] = TransferComponent({ id: idOne, amount: amountOne });
        transfers[1] = TransferComponent({ id: idTwo, amount: amountTwo });

        BatchTransfer memory transfer = BatchTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, transfers: transfers, recipient: recipient });

        vm.prank(swapper);
        bool status = theCompact.allocatedWithdrawal(transfer);
        assert(status);

        assertEq(token.balanceOf(recipient), amountOne);
        assertEq(recipient.balance, amountTwo);
        assertEq(token.balanceOf(address(theCompact)), 0);
        assertEq(address(theCompact).balance, 0);
        assertEq(theCompact.balanceOf(swapper, idOne), 0);
        assertEq(theCompact.balanceOf(swapper, idTwo), 0);
        assertEq(theCompact.balanceOf(recipient, idOne), 0);
        assertEq(theCompact.balanceOf(recipient, idTwo), 0);
    }

    function test_splitBatchWithdrawal() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amountOne = 1e18;
        uint256 amountTwo = 6e17;
        uint256 amountThree = 4e17;
        uint256 nonce = 0;
        uint256 expiration = block.timestamp + 1000;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 idOne = theCompact.deposit(address(token), allocator, resetPeriod, scope, amountOne, swapper);
        uint256 idTwo = theCompact.deposit{ value: amountTwo + amountThree }(allocator);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, idOne), amountOne);
        assertEq(theCompact.balanceOf(swapper, idTwo), amountTwo + amountThree);

        uint256[2][] memory idsAndAmounts = new uint256[2][](2);
        idsAndAmounts[0] = [idOne, amountOne];
        idsAndAmounts[1] = [idTwo, amountTwo + amountThree];

        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                theCompact.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                        swapper,
                        swapper,
                        nonce,
                        expiration,
                        keccak256(abi.encodePacked(idsAndAmounts))
                    )
                )
            )
        );

        (bytes32 r, bytes32 vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitByIdComponent[] memory transfers = new SplitByIdComponent[](2);

        SplitComponent[] memory portionsOne = new SplitComponent[](1);
        portionsOne[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent[] memory portionsTwo = new SplitComponent[](2);
        portionsTwo[0] = SplitComponent({ claimant: recipientOne, amount: amountTwo });
        portionsTwo[1] = SplitComponent({ claimant: recipientTwo, amount: amountThree });

        transfers[0] = SplitByIdComponent({ id: idOne, portions: portionsOne });
        transfers[1] = SplitByIdComponent({ id: idTwo, portions: portionsTwo });

        SplitBatchTransfer memory transfer = SplitBatchTransfer({ nonce: nonce, expires: expiration, allocatorSignature: allocatorSignature, transfers: transfers });

        vm.prank(swapper);
        bool status = theCompact.allocatedWithdrawal(transfer);
        assert(status);

        assertEq(token.balanceOf(recipientOne), amountOne);
        assertEq(token.balanceOf(recipientTwo), 0);
        assertEq(recipientOne.balance, amountTwo);
        assertEq(recipientTwo.balance, amountThree);
        assertEq(theCompact.balanceOf(swapper, idOne), 0);
        assertEq(theCompact.balanceOf(swapper, idTwo), 0);
        assertEq(theCompact.balanceOf(recipientOne, idOne), 0);
        assertEq(theCompact.balanceOf(recipientOne, idTwo), 0);
        assertEq(theCompact.balanceOf(recipientTwo, idTwo), 0);
    }

    function test_claim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 claimHash =
            keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), arbiter, swapper, nonce, expires, id, amount));

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BasicClaim memory claim = BasicClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, id, amount, claimant, amount);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
    }

    function test_claimAndWithdraw() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 claimHash =
            keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), arbiter, swapper, nonce, expires, id, amount));

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BasicClaim memory claim = BasicClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, id, amount, claimant, amount);

        vm.prank(arbiter);
        (bool status) = theCompact.claimAndWithdraw(claim);
        assert(status);

        assertEq(address(theCompact).balance, 0);
        assertEq(claimant.balance, amount);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), 0);
    }

    function test_qualifiedClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 claimHash =
            keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), arbiter, swapper, nonce, expires, id, amount));

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        QualifiedClaim memory claim = QualifiedClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, id, amount, claimant, amount);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
    }

    function test_claimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                id,
                amount,
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        ClaimWithWitness memory claim = ClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, id, amount, claimant, amount);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
    }

    function test_qualifiedClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                id,
                amount,
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        QualifiedClaimWithWitness memory claim = QualifiedClaimWithWitness(
            allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, id, amount, claimant, amount
        );

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
    }

    function test_splitClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 claimHash =
            keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), arbiter, swapper, nonce, expires, id, amount));

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitClaim memory claim = SplitClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, id, amount, recipients);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
    }

    function test_qualifiedSplitClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        bytes32 claimHash =
            keccak256(abi.encode(keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount)"), arbiter, swapper, nonce, expires, id, amount));

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        QualifiedSplitClaim memory claim = QualifiedSplitClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, id, amount, recipients);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
    }

    function test_splitClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                id,
                amount,
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitClaimWithWitness memory claim = SplitClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, id, amount, recipients);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
    }

    function test_qualifiedSplitClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.prank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        assertEq(theCompact.balanceOf(swapper, id), amount);

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("Compact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256 id,uint256 amount,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                id,
                amount,
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        QualifiedSplitClaimWithWitness memory claim = QualifiedSplitClaimWithWitness(
            allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, id, amount, recipients
        );

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
    }

    function test_batchClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts))
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](3);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });
        claims[1] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[2] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        BatchClaim memory claim = BatchClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, claims, claimant);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(claimant, id), amount);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);
    }

    function test_qualifiedBatchClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts))
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](3);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });
        claims[1] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[2] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        QualifiedBatchClaim memory claim = QualifiedBatchClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, claims, claimant);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(claimant, id), amount);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);
    }

    function test_batchClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts)),
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](3);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });
        claims[1] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[2] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        BatchClaimWithWitness memory claim = BatchClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, claims, claimant);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(claimant, id), amount);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);
    }

    function test_qualifiedBatchClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts)),
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](3);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });
        claims[1] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[2] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        QualifiedBatchClaimWithWitness memory claim =
            QualifiedBatchClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, claims, claimant);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(claimant, id), amount);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);
    }

    function test_splitBatchClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts))
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](3);
        SplitComponent[] memory portions = new SplitComponent[](2);
        portions[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });
        portions[1] = SplitComponent({ claimant: recipientTwo, amount: amountTwo });
        claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: portions });
        SplitComponent[] memory anotherPortion = new SplitComponent[](1);
        anotherPortion[0] = SplitComponent({ claimant: recipientOne, amount: anotherAmount });
        claims[1] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherPortion });
        SplitComponent[] memory aThirdPortion = new SplitComponent[](1);
        aThirdPortion[0] = SplitComponent({ claimant: recipientTwo, amount: aThirdAmount });
        claims[2] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: aThirdPortion });

        SplitBatchClaim memory claim = SplitBatchClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, claims);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), aThirdAmount);
    }

    function test_splitBatchClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts)),
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](3);
        SplitComponent[] memory portions = new SplitComponent[](2);
        portions[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });
        portions[1] = SplitComponent({ claimant: recipientTwo, amount: amountTwo });
        claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: portions });
        SplitComponent[] memory anotherPortion = new SplitComponent[](1);
        anotherPortion[0] = SplitComponent({ claimant: recipientOne, amount: anotherAmount });
        claims[1] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherPortion });
        SplitComponent[] memory aThirdPortion = new SplitComponent[](1);
        aThirdPortion[0] = SplitComponent({ claimant: recipientTwo, amount: aThirdAmount });
        claims[2] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: aThirdPortion });

        SplitBatchClaimWithWitness memory claim = SplitBatchClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, claims);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), aThirdAmount);
    }

    function test_qualifiedSplitBatchClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts))
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](3);
        SplitComponent[] memory portions = new SplitComponent[](2);
        portions[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });
        portions[1] = SplitComponent({ claimant: recipientTwo, amount: amountTwo });
        claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: portions });
        SplitComponent[] memory anotherPortion = new SplitComponent[](1);
        anotherPortion[0] = SplitComponent({ claimant: recipientOne, amount: anotherAmount });
        claims[1] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherPortion });
        SplitComponent[] memory aThirdPortion = new SplitComponent[](1);
        aThirdPortion[0] = SplitComponent({ claimant: recipientTwo, amount: aThirdAmount });
        claims[2] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: aThirdPortion });

        QualifiedSplitBatchClaim memory claim = QualifiedSplitBatchClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, claims);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), aThirdAmount);
    }

    function test_qualifiedSplitBatchClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("BatchCompact(address arbiter,address sponsor,uint256 nonce,uint256 expires,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(idsAndAmounts)),
                witness
            )
        );

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](3);
        SplitComponent[] memory portions = new SplitComponent[](2);
        portions[0] = SplitComponent({ claimant: recipientOne, amount: amountOne });
        portions[1] = SplitComponent({ claimant: recipientTwo, amount: amountTwo });
        claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: portions });
        SplitComponent[] memory anotherPortion = new SplitComponent[](1);
        anotherPortion[0] = SplitComponent({ claimant: recipientOne, amount: anotherAmount });
        claims[1] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherPortion });
        SplitComponent[] memory aThirdPortion = new SplitComponent[](1);
        aThirdPortion[0] = SplitComponent({ claimant: recipientTwo, amount: aThirdAmount });
        claims[2] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: aThirdPortion });

        QualifiedSplitBatchClaimWithWitness memory claim =
            QualifiedSplitBatchClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, claims);

        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(token.balanceOf(address(theCompact)), anotherAmount);
        assertEq(anotherToken.balanceOf(address(theCompact)), aThirdAmount);

        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), aThirdAmount);
    }

    function test_multichainClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        MultichainClaim memory claim = MultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, id, amount, claimant, amount);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousMultichainClaim memory anotherClaim = ExogenousMultichainClaim(
            exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, chainIndex, notarizedChainId, anotherId, anotherAmount, claimant, anotherAmount
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedMultichainClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        QualifiedMultichainClaim memory claim =
            QualifiedMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, additionalChains, id, amount, claimant, amount);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousQualifiedMultichainClaim memory anotherClaim = ExogenousQualifiedMultichainClaim(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            qualificationTypehash,
            qualificationPayload,
            additionalChains,
            chainIndex,
            notarizedChainId,
            anotherId,
            anotherAmount,
            claimant,
            anotherAmount
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_multichainClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        MultichainClaimWithWitness memory claim =
            MultichainClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, additionalChains, id, amount, claimant, amount);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousMultichainClaimWithWitness memory anotherClaim = ExogenousMultichainClaimWithWitness(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            witness,
            witnessTypestring,
            additionalChains,
            chainIndex,
            notarizedChainId,
            anotherId,
            anotherAmount,
            claimant,
            anotherAmount
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedMultichainClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        QualifiedMultichainClaimWithWitness memory claim = QualifiedMultichainClaimWithWitness(
            allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, additionalChains, id, amount, claimant, amount
        );

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousQualifiedMultichainClaimWithWitness memory anotherClaim = ExogenousQualifiedMultichainClaimWithWitness(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            witness,
            witnessTypestring,
            qualificationTypehash,
            qualificationPayload,
            additionalChains,
            chainIndex,
            notarizedChainId,
            anotherId,
            anotherAmount,
            claimant,
            anotherAmount
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_splitMultichainClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitMultichainClaim memory claim = SplitMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, id, amount, recipients);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousSplitMultichainClaim memory anotherClaim =
            ExogenousSplitMultichainClaim(exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, chainIndex, notarizedChainId, anotherId, anotherAmount, recipients);

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, anotherId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedSplitMultichainClaim() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        QualifiedSplitMultichainClaim memory claim =
            QualifiedSplitMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, additionalChains, id, amount, recipients);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousQualifiedSplitMultichainClaim memory anotherClaim = ExogenousQualifiedSplitMultichainClaim(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            qualificationTypehash,
            qualificationPayload,
            additionalChains,
            chainIndex,
            notarizedChainId,
            anotherId,
            anotherAmount,
            recipients
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, anotherId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_splitMultichainClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        SplitMultichainClaimWithWitness memory claim =
            SplitMultichainClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, additionalChains, id, amount, recipients);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousSplitMultichainClaimWithWitness memory anotherClaim = ExogenousSplitMultichainClaimWithWitness(
            exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, additionalChains, chainIndex, notarizedChainId, anotherId, anotherAmount, recipients
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, anotherId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedSplitMultichainClaimWithWitness() public {
        ResetPeriod resetPeriod = ResetPeriod.TenMinutes;
        Scope scope = Scope.Multichain;
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;
        uint256 anotherChainId = 7171717;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, resetPeriod, scope, swapper);
        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](1);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        QualifiedSplitMultichainClaimWithWitness memory claim = QualifiedSplitMultichainClaimWithWitness(
            allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, additionalChains, id, amount, recipients
        );

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        ExogenousQualifiedSplitMultichainClaimWithWitness memory anotherClaim = ExogenousQualifiedSplitMultichainClaimWithWitness(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            witness,
            witnessTypestring,
            qualificationTypehash,
            qualificationPayload,
            additionalChains,
            chainIndex,
            notarizedChainId,
            anotherId,
            anotherAmount,
            recipients
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, anotherId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_batchMultichainClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](1);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });

        BatchMultichainClaim memory claim = BatchMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, claims, claimant);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        claims = new BatchClaimComponent[](2);
        claims[0] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[1] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        ExogenousBatchMultichainClaim memory anotherClaim =
            ExogenousBatchMultichainClaim(exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, chainIndex, notarizedChainId, claims, claimant);

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedBatchMultichainClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](1);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });

        QualifiedBatchMultichainClaim memory claim =
            QualifiedBatchMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, additionalChains, claims, claimant);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        claims = new BatchClaimComponent[](2);
        claims[0] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[1] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        ExogenousQualifiedBatchMultichainClaim memory anotherClaim = ExogenousQualifiedBatchMultichainClaim(
            exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, qualificationTypehash, qualificationPayload, additionalChains, chainIndex, notarizedChainId, claims, claimant
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_batchMultichainClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](1);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });

        BatchMultichainClaimWithWitness memory claim =
            BatchMultichainClaimWithWitness(allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, additionalChains, claims, claimant);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        claims = new BatchClaimComponent[](2);
        claims[0] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[1] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        ExogenousBatchMultichainClaimWithWitness memory anotherClaim = ExogenousBatchMultichainClaimWithWitness(
            exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, additionalChains, chainIndex, notarizedChainId, claims, claimant
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedBatchMultichainClaimWithWitness() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address claimant = 0x1111111111111111111111111111111111111111;
        address arbiter = 0x2222222222222222222222222222222222222222;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");

        uint256 qualifiedClaimArgument = 123;
        bytes memory qualificationPayload = abi.encode(qualifiedClaimArgument);

        bytes32 qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));

        digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        BatchClaimComponent[] memory claims = new BatchClaimComponent[](1);
        claims[0] = BatchClaimComponent({ id: id, allocatedAmount: amount, amount: amount });

        QualifiedBatchMultichainClaimWithWitness memory claim = QualifiedBatchMultichainClaimWithWitness(
            allocatorSignature, sponsorSignature, swapper, nonce, expires, witness, witnessTypestring, qualificationTypehash, qualificationPayload, additionalChains, claims, claimant
        );

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(claimant.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(claimant, id), amount);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        claims = new BatchClaimComponent[](2);
        claims[0] = BatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, amount: anotherAmount });
        claims[1] = BatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, amount: aThirdAmount });

        ExogenousQualifiedBatchMultichainClaimWithWitness memory anotherClaim = ExogenousQualifiedBatchMultichainClaimWithWitness(
            exogenousAllocatorSignature,
            sponsorSignature,
            swapper,
            nonce,
            expires,
            witness,
            witnessTypestring,
            qualificationTypehash,
            qualificationPayload,
            additionalChains,
            chainIndex,
            notarizedChainId,
            claims,
            claimant
        );

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(claimant, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(claimant, aThirdId), aThirdAmount);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_splitBatchMultichainClaim() public {
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 nonce = 0;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                nonce,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), initialDomainSeparator, claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory allocatorSignature = abi.encodePacked(r, vs);

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](1);

        SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

        SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

        SplitComponent[] memory recipients = new SplitComponent[](2);
        recipients[0] = splitOne;
        recipients[1] = splitTwo;

        claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: recipients });

        SplitBatchMultichainClaim memory claim = SplitBatchMultichainClaim(allocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, claims);

        uint256 snapshotId = vm.snapshot();
        vm.prank(arbiter);
        (bool status) = theCompact.claim(claim);
        assert(status);

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        bytes32 anotherDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        assert(initialDomainSeparator != anotherDomainSeparator);

        digest = keccak256(abi.encodePacked(bytes2(0x1901), anotherDomainSeparator, claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);
        bytes memory exogenousAllocatorSignature = abi.encodePacked(r, vs);

        additionalChains[0] = allocationHashOne;
        uint256 chainIndex = 0;

        SplitComponent memory anotherSplit = SplitComponent({ claimant: recipientOne, amount: anotherAmount });

        SplitComponent[] memory anotherRecipient = new SplitComponent[](1);
        anotherRecipient[0] = anotherSplit;

        claims = new SplitBatchClaimComponent[](2);
        claims[0] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherRecipient });
        claims[1] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: recipients });

        ExogenousSplitBatchMultichainClaim memory anotherClaim =
            ExogenousSplitBatchMultichainClaim(exogenousAllocatorSignature, sponsorSignature, swapper, nonce, expires, additionalChains, chainIndex, notarizedChainId, claims);

        vm.prank(arbiter);
        (bool exogenousStatus) = theCompact.claim(anotherClaim);
        assert(exogenousStatus);

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientOne, aThirdId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedSplitBatchMultichainClaim() public {
        // ABC
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        bytes32 allocationHashOne =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, block.chainid, keccak256(abi.encodePacked(idsAndAmountsOne))));

        bytes32 allocationHashTwo =
            keccak256(abi.encode(keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"), arbiter, anotherChainId, keccak256(abi.encodePacked(idsAndAmountsTwo))));

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256("MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts)"),
                swapper,
                0,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");
        bytes memory qualificationPayload;
        bytes32 qualifiedClaimHash;

        {
            uint256 qualifiedClaimArgument = 123;
            qualificationPayload = abi.encode(qualifiedClaimArgument);
            qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));
        }

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](1);
        SplitComponent[] memory recipients = new SplitComponent[](2);

        {
            SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

            SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

            recipients[0] = splitOne;
            recipients[1] = splitTwo;

            claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: recipients });
        }

        uint256 snapshotId = vm.snapshot();

        {
            QualifiedSplitBatchMultichainClaim memory claim;
            claim.allocatorSignature = abi.encodePacked(r, vs);
            claim.sponsorSignature = sponsorSignature;
            claim.sponsor = swapper;
            claim.nonce = 0;
            claim.expires = expires;
            claim.qualificationTypehash = qualificationTypehash;
            claim.qualificationPayload = qualificationPayload;
            claim.additionalChains = additionalChains;
            claim.claims = claims;

            vm.prank(arbiter);
            (bool status) = theCompact.claim(claim);
            assert(status);
        }

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        assert(initialDomainSeparator != theCompact.DOMAIN_SEPARATOR());

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        additionalChains[0] = allocationHashOne;

        {
            SplitComponent memory anotherSplit = SplitComponent({ claimant: recipientOne, amount: anotherAmount });

            SplitComponent[] memory anotherRecipient = new SplitComponent[](1);
            anotherRecipient[0] = anotherSplit;

            claims = new SplitBatchClaimComponent[](2);
            claims[0] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherRecipient });
            claims[1] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: recipients });
        }

        ExogenousQualifiedSplitBatchMultichainClaim memory anotherClaim;
        {
            anotherClaim.allocatorSignature = abi.encodePacked(r, vs);
            anotherClaim.sponsorSignature = sponsorSignature;
            anotherClaim.sponsor = swapper;
            anotherClaim.nonce = 0;
            anotherClaim.expires = expires;
            anotherClaim.qualificationTypehash = qualificationTypehash;
            anotherClaim.qualificationPayload = qualificationPayload;
            anotherClaim.additionalChains = additionalChains;
            anotherClaim.chainIndex = 0;
            anotherClaim.notarizedChainId = notarizedChainId;
            anotherClaim.claims = claims;
        }

        {
            vm.prank(arbiter);
            (bool exogenousStatus) = theCompact.claim(anotherClaim);
            assert(exogenousStatus);
        }

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientOne, aThirdId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_splitBatchMultichainClaimWithWitness() public {
        // ABC
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                0,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](1);
        SplitComponent[] memory recipients = new SplitComponent[](2);

        {
            SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

            SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

            recipients[0] = splitOne;
            recipients[1] = splitTwo;

            claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: recipients });
        }

        SplitBatchMultichainClaimWithWitness memory claim;
        claim.sponsorSignature = sponsorSignature;

        {
            uint256 snapshotId = vm.snapshot();

            claim.allocatorSignature = abi.encodePacked(r, vs);
            claim.sponsor = swapper;
            claim.nonce = 0;
            claim.expires = expires;
            claim.witness = witness;
            claim.witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
            claim.additionalChains = additionalChains;
            claim.claims = claims;

            vm.prank(arbiter);
            (bool status) = theCompact.claim(claim);
            assert(status);

            assertEq(address(theCompact).balance, amount);
            assertEq(recipientOne.balance, 0);
            assertEq(recipientTwo.balance, 0);
            assertEq(theCompact.balanceOf(swapper, id), 0);
            assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
            assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
            vm.revertToAndDelete(snapshotId);
        }

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        assert(initialDomainSeparator != theCompact.DOMAIN_SEPARATOR());

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        additionalChains[0] = allocationHashOne;

        {
            SplitComponent memory anotherSplit = SplitComponent({ claimant: recipientOne, amount: anotherAmount });

            SplitComponent[] memory anotherRecipient = new SplitComponent[](1);
            anotherRecipient[0] = anotherSplit;

            claims = new SplitBatchClaimComponent[](2);
            claims[0] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherRecipient });
            claims[1] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: recipients });
        }

        ExogenousSplitBatchMultichainClaimWithWitness memory anotherClaim;
        anotherClaim.allocatorSignature = abi.encodePacked(r, vs);
        anotherClaim.sponsorSignature = sponsorSignature;
        anotherClaim.witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        anotherClaim.additionalChains = additionalChains;

        {
            anotherClaim.sponsor = swapper;
            anotherClaim.nonce = 0;
            anotherClaim.expires = expires;
            anotherClaim.witness = witness;
            anotherClaim.chainIndex = 0;
            anotherClaim.notarizedChainId = notarizedChainId;
            anotherClaim.claims = claims;
        }

        // {
        //     vm.prank(arbiter);
        //     (bool exogenousStatus) = theCompact.claim(anotherClaim);
        //     assert(exogenousStatus);
        // }

        // assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        // assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        // assertEq(theCompact.balanceOf(recipientOne, aThirdId), amountOne);
        // assertEq(theCompact.balanceOf(recipientTwo, aThirdId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }

    function test_qualifiedSplitBatchMultichainClaimWithWitness() public {
        // ABC
        uint256 amount = 1e18;
        uint256 anotherAmount = 1e18;
        uint256 aThirdAmount = 1e18;
        uint256 expires = block.timestamp + 1000;
        address arbiter = 0x2222222222222222222222222222222222222222;

        address recipientOne = 0x1111111111111111111111111111111111111111;
        address recipientTwo = 0x3333333333333333333333333333333333333333;
        uint256 amountOne = 4e17;
        uint256 amountTwo = 6e17;

        vm.prank(allocator);
        theCompact.__register(allocator, "");

        vm.startPrank(swapper);
        uint256 id = theCompact.deposit{ value: amount }(allocator, ResetPeriod.TenMinutes, Scope.Multichain, swapper);

        uint256 anotherId = theCompact.deposit(address(token), allocator, ResetPeriod.TenMinutes, Scope.Multichain, anotherAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);

        uint256 aThirdId = theCompact.deposit(address(anotherToken), allocator, ResetPeriod.TenMinutes, Scope.Multichain, aThirdAmount, swapper);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        vm.stopPrank();

        assertEq(theCompact.balanceOf(swapper, id), amount);
        assertEq(theCompact.balanceOf(swapper, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(swapper, aThirdId), aThirdAmount);

        uint256[2][] memory idsAndAmounts = new uint256[2][](3);
        idsAndAmounts[0] = [id, amount];
        idsAndAmounts[1] = [anotherId, anotherAmount];
        idsAndAmounts[2] = [aThirdId, aThirdAmount];

        uint256 anotherChainId = 7171717;

        uint256[2][] memory idsAndAmountsOne = new uint256[2][](1);
        idsAndAmountsOne[0] = [id, amount];

        uint256[2][] memory idsAndAmountsTwo = new uint256[2][](2);
        idsAndAmountsTwo[0] = [anotherId, anotherAmount];
        idsAndAmountsTwo[1] = [aThirdId, aThirdAmount];

        string memory witnessTypestring = "Witness witness)Witness(uint256 witnessArgument)";
        uint256 witnessArgument = 234;
        bytes32 witness = keccak256(abi.encode(witnessArgument));

        bytes32 allocationHashOne = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                block.chainid,
                keccak256(abi.encodePacked(idsAndAmountsOne)),
                witness
            )
        );

        bytes32 allocationHashTwo = keccak256(
            abi.encode(
                keccak256("Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"),
                arbiter,
                anotherChainId,
                keccak256(abi.encodePacked(idsAndAmountsTwo)),
                witness
            )
        );

        bytes32[] memory additionalChains = new bytes32[](1);
        additionalChains[0] = allocationHashTwo;

        bytes32 claimHash = keccak256(
            abi.encode(
                keccak256(
                    "MultichainCompact(address sponsor,uint256 nonce,uint256 expires,Allocation[] allocations)Allocation(address arbiter,uint256 chainId,uint256[2][] idsAndAmounts,Witness witness)Witness(uint256 witnessArgument)"
                ),
                swapper,
                0,
                expires,
                keccak256(abi.encodePacked(allocationHashOne, allocationHashTwo))
            )
        );

        bytes32 initialDomainSeparator = theCompact.DOMAIN_SEPARATOR();

        bytes32 digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), claimHash));

        (bytes32 r, bytes32 vs) = vm.signCompact(swapperPrivateKey, digest);
        bytes memory sponsorSignature = abi.encodePacked(r, vs);

        bytes32 qualificationTypehash = keccak256("ExampleQualifiedClaim(bytes32 claimHash,uint256 qualifiedClaimArgument)");
        bytes memory qualificationPayload;
        bytes32 qualifiedClaimHash;

        {
            uint256 qualifiedClaimArgument = 123;
            qualificationPayload = abi.encode(qualifiedClaimArgument);
            qualifiedClaimHash = keccak256(abi.encode(qualificationTypehash, claimHash, qualifiedClaimArgument));
        }

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        SplitBatchClaimComponent[] memory claims = new SplitBatchClaimComponent[](1);
        SplitComponent[] memory recipients = new SplitComponent[](2);

        {
            SplitComponent memory splitOne = SplitComponent({ claimant: recipientOne, amount: amountOne });

            SplitComponent memory splitTwo = SplitComponent({ claimant: recipientTwo, amount: amountTwo });

            recipients[0] = splitOne;
            recipients[1] = splitTwo;

            claims[0] = SplitBatchClaimComponent({ id: id, allocatedAmount: amount, portions: recipients });
        }

        uint256 snapshotId = vm.snapshot();

        {
            QualifiedSplitBatchMultichainClaimWithWitness memory claim;
            claim.allocatorSignature = abi.encodePacked(r, vs);
            claim.sponsorSignature = sponsorSignature;
            claim.sponsor = swapper;
            claim.nonce = 0;
            claim.expires = expires;
            claim.witness = witness;
            claim.witnessTypestring = witnessTypestring;
            claim.qualificationTypehash = qualificationTypehash;
            claim.qualificationPayload = qualificationPayload;
            claim.additionalChains = additionalChains;
            claim.claims = claims;

            vm.prank(arbiter);
            (bool status) = theCompact.claim(claim);
            assert(status);
        }

        assertEq(address(theCompact).balance, amount);
        assertEq(recipientOne.balance, 0);
        assertEq(recipientTwo.balance, 0);
        assertEq(theCompact.balanceOf(swapper, id), 0);
        assertEq(theCompact.balanceOf(recipientOne, id), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, id), amountTwo);
        vm.revertToAndDelete(snapshotId);

        // change to "new chain" (this hack is so the original one gets stored)
        uint256 notarizedChainId = abi.decode(abi.encode(block.chainid), (uint256));
        assert(notarizedChainId != anotherChainId);
        vm.chainId(anotherChainId);
        assertEq(block.chainid, anotherChainId);
        assert(notarizedChainId != anotherChainId);

        assert(initialDomainSeparator != theCompact.DOMAIN_SEPARATOR());

        digest = keccak256(abi.encodePacked(bytes2(0x1901), theCompact.DOMAIN_SEPARATOR(), qualifiedClaimHash));

        (r, vs) = vm.signCompact(allocatorPrivateKey, digest);

        additionalChains[0] = allocationHashOne;

        {
            SplitComponent memory anotherSplit = SplitComponent({ claimant: recipientOne, amount: anotherAmount });

            SplitComponent[] memory anotherRecipient = new SplitComponent[](1);
            anotherRecipient[0] = anotherSplit;

            claims = new SplitBatchClaimComponent[](2);
            claims[0] = SplitBatchClaimComponent({ id: anotherId, allocatedAmount: anotherAmount, portions: anotherRecipient });
            claims[1] = SplitBatchClaimComponent({ id: aThirdId, allocatedAmount: aThirdAmount, portions: recipients });
        }

        ExogenousQualifiedSplitBatchMultichainClaimWithWitness memory anotherClaim;
        {
            anotherClaim.allocatorSignature = abi.encodePacked(r, vs);
            anotherClaim.sponsorSignature = sponsorSignature;
            anotherClaim.sponsor = swapper;
            anotherClaim.nonce = 0;
            anotherClaim.expires = expires;
            anotherClaim.witness = witness;
            anotherClaim.witnessTypestring = witnessTypestring;
            anotherClaim.qualificationTypehash = qualificationTypehash;
            anotherClaim.qualificationPayload = qualificationPayload;
            anotherClaim.additionalChains = additionalChains;
            anotherClaim.chainIndex = 0;
            anotherClaim.notarizedChainId = notarizedChainId;
            anotherClaim.claims = claims;
        }

        {
            vm.prank(arbiter);
            (bool exogenousStatus) = theCompact.claim(anotherClaim);
            assert(exogenousStatus);
        }

        assertEq(theCompact.balanceOf(swapper, anotherId), 0);
        assertEq(theCompact.balanceOf(recipientOne, anotherId), anotherAmount);
        assertEq(theCompact.balanceOf(recipientOne, aThirdId), amountOne);
        assertEq(theCompact.balanceOf(recipientTwo, aThirdId), amountTwo);

        // change back
        vm.chainId(notarizedChainId);
        assertEq(block.chainid, notarizedChainId);
    }
}
