pragma solidity =0.8.28;

import "forge-std/Test.sol";

import "../src/CypherToken.sol";
import "../src/VotingEscrow.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract VotingEscrowTest is Test {
    using SafeCast for int128;

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

    function testCreatLockForBasic() public {
        uint256 cypherBalBefore = cypher.balanceOf(address(this));

        uint256 duration = 10 * VOTE_PERIOD;
        address to = address(0x1234);
        uint256 id = ve.createLockFor(1e18, duration, to);

        assertEq(id, 1);
        assertEq(ve.ownerOf(id), to);
        assertEq(cypher.balanceOf(address(this)), cypherBalBefore - 1e18);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(1);
        assertEq(amount, 1e18);
        assertEq(end, ((block.timestamp + duration) / VOTE_PERIOD) * VOTE_PERIOD);
        assert(!isIndefinite);
    }

    function testDepositForBasic() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        uint256 unlockTime = ((block.timestamp + 2 * VOTE_PERIOD) / VOTE_PERIOD) * VOTE_PERIOD;

        uint256 cypherBalBefore = cypher.balanceOf(address(this));
        ve.depositFor(id, 2e18);
        assertEq(cypher.balanceOf(address(this)), cypherBalBefore - 2e18);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(1);
        assertEq(amount, 3e18);
        assertEq(end, unlockTime);
        assert(!isIndefinite);

        vm.warp(INIT_TIMESTAMP + 3 days);
        ve.depositFor(id, 2e18);
        (amount, end, isIndefinite) = ve.locked(1);
        assertEq(amount, 5e18);
        assertEq(end, unlockTime);
        assert(!isIndefinite);
    }

    function testIncreaseUnlockTimeBasic() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(1);

        // advance by one vote period
        ve.increaseUnlockTime(id, end + VOTE_PERIOD);

        (, uint256 newEnd,) = ve.locked(1);
        assertEq(newEnd, end + VOTE_PERIOD);

        // confirm rounding down to nearest vote period
        ve.increaseUnlockTime(id, newEnd + 3 * VOTE_PERIOD / 2);

        (, uint256 newerEnd,) = ve.locked(1);
        assertEq(newerEnd, newEnd + VOTE_PERIOD);
    }

    function testWithdrawBasic() public {
        uint256 id = ve.createLock(1e18, 17 * VOTE_PERIOD);

        (int128 amount, uint256 end,) = ve.locked(1);

        vm.warp(end);

        uint256 cypherBalBefore = cypher.balanceOf(address(this));
        ve.withdraw(id);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        ve.ownerOf(id);

        assertEq(cypher.balanceOf(address(this)), cypherBalBefore + amount.toUint256());

        (int128 amountAfter, uint256 endAfter, bool isIndefiniteAfter) = ve.locked(id);
        assertEq(amountAfter, 0);
        assertEq(endAfter, 0);
        assert(!isIndefiniteAfter);
    }
}
