pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {IElection} from "../src/interfaces/IElection.sol";
import {CypherToken} from "../src/CypherToken.sol";
import {Election} from "../src/Election.sol";
import {VotingEscrow} from "../src/VotingEscrow.sol";
// import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
// import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract ElectionTest is Test {
    bytes32 constant CANDIDATE1 = keccak256(hex'f833a28e');
    bytes32 constant CANDIDATE2 = keccak256(hex'22222222');
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

        // Enabling a second time is a no-op
        election.enableCandidate(CANDIDATE1);
        assertTrue(election.isCandidate(CANDIDATE1));

        election.disableCandidate(CANDIDATE1);
        assertFalse(election.isCandidate(CANDIDATE1));

        // Disabling a second time is a no-op
        election.disableCandidate(CANDIDATE1);
        assertFalse(election.isCandidate(CANDIDATE1));
    }

    function testEnableDisableCandidateAuth() public {
        address notOwner;
        unchecked { notOwner = address(uint160(address(this)) + 1); }

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

        // Enabling a second time is a no-op
        election.enableBribeToken(bribeTokenAddr);
        assertTrue(election.isBribeToken(bribeTokenAddr));

        election.disableBribeToken(bribeTokenAddr);
        assertFalse(election.isBribeToken(bribeTokenAddr));

        // Disabling a second time is a no-op
        election.disableBribeToken(bribeTokenAddr);
        assertFalse(election.isBribeToken(bribeTokenAddr));
    }

    function testEnableDisableBribeTokenAuth() public {
        address notOwner;
        unchecked { notOwner = address(uint160(address(this)) + 1); }
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

    function _warpToNextVotePeriodStart() internal {
        vm.warp(block.timestamp + VOTE_PERIOD - block.timestamp % VOTE_PERIOD);
    }
}
