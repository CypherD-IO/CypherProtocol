pragma solidity =0.8.28;

import "forge-std/Test.sol";

import "../src/CypherToken.sol";
import "../src/VotingEscrow.sol";

contract VotingEscrowTest is Test {

    uint256 private constant VOTE_PERIOD = 2 weeks;
    uint256 private constant INIT_TIMESTAMP = 100_000_000;

    VotingEscrow ve;
    CypherToken cypher;

    function setUp() public {
        cypher = new CypherToken(address(this));
        ve = new VotingEscrow(address(cypher));
        cypher.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);
    }

    function testConstruction() public view {
        assert(ve.nextId() == 1);
    }

    function testCreatLockBasic() public {
        uint256 cypherBalBefore = cypher.balanceOf(address(this));

        uint256 duration = 10 * VOTE_PERIOD;
        uint256 id = ve.createLock(1e18, duration);

        assertEq(id, 1);
        assertEq(ve.ownerOf(id), address(this));
        assertEq(cypher.balanceOf(address(this)), cypherBalBefore - 1e18);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(1);
        assertEq(amount, 1e18);
        assertEq(end, ((block.timestamp + duration) / VOTE_PERIOD) * VOTE_PERIOD);
        assert(!isIndefinite);
    }
}
