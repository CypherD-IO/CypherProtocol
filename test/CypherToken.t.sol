pragma solidity =0.8.28;

import "forge-std/Test.sol";

import "../src/CypherToken.sol";

contract CypherTokenTest is Test {
    CypherToken token;

    function setUp() public {
        token = new CypherToken(address(this));
    }

    function testConstruction() public view {
        assertEq(token.name(), "Cypher");
        assertEq(token.symbol(), "CYPR");
        assertEq(token.totalSupply(), 499_500_000 * 1e18);
        assertEq(token.balanceOf(address(this)), token.totalSupply());
    }

    function testClock(uint256 ts) public {
        vm.warp(ts % type(uint48).max);
        assertEq(token.clock(), block.timestamp);
        assertEq(token.CLOCK_MODE(), "mode=timestamp");
    }

    function testCheckpointing() public {
        address other = address(0x1234);
        address delegate = address(0xde1e947e);
        assert(other != address(this));

        token.delegate(address(this));
        assertEq(token.getVotes(address(this)), token.balanceOf(address(this)));

        vm.warp(block.timestamp + 22);

        token.delegate(delegate);
        assertEq(token.getVotes(address(this)), 0);
        assertEq(token.getVotes(delegate), token.balanceOf(address(this)));

        vm.warp(block.timestamp + 41);

        token.transfer(other, token.balanceOf(address(this)));
        assertEq(token.getVotes(delegate), 0);
        assertEq(token.getVotes(address(this)), 0);
        assertEq(token.getVotes(other), 0);
        assertEq(token.numCheckpoints(address(this)), 2);
        assertEq(token.numCheckpoints(delegate), 2);

        vm.prank(other);
        token.delegate(other);
        assertEq(token.getVotes(other), token.balanceOf(address(other)));
        assertEq(token.numCheckpoints(other), 1);
    }
}
