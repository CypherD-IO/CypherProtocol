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
        (bytes32 root, address[] memory addrs, uint256[] memory amnts, bytes32[] memory proof) = _constructSimpleTree();
        uint256 id = rd.addRoot(root);

        cypher.transfer(address(rd), amnts[1]);
        uint256 balBefore = cypher.balanceOf(addrs[1]);

        vm.prank(addrs[1]);
        rd.claim(proof, id, amnts[1]);

        uint256 balAfter = cypher.balanceOf(addrs[1]);
        assertEq(balAfter - balBefore, amnts[1]);
        assertTrue(rd.claimed(id, addrs[1]));
    }

    function _constructSimpleTree() internal pure returns (bytes32 root, address[] memory addrs, uint256[] memory amnts, bytes32[] memory proof) {
        addrs = new address[](4);
        amnts = new uint256[](4);

        addrs[0] = address(0x1234);
        addrs[1] = address(0x6789);
        addrs[2] = address(0x8888);
        addrs[3] = address(0xF1F0);

        amnts[0] = 5e18;
        amnts[1] = 2.7e18;
        amnts[2] = 555e18;
        amnts[3] = 0.01e18;

        proof = new bytes32[](2);

        bytes32[] memory leafHashes = new bytes32[](4);
        for(uint256 i = 0; i < 4; i++) {
            leafHashes[i] = keccak256(bytes.concat(keccak256(abi.encode(addrs[i], amnts[i]))));
        }

        proof[0] = leafHashes[0];

        bytes32 leftHash  = keccak256(bytes.concat(leafHashes[0], leafHashes[1]));
        bytes32 rightHash = keccak256(bytes.concat(leafHashes[2], leafHashes[3]));

        proof[1] = rightHash;

        root = keccak256(bytes.concat(leftHash, rightHash));
    }
}
