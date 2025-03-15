pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {IElection} from "../src/interfaces/IElection.sol";
import {CypherToken} from "../src/CypherToken.sol";
import {Election} from "../src/Election.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {TestToken} from "./mocks/TestToken.sol";

contract ElectionTest is Test {
    bytes32 constant CANDIDATE1 = keccak256(hex"f833a28e");
    bytes32 constant CANDIDATE2 = keccak256(hex"22222222");
    bytes32 constant CANDIDATE3 = keccak256(hex"333333");
    address constant USER1 = address(0x123456789);
    uint256 private constant VOTE_PERIOD = 2 weeks;
    uint256 private constant MAX_LOCK_DURATION = 52 * 2 weeks;

    Election election;
    VotingEscrow ve;
    CypherToken cypher;

    function setUp() public {
        cypher = new CypherToken(address(this));
        ve = new VotingEscrow(address(cypher));
        cypher.approve(address(ve), type(uint256).max);
        vm.warp(98764321);
        election = new Election(address(this), address(ve));
    }

    function testConstruction() public view {
        assertEq(election.owner(), address(this));
        assertEq(address(election.ve()), address(ve));
    }

    function testEnableDisableCandiate() public {
        assertFalse(election.isCandidate(CANDIDATE1));

        election.enableCandidate(CANDIDATE1);
        assertTrue(election.isCandidate(CANDIDATE1));

        // Enabling a second time is an error
        vm.expectRevert(IElection.CandidateAlreadyEnabled.selector);
        election.enableCandidate(CANDIDATE1);

        election.disableCandidate(CANDIDATE1);
        assertFalse(election.isCandidate(CANDIDATE1));

        // Disabling a second time is an error
        vm.expectRevert(IElection.CandidateNotEnabled.selector);
        election.disableCandidate(CANDIDATE1);
    }

    function testEnableDisableCandidateAuth() public {
        address notOwner;
        unchecked {
            notOwner = address(uint160(address(this)) + 1);
        }

        vm.prank(notOwner);
        vm.expectRevert();
        election.enableCandidate(CANDIDATE1);

        // successfully enable
        election.enableCandidate(CANDIDATE1);

        vm.prank(notOwner);
        vm.expectRevert();
        election.disableCandidate(CANDIDATE1);
    }

    function testEnableDisableBribeToken() public {
        address bribeTokenAddr = address(0x12341234);
        assertFalse(election.isBribeToken(bribeTokenAddr));

        election.enableBribeToken(bribeTokenAddr);
        assertTrue(election.isBribeToken(bribeTokenAddr));

        // Enabling a second time is an error
        vm.expectRevert(IElection.BribeTokenAlreadyEnabled.selector);
        election.enableBribeToken(bribeTokenAddr);

        election.disableBribeToken(bribeTokenAddr);
        assertFalse(election.isBribeToken(bribeTokenAddr));

        // Disabling a second time is an error
        vm.expectRevert(IElection.BribeTokenNotEnabled.selector);
        election.disableBribeToken(bribeTokenAddr);
    }

    function testEnableDisableBribeTokenAuth() public {
        address notOwner;
        unchecked {
            notOwner = address(uint160(address(this)) + 1);
        }
        address bribeTokenAddr = address(0x12341234);

        vm.prank(notOwner);
        vm.expectRevert();
        election.enableBribeToken(bribeTokenAddr);

        // successfully enable
        election.enableBribeToken(bribeTokenAddr);

        vm.prank(notOwner);
        vm.expectRevert();
        election.disableBribeToken(bribeTokenAddr);
    }

    function testVoteSingleVoterPeriodStart() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);

        _warpToNextVotePeriodStart();

        uint256 power = ve.balanceOfAt(id, block.timestamp);
        assert(power > 0);

        bytes32[] memory candidates = new bytes32[](2);
        candidates[0] = CANDIDATE1;
        candidates[1] = CANDIDATE2;

        election.enableCandidate(CANDIDATE1);
        election.enableCandidate(CANDIDATE2);

        uint256[] memory weights = new uint256[](2);

        // Weights don't have to sum to anything in particular--will be normalized based on total weight provided.
        weights[0] = 6667;
        weights[1] = 3333;
        uint256 totalWeight = weights[0] + weights[1];

        vm.expectEmit(true, true, true, true);
        emit IElection.Vote(id, address(this), candidates[0], block.timestamp, power * weights[0] / totalWeight);
        vm.expectEmit(true, true, true, true);
        emit IElection.Vote(id, address(this), candidates[1], block.timestamp, power * weights[1] / totalWeight);
        election.vote(id, candidates, weights);

        assertEq(election.lastVoteTime(id), block.timestamp);

        for (uint256 i = 0; i < 2; i++) {
            uint256 votes = power * weights[i] / totalWeight;
            assertEq(election.votesForCandidateInPeriod(candidates[i], block.timestamp), votes);
            assertEq(election.votesByTokenForCandidateInPeriod(id, candidates[i], block.timestamp), votes);
        }
    }

    // Verifies that it's voting power at the start of a period that counts.
    function testVoteSingleVoterDuringPeriod() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);

        _warpToNextVotePeriodStart();

        uint256 power = ve.balanceOfAt(id, block.timestamp);
        assert(power > 0);

        // warp into the middle of the period
        vm.warp(block.timestamp + 3 * VOTE_PERIOD / 5);

        // check that voting power has diminished (vote power from start of period will be used)
        assertLt(ve.balanceOfAt(id, block.timestamp), power);

        bytes32[] memory candidates = new bytes32[](2);
        candidates[0] = CANDIDATE1;
        candidates[1] = CANDIDATE2;

        election.enableCandidate(CANDIDATE1);
        election.enableCandidate(CANDIDATE2);

        uint256[] memory weights = new uint256[](2);

        // Weights don't have to sum to anything in particular--will be normalized based on total weight provided.
        weights[0] = 6667;
        weights[1] = 3333;
        uint256 totalWeight = weights[0] + weights[1];

        uint256 periodStart = _periodStart(block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit IElection.Vote(id, address(this), candidates[0], periodStart, power * weights[0] / totalWeight);
        vm.expectEmit(true, true, true, true);
        emit IElection.Vote(id, address(this), candidates[1], periodStart, power * weights[1] / totalWeight);
        election.vote(id, candidates, weights);

        assertEq(election.lastVoteTime(id), block.timestamp);

        for (uint256 i = 0; i < 2; i++) {
            uint256 votes = power * weights[i] / totalWeight;
            assertEq(election.votesForCandidateInPeriod(candidates[i], periodStart), votes);
            assertEq(election.votesByTokenForCandidateInPeriod(id, candidates[i], periodStart), votes);
        }
    }

    function testVoteAuthorization() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);
        _warpToNextVotePeriodStart();

        // Approve USER1 to vote for our account.
        ve.approve(USER1, id);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        vm.expectEmit(true, true, true, true);
        // The owner of the id, not the caller of vote(), is emitted.
        emit IElection.Vote(id, address(this), candidates[0], block.timestamp, ve.balanceOfAt(id, block.timestamp));
        vm.prank(USER1);
        election.vote(id, candidates, weights);

        // Just a basic check that the vote was processed correctly.
        assertEq(election.lastVoteTime(id), block.timestamp);
    }

    function testVoteUnauthorized() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);
        _warpToNextVotePeriodStart();

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        vm.prank(USER1);
        vm.expectRevert(IElection.NotAuthorizedForVoting.selector);
        election.vote(id, candidates, weights);
    }

    function testVoteArgLengthMismatch() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);
        _warpToNextVotePeriodStart();

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1e18;
        weights[1] = 1e18;

        vm.expectRevert(IElection.LengthMismatch.selector);
        election.vote(id, candidates, weights);

        candidates = new bytes32[](3);
        candidates[0] = CANDIDATE1;
        candidates[1] = CANDIDATE2;
        election.enableCandidate(CANDIDATE2);
        candidates[2] = CANDIDATE3;
        election.enableCandidate(CANDIDATE3);

        vm.expectRevert(IElection.LengthMismatch.selector);
        election.vote(id, candidates, weights);
    }

    function testVoteAlreadyVoted() public {
        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, MAX_LOCK_DURATION);
        _warpToNextVotePeriodStart();

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        election.vote(id, candidates, weights);

        vm.expectRevert(IElection.AlreadyVoted.selector);
        election.vote(id, candidates, weights);

        vm.warp(block.timestamp + VOTE_PERIOD / 2);

        vm.expectRevert(IElection.AlreadyVoted.selector);
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();
        vm.warp(block.timestamp - 1);

        vm.expectRevert(IElection.AlreadyVoted.selector);
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();

        // New period, should be able to vote again.
        election.vote(id, candidates, weights);
    }

    function testVoteNoVotingPower() public {
        _warpToNextVotePeriodStart();

        cypher.approve(address(ve), 4e18);
        uint256 id = ve.createLock(4e18, VOTE_PERIOD * 3);

        vm.warp(block.timestamp + 4 * VOTE_PERIOD);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        vm.expectRevert(IElection.NoVotingPower.selector);
        election.vote(id, candidates, weights);
    }

    function testVoteZeroWeight() public {
        _warpToNextVotePeriodStart();

        cypher.approve(address(ve), 333e18);
        uint256 id = ve.createLock(333e18, MAX_LOCK_DURATION);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 0;

        vm.expectRevert();
        election.vote(id, candidates, weights);
    }

    function testVoteWeightOverflow() public {
        _warpToNextVotePeriodStart();

        cypher.approve(address(ve), 333e18);
        uint256 id = ve.createLock(333e18, MAX_LOCK_DURATION);

        bytes32[] memory candidates = new bytes32[](2);
        candidates[0] = CANDIDATE1;
        election.enableCandidate(CANDIDATE1);
        candidates[1] = CANDIDATE2;
        election.enableCandidate(CANDIDATE2);
        uint256[] memory weights = new uint256[](2);
        weights[0] = type(uint256).max;
        weights[1] = type(uint256).max;

        vm.expectRevert();
        election.vote(id, candidates, weights);
    }

    function testVoteInvalidCandidate() public {
        _warpToNextVotePeriodStart();

        cypher.approve(address(ve), 333e18);
        uint256 id = ve.createLock(333e18, MAX_LOCK_DURATION);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;

        vm.expectRevert(IElection.InvalidCandidate.selector);
        election.vote(id, candidates, weights);
    }

    function testAddBribeBasic() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 100e18);

        election.enableBribeToken(address(bribeAsset));
        election.enableCandidate(CANDIDATE1);

        _warpToNextVotePeriodStart();

        uint256 balBefore = bribeAsset.balanceOf(address(this));
        bribeAsset.approve(address(election), 5e18);
        vm.expectEmit(true, true, true, true);
        emit IElection.BribeAdded(address(bribeAsset), CANDIDATE1, block.timestamp, 5e18);
        election.addBribe(address(bribeAsset), 5e18, CANDIDATE1);

        assertEq(
            election.amountOfBribeTokenForCandidateInPeriod(address(bribeAsset), CANDIDATE1, block.timestamp), 5e18
        );
        assertEq(bribeAsset.balanceOf(address(this)), balBefore - 5e18);

        vm.warp(block.timestamp + 3 * VOTE_PERIOD / 4);

        balBefore = bribeAsset.balanceOf(address(this));
        bribeAsset.approve(address(election), 3e18);
        vm.expectEmit(true, true, true, true);
        emit IElection.BribeAdded(address(bribeAsset), CANDIDATE1, _periodStart(block.timestamp), 3e18);
        election.addBribe(address(bribeAsset), 3e18, CANDIDATE1);

        assertEq(
            election.amountOfBribeTokenForCandidateInPeriod(
                address(bribeAsset), CANDIDATE1, _periodStart(block.timestamp)
            ),
            8e18
        );
        assertEq(bribeAsset.balanceOf(address(this)), balBefore - 3e18);
    }

    function testAddBribeInvalidBribeToken() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 100e18);

        election.enableCandidate(CANDIDATE1);

        _warpToNextVotePeriodStart();

        bribeAsset.approve(address(election), 5e18);
        vm.expectRevert(IElection.InvalidBribeToken.selector);
        election.addBribe(address(bribeAsset), 5e18, CANDIDATE1);
    }

    function testAddBribeInvalidCandidate() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 100e18);

        election.enableBribeToken(address(bribeAsset));

        _warpToNextVotePeriodStart();

        bribeAsset.approve(address(election), 5e18);
        vm.expectRevert(IElection.InvalidCandidate.selector);
        election.addBribe(address(bribeAsset), 5e18, CANDIDATE1);
    }

    function testClaimBribesBasic() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 100e18);

        cypher.approve(address(ve), 10e18);
        uint256 id = ve.createLock(10e18, MAX_LOCK_DURATION);

        _warpToNextVotePeriodStart();

        election.enableCandidate(CANDIDATE1);

        election.enableBribeToken(address(bribeAsset));
        bribeAsset.approve(address(election), 5e18);
        vm.expectEmit(true, true, true, true);
        emit IElection.BribeAdded(address(bribeAsset), CANDIDATE1, block.timestamp, 5e18);
        election.addBribe(address(bribeAsset), 5e18, CANDIDATE1);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();
        uint256 previousPeriod = block.timestamp - VOTE_PERIOD;
        address[] memory bribeTokens = new address[](1);
        bribeTokens[0] = address(bribeAsset);

        uint256 balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, bribeTokens, candidates, previousPeriod, previousPeriod);
        assertEq(bribeAsset.balanceOf(address(this)) - balBefore, 5e18); // Receive entire bribe.
        assertTrue(election.hasClaimedBribe(id, address(bribeAsset), CANDIDATE1, previousPeriod));

        // Attempting a second claim is a no-op
        balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, bribeTokens, candidates, previousPeriod, previousPeriod);
        assertEq(bribeAsset.balanceOf(address(this)), balBefore);
    }

    function _warpToNextVotePeriodStart() internal {
        vm.warp(block.timestamp + VOTE_PERIOD - block.timestamp % VOTE_PERIOD);
    }

    function _periodStart(uint256 t) internal pure returns (uint256) {
        return t / VOTE_PERIOD * VOTE_PERIOD;
    }
}
