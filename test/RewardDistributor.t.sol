pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {CypherToken} from "../src/CypherToken.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
import {IRewardDistributor} from "../src/interfaces/IRewardDistributor.sol";

contract RewardDistributorTest is Test {
    CypherToken cypher;
    RewardDistributor rd;

    function setUp() public {
        cypher = new CypherToken(address(this));
        rd = new RewardDistributor(address(this), address(cypher));
    }

    function testConstruction() public {
        RewardDistributor rewardDistributor = new RewardDistributor(address(0x1234), address(0x9876));
        assertEq(rewardDistributor.owner(), address(0x1234));
        assertEq(address(rewardDistributor.cypher()), address(0x9876));
    }

    function testAddRoot() public {
        bytes32 root1 = keccak256(bytes.concat("abc"));
        uint256 id = rd.addRoot(root1);
        assertEq(id, 0);
        assertEq(rd.idToRoot(id), root1);
        bytes32 root2 = keccak256(bytes.concat("123"));
        id = rd.addRoot(root2);
        assertEq(id, 1);
        assertEq(rd.idToRoot(id), root2);
    }

    function testAddSameRootTwice() public {
        bytes32 root = keccak256(bytes.concat("a1A"));
        uint256 id = rd.addRoot(root);
        assertEq(id, 0);
        assertEq(rd.idToRoot(id), root);
        id = rd.addRoot(root);
        assertEq(id, 1);
        assertEq(rd.idToRoot(id), root);
    }

    function testZeroBytes32IsNotAValidRoot() public {
        vm.expectRevert(IRewardDistributor.InvalidRoot.selector);
        rd.addRoot(bytes32(0));
    }

    function testOnlyOwnerCanAddARoot() public {
        address other = address(0xF00);
        assertTrue(rd.owner() != other);
        bytes32 root = bytes32(bytes1(0x11));
        vm.prank(other);
        vm.expectRevert();
        rd.addRoot(root);
    }

    function testClaimSingle() public {
        address[] memory addrs = new address[](4);
        uint256[] memory amnts = new uint256[](4);

        addrs[0] = address(0x1234);
        addrs[1] = address(0x6789);
        addrs[2] = address(0x8888);
        addrs[3] = address(0xF1F0);

        amnts[0] = 5e18;
        amnts[1] = 2.7e18;
        amnts[2] = 555e18;
        amnts[3] = 0.01e18;

        bytes32 root;
        bytes32[] memory proof;
        for (uint256 proofIdx = 0; proofIdx < 4; proofIdx++) {
            (root, proof) = _computeSimpleTree(addrs, amnts, proofIdx);
            uint256 id = rd.addRoot(root);

            address claimant = addrs[proofIdx];
            uint256 claimAmt = amnts[proofIdx];

            cypher.transfer(address(rd), claimAmt);
            uint256 balBefore = cypher.balanceOf(claimant);

            vm.prank(claimant);
            rd.claim(proof, id, claimAmt);

            uint256 balAfter = cypher.balanceOf(claimant);
            assertEq(balAfter - balBefore, claimAmt);
            assertTrue(rd.claimed(id, claimant));
        }
    }

    function _computeSimpleTree(address[] memory addrs, uint256[] memory amnts, uint256 proofIdx)
        internal
        pure
        returns (bytes32 root, bytes32[] memory proof)
    {
        proof = new bytes32[](2);

        bytes32[] memory leafHashes = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            leafHashes[i] = keccak256(bytes.concat(keccak256(abi.encode(addrs[i], amnts[i]))));
        }

        proof[0] = leafHashes[(proofIdx + 1) % 2 + (proofIdx / 2) * 2];

        bytes32 leftHash = _commutativeKeccak(leafHashes[0], leafHashes[1]);
        bytes32 rightHash = _commutativeKeccak(leafHashes[2], leafHashes[3]);

        proof[1] = proofIdx < 2 ? rightHash : leftHash;

        root = keccak256(bytes.concat(leftHash, rightHash));
        root = _commutativeKeccak(leftHash, rightHash);
    }

    function _commutativeKeccak(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(bytes.concat(a, b)) : keccak256(bytes.concat(b, a));
    }
}
