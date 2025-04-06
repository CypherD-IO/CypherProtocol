// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {CypherToken} from "src/CypherToken.sol";
import {IVotingEscrow} from "src/interfaces/IVotingEscrow.sol";
import {VotingEscrow} from "src/VotingEscrow.sol";

import {ReenteringActor} from "test/mocks/ReenteringActor.sol";
import {ReenteringToken} from "test/mocks/ReenteringToken.sol";

contract VotingEscrowUnitTest is Test {
    using SafeCast for int128;

    uint256 private constant VOTE_PERIOD = 2 weeks;
    uint256 private constant INIT_TIMESTAMP = 100_000_000;
    uint256 private constant MAX_LOCK_DURATION = 52 * VOTE_PERIOD;

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
        assertTrue(!isIndefinite);
    }

    function testCreateLockReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 1e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(token));
        reenterer.makeCall(abi.encodeWithSelector(IERC20.approve.selector, address(ve), type(uint256).max));
        reenterer.setTarget(address(ve));
        token.mint(address(reenterer), 1e18);

        bytes memory createLockData = abi.encodeWithSelector(IVotingEscrow.createLock.selector, 1e18, 8 * VOTE_PERIOD);
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, createLockData);
        token.setCall(address(reenterer), makeCallData);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.createLock(1e18, 12 * VOTE_PERIOD);
    }

    function testCreateLockDurationAdditionOverfow() public {
        vm.expectRevert(stdError.arithmeticError);
        ve.createLock(1e18, type(uint256).max);
    }

    function testCreateLockDurationExceedsMaximum() public {
        vm.expectRevert(IVotingEscrow.LockDurationExceedsMaximum.selector);
        ve.createLock(1e18, 53 * VOTE_PERIOD);
    }

    function testCreateLockZeroValue() public {
        vm.expectRevert(IVotingEscrow.ZeroValue.selector);
        ve.createLock(0, 8 * VOTE_PERIOD);
    }

    function testCreateLockUnlockTimeNotInFuture() public {
        assert(block.timestamp % VOTE_PERIOD != 0);
        vm.expectRevert(IVotingEscrow.UnlockTimeNotInFuture.selector);
        ve.createLock(1e18, 1);
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
        assertTrue(!isIndefinite);
    }

    function testCreateLockForReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 1e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(token));
        reenterer.makeCall(abi.encodeWithSelector(IERC20.approve.selector, address(ve), type(uint256).max));
        reenterer.setTarget(address(ve));
        token.mint(address(reenterer), 1e18);

        bytes memory createLockForData =
            abi.encodeWithSelector(IVotingEscrow.createLockFor.selector, 1e18, 8 * VOTE_PERIOD, address(this));
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, createLockForData);
        token.setCall(address(reenterer), makeCallData);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.createLockFor(1e18, 12 * VOTE_PERIOD, address(this));
    }

    function testCreateLockForDurationAdditionOverfow() public {
        vm.expectRevert(stdError.arithmeticError);
        ve.createLockFor(1e18, type(uint256).max, address(this));
    }

    function testCreateLockForDurationExceedsMaximum() public {
        vm.expectRevert(IVotingEscrow.LockDurationExceedsMaximum.selector);
        ve.createLockFor(1e18, 53 * VOTE_PERIOD, address(this));
    }

    function testCreateLockForZeroValue() public {
        vm.expectRevert(IVotingEscrow.ZeroValue.selector);
        ve.createLockFor(0, 8 * VOTE_PERIOD, address(this));
    }

    function testCreateLockForUnlockTimeNotInFuture() public {
        assert(block.timestamp % VOTE_PERIOD != 0);
        vm.expectRevert(IVotingEscrow.UnlockTimeNotInFuture.selector);
        ve.createLockFor(1e18, 1, address(this));
    }

    function testDepositForBasic() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        uint256 unlockTime = ((block.timestamp + 2 * VOTE_PERIOD) / VOTE_PERIOD) * VOTE_PERIOD;

        uint256 cypherBalBefore = cypher.balanceOf(address(this));
        ve.depositFor(id, 2e18);
        assertEq(cypher.balanceOf(address(this)), cypherBalBefore - 2e18);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(id);
        assertEq(amount, 3e18);
        assertEq(end, unlockTime);
        assert(!isIndefinite);

        vm.warp(INIT_TIMESTAMP + 3 days);
        ve.depositFor(id, 2e18);
        (amount, end, isIndefinite) = ve.locked(1);
        assertEq(amount, 5e18);
        assertEq(end, unlockTime);
        assertTrue(!isIndefinite);
    }

    function testDepositForIndefinite() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        ve.lockIndefinite(id);

        vm.warp(INIT_TIMESTAMP + 365 days);

        ve.depositFor(id, 2e18);
        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(id);
        assertEq(amount, 3e18);
        assertEq(end, 0);
        assertTrue(isIndefinite);
    }

    function testDepositForReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 2e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        uint256 id = ve.createLock(1e18, 42 * VOTE_PERIOD);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(token));
        reenterer.makeCall(abi.encodeWithSelector(IERC20.approve.selector, address(ve), type(uint256).max));
        reenterer.setTarget(address(ve));
        token.mint(address(reenterer), 1e18);

        bytes memory depositForData = abi.encodeWithSelector(IVotingEscrow.depositFor.selector, id, 1e18);
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, depositForData);
        token.setCall(address(reenterer), makeCallData);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.depositFor(id, 1e18);
    }

    function testDepositForZeroValue() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        vm.expectRevert(IVotingEscrow.ZeroValue.selector);
        ve.depositFor(id, 0);
    }

    function testDepositForTokenDoesNotExist() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id + 1));
        ve.depositFor(id + 1, 1e18);
    }

    function testDepositForLockExpired() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);

        vm.warp(end);
        vm.expectRevert(IVotingEscrow.LockExpired.selector);
        ve.depositFor(id, 1e18);

        vm.warp(end + 1);
        vm.expectRevert(IVotingEscrow.LockExpired.selector);
        ve.depositFor(id, 1e18);
    }

    function testIncreaseUnlockTimeBasic() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(id);

        // advance by one vote period
        ve.increaseUnlockTime(id, end + VOTE_PERIOD);

        (, uint256 newEnd,) = ve.locked(id);
        assertEq(newEnd, end + VOTE_PERIOD);

        // confirm rounding down to nearest vote period
        ve.increaseUnlockTime(id, newEnd + 3 * VOTE_PERIOD / 2);

        (, uint256 newerEnd,) = ve.locked(1);
        assertEq(newerEnd, newEnd + VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeAuthorization() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);

        address other = address(0x1234);
        assert(other != address(this));

        vm.startPrank(other);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, other, id));
        ve.increaseUnlockTime(id, end + 3 * VOTE_PERIOD);
        vm.stopPrank();

        ve.approve(other, id);

        vm.startPrank(other);
        ve.increaseUnlockTime(id, end + 3 * VOTE_PERIOD);
        vm.stopPrank();

        (, uint256 newEnd,) = ve.locked(id);
        assertEq(newEnd, (end + 3 * VOTE_PERIOD) / VOTE_PERIOD * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 2e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(ve));

        bytes memory increaseUnlockTimeData =
            abi.encodeWithSelector(IVotingEscrow.increaseUnlockTime.selector, id, end + 2 * VOTE_PERIOD);
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, increaseUnlockTimeData);
        token.setCall(address(reenterer), makeCallData);
        ve.approve(address(reenterer), id);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.createLock(1e18, 8 * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeIndefinite() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        ve.lockIndefinite(id);

        (, uint256 end,) = ve.locked(id);

        vm.expectRevert(IVotingEscrow.LockedIndefinitely.selector);
        ve.increaseUnlockTime(id, end + 9 * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeLockExpired() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(id);

        vm.warp(end);
        vm.expectRevert(IVotingEscrow.LockExpired.selector);
        ve.increaseUnlockTime(id, end + 9 * VOTE_PERIOD);

        vm.warp(end + 1);
        vm.expectRevert(IVotingEscrow.LockExpired.selector);
        ve.increaseUnlockTime(id, end + 9 * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeDurationExceedsMaximum() public {
        vm.warp(INIT_TIMESTAMP / VOTE_PERIOD * VOTE_PERIOD);
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(id);

        // This will be exactly the maximum duration, and will succeed.
        ve.increaseUnlockTime(id, end + 50 * VOTE_PERIOD);

        // One more vote period is too many
        vm.expectRevert(IVotingEscrow.LockDurationExceedsMaximum.selector);
        ve.increaseUnlockTime(id, end + 51 * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeNotAfterOld() public {
        uint256 id = ve.createLock(1e18, 20 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(id);

        vm.expectRevert(IVotingEscrow.NewUnlockTimeNotAfterOld.selector);
        ve.increaseUnlockTime(id, end);

        // This still fails due to rounding the end time down to the nearest vote period.
        vm.expectRevert(IVotingEscrow.NewUnlockTimeNotAfterOld.selector);
        ve.increaseUnlockTime(id, end + VOTE_PERIOD / 2);

        vm.expectRevert(IVotingEscrow.NewUnlockTimeNotAfterOld.selector);
        ve.increaseUnlockTime(id, end - 2 * VOTE_PERIOD);
    }

    function testIncreaseUnlockTimeNewTimeInPast() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        (, uint256 end,) = ve.locked(id);

        vm.expectRevert(IVotingEscrow.NewUnlockTimeNotAfterOld.selector);
        ve.increaseUnlockTime(id, end - 3 * VOTE_PERIOD);
    }

    function testWithdrawBasic() public {
        uint256 id = ve.createLock(1e18, 17 * VOTE_PERIOD);

        (int128 amount, uint256 end,) = ve.locked(id);

        vm.warp(end);

        uint256 cypherBalBefore = cypher.balanceOf(address(this));
        ve.withdraw(id);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id));
        ve.ownerOf(id);

        assertEq(cypher.balanceOf(address(this)), cypherBalBefore + amount.toUint256());

        (int128 amountAfter, uint256 endAfter, bool isIndefiniteAfter) = ve.locked(id);
        assertEq(amountAfter, 0);
        assertEq(endAfter, 0);
        assert(!isIndefiniteAfter);
    }

    function testWithdrawAuthorization() public {
        uint256 id = ve.createLock(1e18, 10 * VOTE_PERIOD);

        (int128 amount, uint256 end,) = ve.locked(id);

        vm.warp(end);

        address other = address(0x1234);
        assert(other != address(this));

        vm.startPrank(other);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, other, id));
        ve.withdraw(id);
        vm.stopPrank();

        ve.approve(other, id);
        uint256 cypherBalOtherBefore = cypher.balanceOf(other);

        vm.startPrank(other);
        ve.withdraw(id);
        vm.stopPrank();

        assertEq(cypher.balanceOf(other) - cypherBalOtherBefore, uint256(int256(amount)));
    }

    function testWithdrawReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 2e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);
        vm.warp(end);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(ve));

        bytes memory withdrawData = abi.encodeWithSelector(IVotingEscrow.withdraw.selector, id);
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, withdrawData);
        token.setCall(address(reenterer), makeCallData);
        ve.approve(address(reenterer), id);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.createLock(1e18, 8 * VOTE_PERIOD);

        token.setCall(address(0), bytes.concat(""));

        uint256 id2 = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, end,) = ve.locked(id2);
        vm.warp(end);

        token.setCall(address(reenterer), makeCallData);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.withdraw(id2);
    }

    function testWithdrawLockedIndefinitely() public {
        uint256 id = ve.createLock(1e18, 30 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);
        ve.lockIndefinite(id);
        vm.warp(end);

        vm.expectRevert(IVotingEscrow.LockedIndefinitely.selector);
        ve.withdraw(id);
    }

    function testWithdrawLockNotExpired() public {
        uint256 id = ve.createLock(1e18, 30 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);
        vm.warp(end - 1);

        vm.expectRevert(IVotingEscrow.LockNotExpired.selector);
        ve.withdraw(id);
    }

    function testWithdrawTokenDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 18));
        ve.withdraw(18);

        uint256 id = ve.createLock(1e18, 30 * VOTE_PERIOD);
        ve.createLock(1e18, 30 * VOTE_PERIOD); // ensure more tokens available to withdraw than just from the first lock
        (, uint256 end,) = ve.locked(id);
        vm.warp(end);

        ve.withdraw(id);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id));
        ve.withdraw(id);
    }

    function testLockIndefiniteBasic(uint256 tsSeed) public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        ve.lockIndefinite(id);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(id);
        assertEq(amount, 1e18);
        assertEq(end, 0);
        assertTrue(isIndefinite);
        assertEq(ve.indefiniteLockBalance(), amount.toUint256());

        uint256 ts = tsSeed > block.timestamp ? tsSeed : block.timestamp + tsSeed;
        assertEq(ve.balanceOfAt(id, ts), 1e18);
    }

    function testLockIndefiniteAuthorization() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        address other = address(0x1234);
        assert(other != address(this));

        vm.startPrank(other);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, other, id));
        ve.lockIndefinite(id);
        vm.stopPrank();

        ve.approve(address(other), id);

        ve.lockIndefinite(id);
        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(id);
        assertEq(amount, 1e18);
        assertEq(end, 0);
        assertTrue(isIndefinite);
        assertEq(ve.indefiniteLockBalance(), amount.toUint256());
    }

    function testLockIndefiniteReentrancy() public {
        ReenteringToken token = new ReenteringToken();
        ve = new VotingEscrow(address(token));
        token.mint(address(this), 2e18);
        token.approve(address(ve), type(uint256).max);
        vm.warp(INIT_TIMESTAMP);

        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        ReenteringActor reenterer = new ReenteringActor();
        reenterer.setTarget(address(ve));

        bytes memory lockIndefiniteData = abi.encodeWithSelector(IVotingEscrow.lockIndefinite.selector, id);
        bytes memory makeCallData = abi.encodeWithSelector(ReenteringActor.makeCall.selector, lockIndefiniteData);
        token.setCall(address(reenterer), makeCallData);
        ve.approve(address(reenterer), id);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        ve.createLock(1e18, 8 * VOTE_PERIOD);
    }

    function testLockIndefiniteTokenDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 7));
        ve.lockIndefinite(7);
    }

    function testLockIndefiniteAlreadyIndefinite() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        ve.lockIndefinite(id);

        vm.expectRevert(IVotingEscrow.LockedIndefinitely.selector);
        ve.lockIndefinite(id);
    }

    function testLockIndefiniteLockExpired() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);
        (, uint256 end,) = ve.locked(id);
        vm.warp(end);

        vm.expectRevert(IVotingEscrow.LockExpired.selector);
        ve.lockIndefinite(id);
    }

    function testUnlockIndefiniteBasic() public {
        uint256 id = ve.createLock(1e18, 2 * VOTE_PERIOD);

        ve.lockIndefinite(id);

        ve.unlockIndefinite(id);
        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(id);
        assertEq(amount, 1e18);
        assertEq(end, ((block.timestamp + MAX_LOCK_DURATION) / VOTE_PERIOD) * VOTE_PERIOD);
        assertTrue(!isIndefinite);
        assertEq(ve.indefiniteLockBalance(), 0);
    }

    function testMergeBasic() public {
        uint256 idFrom = ve.createLock(1e18, 2 * VOTE_PERIOD);
        uint256 idTo = ve.createLock(3e18, 5 * VOTE_PERIOD);

        ve.merge(idFrom, idTo);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(idTo);
        assertEq(amount, 4e18);
        assertEq(end, ((block.timestamp + 5 * VOTE_PERIOD) / VOTE_PERIOD) * VOTE_PERIOD);
        assertTrue(!isIndefinite);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, idFrom));
        ve.ownerOf(idFrom);

        (amount, end, isIndefinite) = ve.locked(idFrom);
        assertEq(amount, 0);
        assertEq(end, 0);
        assertTrue(!isIndefinite);
    }

    function testMergeToIndefinite() public {
        uint256 idFrom = ve.createLock(9e18, 6 * VOTE_PERIOD);
        uint256 idTo = ve.createLock(0.1e18, MAX_LOCK_DURATION);
        ve.lockIndefinite(idTo);

        ve.merge(idFrom, idTo);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(idTo);
        assertEq(amount, 9.1e18);
        assertEq(end, 0);
        assertTrue(isIndefinite);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, idFrom));
        ve.ownerOf(idFrom);

        (amount, end, isIndefinite) = ve.locked(idFrom);
        assertEq(amount, 0);
        assertEq(end, 0);
        assertTrue(!isIndefinite);
    }

    function testMergeFromExpired() public {
        uint256 initTime = _get2TimesTimestamp() / 2; // work around the optimizer

        uint256 idFrom = ve.createLock(1e18, 2 * VOTE_PERIOD);

        vm.warp(initTime + 4 * VOTE_PERIOD);

        uint256 idTo = ve.createLock(2e18, 16 * VOTE_PERIOD);

        ve.merge(idFrom, idTo);

        (int128 amount, uint256 end, bool isIndefinite) = ve.locked(idTo);
        assertEq(amount, 3e18);
        assertEq(end, ((initTime + 20 * VOTE_PERIOD) / VOTE_PERIOD) * VOTE_PERIOD);
        assertTrue(!isIndefinite);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, idFrom));
        ve.ownerOf(idFrom);

        (amount, end, isIndefinite) = ve.locked(idFrom);
        assertEq(amount, 0);
        assertEq(end, 0);
        assertTrue(!isIndefinite);
    }

    function testMergeFuzz(
        uint256 startTimeSeed,
        uint256 fromValueSeed,
        uint256 fromDurationSeed,
        uint256 toValueSeed,
        uint256 toDurationSeed
    ) public {
        vm.warp(block.timestamp + startTimeSeed % MAX_LOCK_DURATION);
        uint256 idFrom;
        uint256 idTo;

        {
            uint256 totalCypherAvailable = cypher.balanceOf(address(this));
            uint256 value = bound(fromValueSeed, 1, totalCypherAvailable - 1);
            uint256 duration = bound(fromDurationSeed, VOTE_PERIOD + 1, MAX_LOCK_DURATION);
            idFrom = ve.createLock(value, duration);

            value = bound(toValueSeed, 1, totalCypherAvailable - value);
            duration = bound(toDurationSeed, VOTE_PERIOD + 1, MAX_LOCK_DURATION);
            idTo = ve.createLock(value, duration);
        }
        (int128 amountFrom, uint256 endFrom,) = ve.locked(idFrom);
        (int128 amountTo, uint256 endTo,) = ve.locked(idTo);

        ve.merge(idFrom, idTo);

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, idFrom));
        ve.ownerOf(idFrom);

        (int128 amount, uint256 end,) = ve.locked(idFrom);
        assertEq(amount, 0);
        assertEq(end, 0);

        (amount, end,) = ve.locked(idTo);
        assertEq(amount, amountFrom + amountTo);
        assertEq(end, endFrom > endTo ? endFrom : endTo);
    }

    function testVoteWeightDecayOnePositionAligned() public {
        uint256 initTimestamp = INIT_TIMESTAMP - (INIT_TIMESTAMP % VOTE_PERIOD);
        vm.warp(initTimestamp);

        uint256 id = ve.createLock(10e18, MAX_LOCK_DURATION);
        uint256[] memory times = new uint256[](4);
        times[0] = initTimestamp;
        times[1] = initTimestamp + MAX_LOCK_DURATION / 2;
        times[2] = initTimestamp + MAX_LOCK_DURATION;
        times[3] = initTimestamp + 3 * MAX_LOCK_DURATION;

        for (uint256 i = 0; i < times.length; i++) {
            vm.warp(times[i]);
            assertEq(ve.balanceOfAt(id, initTimestamp - 1), 0);
            assertEq(ve.totalSupplyAt(initTimestamp - 1), 0);
            assertEq(ve.balanceOfAt(id, initTimestamp), 9999999999966412800);
            assertEq(ve.totalSupplyAt(initTimestamp), 9999999999966412800);
            assertEq(ve.balanceOfAt(id, initTimestamp + MAX_LOCK_DURATION / 2), 4999999999983206400);
            assertEq(ve.totalSupplyAt(initTimestamp + MAX_LOCK_DURATION / 2), 4999999999983206400);
            assertEq(ve.balanceOfAt(id, initTimestamp + MAX_LOCK_DURATION), 0);
            assertEq(ve.totalSupplyAt(initTimestamp + MAX_LOCK_DURATION), 0);
            assertEq(ve.balanceOfAt(id, initTimestamp + 3 * MAX_LOCK_DURATION), 0);
            assertEq(ve.totalSupplyAt(initTimestamp + 3 * MAX_LOCK_DURATION), 0);
        }
    }

    function testVoteWeightDecayOnePositionUnaligned() public {
        uint256 initTimestamp = INIT_TIMESTAMP;
        assert(initTimestamp % VOTE_PERIOD > 0);
        assert(block.timestamp == INIT_TIMESTAMP);

        uint256 id = ve.createLock(35e18, MAX_LOCK_DURATION);
        uint256[] memory times = new uint256[](4);
        times[0] = initTimestamp;
        times[1] = MAX_LOCK_DURATION / 2;
        times[2] = 62086400;
        times[3] = initTimestamp + MAX_LOCK_DURATION;

        for (uint256 i = 0; i < times.length; i++) {
            vm.warp(times[i]);
            assertEq(ve.balanceOfAt(id, initTimestamp - 1_000), 0);
            assertEq(ve.totalSupplyAt(initTimestamp - 1_000), 0);
            assertEq(ve.balanceOfAt(id, initTimestamp), 34547720797666848000);
            assertEq(ve.totalSupplyAt(initTimestamp), 34547720797666848000);
            assertEq(ve.balanceOfAt(id, initTimestamp + MAX_LOCK_DURATION / 2), 17047720797694176000);
            assertEq(ve.totalSupplyAt(initTimestamp + MAX_LOCK_DURATION / 2), 17047720797694176000);
            assertEq(ve.balanceOfAt(id, initTimestamp + 62086400), 0);
            assertEq(ve.totalSupplyAt(initTimestamp + 62086400), 0);
            assertEq(ve.balanceOfAt(id, initTimestamp + MAX_LOCK_DURATION), 0);
            assertEq(ve.totalSupplyAt(initTimestamp + MAX_LOCK_DURATION), 0);
        }
    }

    function testVoteWeightDecayPartialPeriod(uint256 betweenSeed) public {
        uint256 initTimestamp = INIT_TIMESTAMP;
        assert(block.timestamp == INIT_TIMESTAMP);

        uint256 id = ve.createLock(36e18, MAX_LOCK_DURATION / 9);
        (, uint256 end,) = ve.locked(id);
        uint256 between = initTimestamp + 1 + (betweenSeed % (end - initTimestamp - 2));
        uint256 balBetween = 3688644688642611200 - (36e18 / MAX_LOCK_DURATION) * (between - initTimestamp);
        uint256[] memory times = new uint256[](4);
        times[0] = initTimestamp;
        times[1] = between;
        times[2] = end;
        times[3] = end + 1;

        for (uint256 i = 0; i < times.length; i++) {
            vm.warp(times[i]);
            assertEq(ve.balanceOfAt(id, initTimestamp), 3688644688642611200);
            assertEq(ve.totalSupplyAt(initTimestamp), 3688644688642611200);
            assertEq(ve.balanceOfAt(id, between), balBetween);
            assertEq(ve.totalSupplyAt(between), balBetween);
            assertEq(ve.balanceOfAt(id, end), 0);
            assertEq(ve.totalSupplyAt(end), 0);
            assertEq(ve.balanceOfAt(id, end + 1), 0);
            assertEq(ve.totalSupplyAt(end + 1), 0);
        }
    }

    function testVoteWeightDecayMultiplePositions() public {
        uint256 initTimestamp = INIT_TIMESTAMP;
        assert(block.timestamp == INIT_TIMESTAMP);

        uint256 id1 = ve.createLock(121e18, MAX_LOCK_DURATION);
        (, uint256 end1,) = ve.locked(id1);
        uint256 slope1 = 121e18 / MAX_LOCK_DURATION;
        uint256 bias1 = slope1 * (end1 - block.timestamp);

        uint256 secondLockStartTime = initTimestamp + VOTE_PERIOD;
        vm.warp(secondLockStartTime);

        uint256 id2 = ve.createLock(77e18, MAX_LOCK_DURATION * 2 / 3);
        (, uint256 end2,) = ve.locked(id2);
        uint256 slope2 = 77e18 / MAX_LOCK_DURATION;
        uint256 bias2 = slope2 * (end2 - block.timestamp);

        uint256 ts = initTimestamp;
        assertEq(ve.totalSupplyAt(ts), ve.balanceOfAt(id1, ts));
        assertEq(ve.balanceOfAt(id1, ts), bias1);
        assertEq(ve.balanceOfAt(id2, ts), 0);

        ts = secondLockStartTime;
        assertEq(ve.totalSupplyAt(ts), ve.balanceOfAt(id1, ts) + ve.balanceOfAt(id2, ts));
        assertEq(ve.balanceOfAt(id1, ts), bias1 - slope1 * (ts - initTimestamp));
        assertEq(ve.balanceOfAt(id2, ts), bias2);

        uint256 bothActiveTime = secondLockStartTime + MAX_LOCK_DURATION / 3;
        assert(bothActiveTime < end1 && bothActiveTime < end2);
        ts = bothActiveTime;
        assertEq(ve.totalSupplyAt(ts), ve.balanceOfAt(id1, ts) + ve.balanceOfAt(id2, ts));
        assertEq(ve.balanceOfAt(id1, ts), bias1 - slope1 * (ts - initTimestamp));
        assertEq(ve.balanceOfAt(id2, ts), bias2 - slope2 * (ts - secondLockStartTime));

        assert(end2 < end1);
        ts = end2;
        assertEq(ve.totalSupplyAt(ts), ve.balanceOfAt(id1, ts));
        assertEq(ve.balanceOfAt(id1, ts), bias1 - slope1 * (ts - initTimestamp));
        assertEq(ve.balanceOfAt(id2, ts), 0);

        ts = end1;
        assertEq(ve.totalSupplyAt(ts), 0);
        assertEq(ve.balanceOfAt(id1, ts), 0);
        assertEq(ve.balanceOfAt(id2, ts), 0);
    }

    function _get2TimesTimestamp() internal view returns (uint256) {
        return block.timestamp * 2;
    }
}
