pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {IElection} from "../src/interfaces/IElection.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {CypherToken} from "../src/CypherToken.sol";
import {Election} from "../src/Election.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
import {TestToken} from "./mocks/TestToken.sol";

contract ReenteringToken is TestToken {
    address target;
    bytes data;

    function setCall(address _target, bytes memory _data) external {
        target = _target;
        data = _data;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (target != address(0)) {
            (bool ok, bytes memory err) = target.call{value: 0}(data);
            if (!ok) {
                uint256 len = err.length;
                assembly ("memory-safe") {
                    revert(add(err, 0x20), len)
                }
            }
            target = address(0);
        }

        super._update(from, to, value);
    }
}

contract ElectionTest is Test {
    bytes32 constant CANDIDATE1 = keccak256(hex"f833a28e");
    bytes32 constant CANDIDATE2 = keccak256(hex"22222222");
    bytes32 constant CANDIDATE3 = keccak256(hex"333333");
    address constant USER1 = address(0x123456789);
    address constant USER2 = address(0x987654321);
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

    // Multiple voters, multiple bribe assets, multiple candidates, multiple periods.
    // Interleaving of action times.
    function testClaimBribesComplex() public {
        // === Bribe token setup ===

        TestToken bribeAsset1 = new TestToken();
        bribeAsset1.mint(address(this), 1_000_000e18);
        election.enableBribeToken(address(bribeAsset1));
        bribeAsset1.approve(address(election), type(uint256).max);

        TestToken bribeAsset2 = new TestToken();
        bribeAsset2.mint(address(this), 1_000_000e18);
        election.enableBribeToken(address(bribeAsset2));
        bribeAsset2.approve(address(election), type(uint256).max);

        // === Candidate setup ===

        election.enableCandidate(CANDIDATE1);
        election.enableCandidate(CANDIDATE2);
        election.enableCandidate(CANDIDATE3);

        // === Voting position setup ===

        // USER1 creates a ve position
        cypher.transfer(USER1, 30e18);
        vm.startPrank(USER1);
        cypher.approve(address(ve), 30e18);
        uint256 user1TokenId = ve.createLock(30e18, MAX_LOCK_DURATION);
        ve.lockIndefinite(user1TokenId);
        vm.stopPrank();

        // USER2 creates a ve position
        cypher.transfer(USER2, 20e18);
        vm.startPrank(USER2);
        cypher.approve(address(ve), 20e18);
        uint256 user2TokenId = ve.createLock(20e18, MAX_LOCK_DURATION);
        ve.lockIndefinite(user2TokenId);
        vm.stopPrank();

        // The test contract also creates a ve position
        cypher.approve(address(ve), 50e18);
        uint256 testContractTokenId = ve.createLock(50e18, MAX_LOCK_DURATION);
        ve.lockIndefinite(testContractTokenId);

        // === First vote period ===

        // Working with a cached timestamp to avoid spurious errors due to the optimizer.
        uint256 firstPeriodStart = _warpToNextVotePeriodStart();

        bytes32[] memory twoCandidates = new bytes32[](2);
        uint256[] memory twoWeights = new uint256[](2);

        vm.startPrank(USER1);
        twoCandidates[0] = CANDIDATE1;
        twoCandidates[1] = CANDIDATE2;
        twoWeights[0] = 2;
        twoWeights[1] = 1;
        election.vote(user1TokenId, twoCandidates, twoWeights);
        vm.stopPrank();

        vm.warp(firstPeriodStart + 1 hours);

        // First bribe dropped for CANDIDATE1 in bribeAsset1
        election.addBribe(address(bribeAsset1), 3_000e18, CANDIDATE1);

        vm.warp(firstPeriodStart + 2 hours);

        vm.startPrank(USER2);
        twoCandidates[0] = CANDIDATE1;
        twoCandidates[1] = CANDIDATE3;
        twoWeights[0] = 1;
        twoWeights[1] = 1;
        election.vote(user2TokenId, twoCandidates, twoWeights);
        vm.stopPrank();

        vm.warp(firstPeriodStart + 3 hours);

        // Second bribe dropped for CANDIDATE3 in bribeAsset2
        election.addBribe(address(bribeAsset2), 1_000e18, CANDIDATE3);

        vm.warp(firstPeriodStart + 4 hours);

        bytes32[] memory oneCandidate = new bytes32[](1);
        uint256[] memory oneWeight = new uint256[](1);

        // The test contract votes for CANDIDATE2
        oneCandidate[0] = CANDIDATE2;
        oneWeight[0] = 100;
        election.vote(testContractTokenId, oneCandidate, oneWeight);

        // Expected bribe allotments from this period:
        // USER1: 2_000e18 of bribeToken1
        // USER2: 1_000e18 of bribeToken1 and 1_000e18 of bribeToken2
        // testContract: no bribe earnings

        // === Second vote period ===

        uint256 secondPeriodStart = firstPeriodStart + VOTE_PERIOD;
        vm.warp(secondPeriodStart);

        // First bribe is dropped for CANDIDATE1 in bribeToken1
        election.addBribe(address(bribeAsset1), 5_000e18, CANDIDATE1);

        vm.warp(secondPeriodStart + 1 hours);

        vm.startPrank(USER1);
        oneCandidate[0] = CANDIDATE1;
        oneWeight[0] = 333;
        election.vote(user1TokenId, oneCandidate, oneWeight);
        vm.stopPrank();

        vm.warp(secondPeriodStart + 2 hours);

        // Second bribe is dropped for CANDIDATE1 in bribeToken2
        election.addBribe(address(bribeAsset2), 10_000e18, CANDIDATE1);

        vm.warp(secondPeriodStart + 3 hours);

        vm.startPrank(USER2);
        twoCandidates[0] = CANDIDATE1;
        twoCandidates[1] = CANDIDATE2;
        twoWeights[0] = 1;
        twoWeights[1] = 1;
        election.vote(user2TokenId, twoCandidates, twoWeights);
        vm.stopPrank();

        vm.warp(secondPeriodStart + 4 hours);

        // Third bribe is dropped for CANDIDATE3 in bribeToken1
        election.addBribe(address(bribeAsset1), 7_000e18, CANDIDATE3);

        vm.warp(block.timestamp + 5 hours);

        // The test contract votes 80% for CANDIDATE3 and 20% for CANDIDATE1
        twoCandidates[0] = CANDIDATE3;
        twoCandidates[1] = CANDIDATE1;
        twoWeights[0] = 80;
        twoWeights[1] = 20;
        election.vote(testContractTokenId, twoCandidates, twoWeights);

        // Expected bribe allotments from this period:
        // USER1: 3_000e18 of bribeToken1 and 6_000e18 of bribeToken2
        // USER2: 1_000e18 of bribeToken1 and 2_000e18 of bribeToken2
        // testContract: 8_000e18 of bribeToken1 and 2_000e18 of bribeToken2

        // === Third vote period ===

        uint256 thirdPeriodStart = secondPeriodStart + VOTE_PERIOD;
        vm.warp(thirdPeriodStart);

        // USER2 claims their bribes from the second period
        uint256 bal1Before = bribeAsset1.balanceOf(USER2);
        uint256 bal2Before = bribeAsset2.balanceOf(USER2);
        address[] memory twoTokens = new address[](2);
        twoTokens[0] = address(bribeAsset1);
        twoTokens[1] = address(bribeAsset2);
        twoCandidates[0] = CANDIDATE1;
        twoCandidates[1] = CANDIDATE2;
        vm.startPrank(USER2);
        election.claimBribes(user2TokenId, twoTokens, twoCandidates, secondPeriodStart, secondPeriodStart);
        vm.stopPrank();
        assertEq(bribeAsset1.balanceOf(USER2) - bal1Before, 1_000e18);
        assertEq(bribeAsset2.balanceOf(USER2) - bal2Before, 2_000e18);

        vm.warp(thirdPeriodStart + 1 hours);

        // First bribe is dropped for CANDIDATE1 in bribeToken1
        election.addBribe(address(bribeAsset1), 10_000e18, CANDIDATE1);

        // Second bribe is dropped for CANDIDATE2 in bribeToken2
        election.addBribe(address(bribeAsset2), 30_000e18, CANDIDATE2);

        // Surprise! Add the Cypher token itself as a bribe asset.
        election.enableBribeToken(address(cypher));
        cypher.approve(address(election), type(uint256).max);

        // Third bribe is dropped for CANDIDATE3 in Cypher tokens.
        election.addBribe(address(cypher), 60_000e18, CANDIDATE3);

        vm.warp(thirdPeriodStart + 2 hours);

        vm.startPrank(USER1);
        bytes32[] memory threeCandidates = new bytes32[](3);
        threeCandidates[0] = CANDIDATE1;
        threeCandidates[1] = CANDIDATE2;
        threeCandidates[2] = CANDIDATE3;
        uint256[] memory threeWeights = new uint256[](3);
        threeWeights[0] = 1;
        threeWeights[1] = 1;
        threeWeights[2] = 1;
        election.vote(user1TokenId, threeCandidates, threeWeights);
        vm.stopPrank();

        vm.startPrank(USER2);
        twoCandidates[0] = CANDIDATE2;
        twoCandidates[1] = CANDIDATE3;
        twoWeights[0] = 50;
        twoWeights[1] = 50;
        election.vote(user2TokenId, twoCandidates, twoWeights);
        vm.stopPrank();

        twoCandidates[0] = CANDIDATE2;
        twoCandidates[1] = CANDIDATE3;
        twoWeights[0] = 10;
        twoWeights[1] = 40;
        election.vote(testContractTokenId, twoCandidates, twoWeights);

        // Expected bribe allotments from this period:
        // USER1: 10_000e18 of bribeToken1, 10_000e18 of bribeToken2, 10_000e18 CYPR
        // USER2: 10_000e18 of bribeToken2 and 10_000e18 CYPR
        // testContract: 10_000e18 of bribeToken2 and 40_000e18 of CYPR

        // === Fourth vote period ===
        // Just test claims here.

        vm.warp(thirdPeriodStart + VOTE_PERIOD);

        // First up: USER1 claims everything in one go.
        bal1Before = bribeAsset1.balanceOf(USER1);
        bal2Before = bribeAsset2.balanceOf(USER1);
        uint256 balCypherBefore = cypher.balanceOf(USER1);
        address[] memory threeTokens = new address[](3);
        threeTokens[0] = address(bribeAsset1);
        threeTokens[1] = address(bribeAsset2);
        threeTokens[2] = address(cypher);
        vm.startPrank(USER1);
        election.claimBribes(user1TokenId, threeTokens, threeCandidates, firstPeriodStart, thirdPeriodStart);
        vm.stopPrank();
        assertEq(bribeAsset1.balanceOf(USER1) - bal1Before, 15_000e18);
        assertEq(bribeAsset2.balanceOf(USER1) - bal2Before, 16_000e18);
        assertEq(cypher.balanceOf(USER1) - balCypherBefore, 10_000e18);

        // Check that USER1 attempting to claim again is a no-op
        bal1Before = bribeAsset1.balanceOf(USER1);
        bal2Before = bribeAsset2.balanceOf(USER1);
        balCypherBefore = cypher.balanceOf(USER1);
        vm.startPrank(USER1);
        election.claimBribes(user1TokenId, threeTokens, threeCandidates, firstPeriodStart, thirdPeriodStart);
        vm.stopPrank();
        assertEq(bribeAsset1.balanceOf(USER1), bal1Before);
        assertEq(bribeAsset2.balanceOf(USER1), bal2Before);
        assertEq(cypher.balanceOf(USER1), balCypherBefore);

        // Next up: USER2 claims everything, including their balances for the fist round they forgot about.
        // Note that their second round was already claimed!
        bal1Before = bribeAsset1.balanceOf(USER2);
        bal2Before = bribeAsset2.balanceOf(USER2);
        balCypherBefore = cypher.balanceOf(USER2);
        vm.startPrank(USER2);
        election.claimBribes(user2TokenId, threeTokens, threeCandidates, firstPeriodStart, thirdPeriodStart);
        vm.stopPrank();
        assertEq(bribeAsset1.balanceOf(USER2) - bal1Before, 1_000e18);
        assertEq(bribeAsset2.balanceOf(USER2) - bal2Before, 11_000e18);
        assertEq(cypher.balanceOf(USER2) - balCypherBefore, 10_000e18);

        // The test contract claims for all three periods despite only earning in the 2nd and 3rd.
        bal1Before = bribeAsset1.balanceOf(address(this));
        bal2Before = bribeAsset2.balanceOf(address(this));
        balCypherBefore = cypher.balanceOf(address(this));
        election.claimBribes(testContractTokenId, threeTokens, threeCandidates, firstPeriodStart, thirdPeriodStart);
        assertEq(bribeAsset1.balanceOf(address(this)) - bal1Before, 8_000e18);
        assertEq(bribeAsset2.balanceOf(address(this)) - bal2Before, 12_000e18);
        assertEq(cypher.balanceOf(address(this)) - balCypherBefore, 40_000e18);
    }

    function testLongTermBribeFunctionality() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 1_000_000e18);
        election.enableBribeToken(address(bribeAsset));
        bribeAsset.approve(address(election), type(uint256).max);

        election.enableCandidate(CANDIDATE1);

        cypher.approve(address(ve), 100e18);
        uint256 id = ve.createLock(100e18, MAX_LOCK_DURATION);
        ve.lockIndefinite(id);

        bytes32[] memory oneCandidate = new bytes32[](1);
        oneCandidate[0] = CANDIDATE1;

        uint256[] memory oneWeight = new uint256[](1);
        oneWeight[0] = 1;

        // Working with a cached timestamp to avoid spurious errors due to the optimizer.
        uint256 firstPeriod = _warpToNextVotePeriodStart();

        election.addBribe(address(bribeAsset), 1_000e18, CANDIDATE1);
        election.vote(id, oneCandidate, oneWeight);

        uint256 secondPeriod = firstPeriod + 256 * VOTE_PERIOD;
        vm.warp(secondPeriod);

        election.addBribe(address(bribeAsset), 333e18, CANDIDATE1);
        election.vote(id, oneCandidate, oneWeight);

        uint256 thirdPeriod = secondPeriod + 100 * VOTE_PERIOD;
        vm.warp(thirdPeriod);

        election.addBribe(address(bribeAsset), 777e18, CANDIDATE1);
        election.vote(id, oneCandidate, oneWeight);

        uint256 fourthPeriod = thirdPeriod + 400 * VOTE_PERIOD;
        vm.warp(fourthPeriod);

        election.addBribe(address(bribeAsset), 1, CANDIDATE1);
        election.vote(id, oneCandidate, oneWeight);

        // Warp ahead one more period so that all bribes are claimable.
        vm.warp(fourthPeriod + VOTE_PERIOD);

        // Claim from first period.
        address[] memory oneToken = new address[](1);
        oneToken[0] = address(bribeAsset);
        uint256 balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, oneToken, oneCandidate, firstPeriod, firstPeriod);
        assertEq(bribeAsset.balanceOf(address(this)) - balBefore, 1_000e18);

        // Claim from first and second period (first claim will not be paid a second time).
        balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, oneToken, oneCandidate, firstPeriod, secondPeriod);
        assertEq(bribeAsset.balanceOf(address(this)) - balBefore, 333e18);

        // Claim from fourth.
        balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, oneToken, oneCandidate, fourthPeriod, fourthPeriod);
        assertEq(bribeAsset.balanceOf(address(this)) - balBefore, 1);

        // Claim first through fourth (only third has tokens left to claim).
        balBefore = bribeAsset.balanceOf(address(this));
        election.claimBribes(id, oneToken, oneCandidate, firstPeriod, fourthPeriod);
        assertEq(bribeAsset.balanceOf(address(this)) - balBefore, 777e18);
    }

    function testClaimBribesAuthorized() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 1e18);

        cypher.approve(address(ve), 1e18);
        uint256 id = ve.createLock(1e18, MAX_LOCK_DURATION);

        uint256 period = _warpToNextVotePeriodStart();

        election.enableCandidate(CANDIDATE1);

        election.enableBribeToken(address(bribeAsset));
        bribeAsset.approve(address(election), 1e18);
        election.addBribe(address(bribeAsset), 1e18, CANDIDATE1);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();
        address[] memory bribeTokens = new address[](1);
        bribeTokens[0] = address(bribeAsset);

        uint256 balThisBefore = bribeAsset.balanceOf(address(this));
        uint256 balUser1Before = bribeAsset.balanceOf(USER1);

        ve.approve(USER1, id);

        vm.startPrank(address(USER1));
        election.claimBribes(id, bribeTokens, candidates, period, period);
        vm.stopPrank();

        assertEq(bribeAsset.balanceOf(address(this)) - balThisBefore, 0); // Bribes do not go to token owner.
        assertEq(bribeAsset.balanceOf(USER1) - balUser1Before, 1e18); // Bribes go to claimant.
        assertTrue(election.hasClaimedBribe(id, address(bribeAsset), CANDIDATE1, period));
    }

    function testClaimBribesUnauthorized() public {
        TestToken bribeAsset = new TestToken();
        bribeAsset.mint(address(this), 1e18);

        cypher.approve(address(ve), 1e18);
        uint256 id = ve.createLock(1e18, MAX_LOCK_DURATION);

        uint256 period = _warpToNextVotePeriodStart();

        election.enableCandidate(CANDIDATE1);

        election.enableBribeToken(address(bribeAsset));
        bribeAsset.approve(address(election), 1e18);
        election.addBribe(address(bribeAsset), 1e18, CANDIDATE1);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();
        address[] memory bribeTokens = new address[](1);
        bribeTokens[0] = address(bribeAsset);

        vm.startPrank(address(USER1));
        vm.expectRevert(abi.encodeWithSelector(IElection.NotAuthorizedToClaimBribesFor.selector, id));
        election.claimBribes(id, bribeTokens, candidates, period, period);
        vm.stopPrank();
    }

    function testClaimBribesNonreentrant() public {
        ReenteringToken bribeAsset = new ReenteringToken();
        bribeAsset.mint(address(this), 1e18);

        cypher.approve(address(ve), 1e18);
        uint256 id = ve.createLock(1e18, MAX_LOCK_DURATION);

        uint256 period = _warpToNextVotePeriodStart();

        election.enableCandidate(CANDIDATE1);

        election.enableBribeToken(address(bribeAsset));
        bribeAsset.approve(address(election), 1e18);
        election.addBribe(address(bribeAsset), 1e18, CANDIDATE1);

        bytes32[] memory candidates = new bytes32[](1);
        candidates[0] = CANDIDATE1;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1e18;
        election.vote(id, candidates, weights);

        _warpToNextVotePeriodStart();
        address[] memory bribeTokens = new address[](1);
        bribeTokens[0] = address(bribeAsset);

        ve.approve(address(bribeAsset), id);

        bytes memory data =
            abi.encodeWithSelector(IElection.claimBribes.selector, id, bribeTokens, candidates, period, period);
        bribeAsset.setCall(address(election), data);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        election.claimBribes(id, bribeTokens, candidates, period, period);

        data = abi.encodeWithSelector(IElection.vote.selector, id, candidates, weights);
        bribeAsset.setCall(address(election), data);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        election.claimBribes(id, bribeTokens, candidates, period, period);
    }

    function testClaimBribesCurrentPeriod() public {}

    function testClaimBribesFuturePeriod() public {}

    function _warpToNextVotePeriodStart() internal returns (uint256 firstPeriodStart) {
        firstPeriodStart = block.timestamp + VOTE_PERIOD - block.timestamp % VOTE_PERIOD;
        vm.warp(firstPeriodStart);
    }

    function _periodStart(uint256 t) internal pure returns (uint256) {
        return t / VOTE_PERIOD * VOTE_PERIOD;
    }
}
