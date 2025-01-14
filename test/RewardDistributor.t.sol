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
}
