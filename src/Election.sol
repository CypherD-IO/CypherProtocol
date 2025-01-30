pragma solidity 0.8.28;

import {IElection} from "./interfaces/IElection.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Election is IElection, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- Constants ---

    uint256 private constant VOTE_PERIOD = 2 weeks;
    uint256 private constant MAX_LOCK_DURATION = 2 * 52 weeks;

    // --- Storage ---

    IVotingEscrow public ve;

    mapping(bytes32 candidate => bool isCandidate) public isCandidate;
    mapping(address bribeToken => bool isBribeToken) public isBribeToken;
    mapping(uint256 tokenId => uint256 timestamp) public lastVoteTime;
    mapping(bytes32 candidate => mapping(uint256 periodStart => uint256 votes)) public votesForCandidateInPeriod;
    mapping(uint256 tokenId => mapping(bytes32 candidate => mapping(uint256 periodStart => uint256 votesInPeriod)))
        public votesByTokenForCandidateInPeriod;
    mapping(address bribeToken => mapping(bytes32 candidate => mapping(uint256 periodStart => uint256 amount))) public
        amountOfBribeTokenForCandidateInPeriod;
    mapping(
        uint256 tokenId => mapping(address bribeToken => mapping(bytes32 candidate => uint256 lastClaimedPeriodStart))
    ) public lastClaimByTokenOfBribeTokenForCandidate;

    // --- Constructor ---

    constructor(address initialOwner, address votingEscrow) Ownable(initialOwner) {
        ve = IVotingEscrow(votingEscrow);
    }

    // --- Mutations ---

    /// @inheritdoc IElection
    function enableCandidate(bytes32 candidate) external onlyOwner {
        if (isCandidate[candidate]) revert CandidateAlreadyEnabled();
        isCandidate[candidate] = true;
        emit CandidateEnabled(candidate);
    }

    /// @inheritdoc IElection
    function disableCandidate(bytes32 candidate) external onlyOwner {
        if (!isCandidate[candidate]) revert CandidateNotEnabled();
        isCandidate[candidate] = false;
        emit CandidateDisabled(candidate);
    }

    /// @inheritdoc IElection
    function enableBribeToken(address token) external onlyOwner {
        if (isBribeToken[token]) revert BribeTokenAlreadyEnabled();
        isBribeToken[token] = true;
        emit BribeTokenEnabled(token);
    }

    /// @inheritdoc IElection
    function disableBribeToken(address token) external onlyOwner {
        if (!isBribeToken[token]) revert BribeTokenNotEnabled();
        isBribeToken[token] = false;
        emit BribeTokenDisabled(token);
    }

    /// @inheritdoc IElection
    function vote(uint256 tokenId, bytes32[] calldata candidates, uint256[] calldata weights) external nonReentrant {
        if (!ve.isAuthorizedToVoteFor(msg.sender, tokenId)) revert NotAuthorizedForVoting();
        if (candidates.length != weights.length) revert LengthMismatch();
        uint256 periodStart = _votingPeriodStart(block.timestamp);
        if (lastVoteTime[tokenId] >= periodStart) revert AlreadyVoted();

        uint256 power = ve.balanceOfAt(tokenId, periodStart);
        if (power == 0) revert NoVotingPower();

        lastVoteTime[tokenId] = block.timestamp;

        uint256 len = weights.length;

        uint256 totalWeight;
        for (uint256 i = 0; i < len; i++) {
            totalWeight += weights[i];
        }

        for (uint256 i = 0; i < len; i++) {
            bytes32 candidate = candidates[i];
            if (!isCandidate[candidate]) revert InvalidCandidate();
            uint256 votesToAdd = power * weights[i] / totalWeight;
            if (votesToAdd > 0) {
                votesForCandidateInPeriod[candidate][periodStart] += votesToAdd;
                votesByTokenForCandidateInPeriod[tokenId][candidate][periodStart] += votesToAdd;
                emit Vote(tokenId, ve.ownerOf(tokenId), candidate, periodStart, votesToAdd);
            }
        }
    }

    /// @inheritdoc IElection
    function claimBribes(
        uint256 tokenId,
        address[] calldata bribeTokens,
        bytes32[] calldata candidates,
        uint256 from,
        uint256 until
    ) external nonReentrant {
        if (!ve.isAuthorizedToVoteFor(msg.sender, tokenId)) revert NotAuthorizedForVoting();

        uint256 firstPeriod = _votingPeriodStart(from);
        uint256 lastPeriod = _votingPeriodStart(until);

        if (lastPeriod >= _votingPeriodStart(block.timestamp)) revert CanOnlyClaimBribesForPastPeriods();

        uint256 nBribeTokens = bribeTokens.length;
        uint256[] memory owed = new uint256[](nBribeTokens);
        uint256 nCandidates = candidates.length;
        for (uint256 period = firstPeriod; period <= lastPeriod; period += VOTE_PERIOD) {
            for (uint256 i = 0; i < nBribeTokens; i++) {
                address bribeToken = bribeTokens[i];
                for (uint256 j = 0; j < nCandidates; j++) {
                    bytes32 candidate = candidates[j];

                    uint256 totalBribeAmount = amountOfBribeTokenForCandidateInPeriod[bribeToken][candidate][period];
                    if (totalBribeAmount == 0) continue; // No bribes available.

                    uint256 totalVotes = votesForCandidateInPeriod[candidate][period];
                    if (totalVotes == 0) continue; // No votes for candidate (any bribe value lost!).

                    uint256 tokenVotes = votesByTokenForCandidateInPeriod[tokenId][candidate][period];
                    if (tokenVotes == 0) continue; // Didn't vote for candiate this period.

                    uint256 lastClaim = lastClaimByTokenOfBribeTokenForCandidate[tokenId][bribeToken][candidate];
                    if (lastClaim >= period) continue; // Already claimed.
                    lastClaimByTokenOfBribeTokenForCandidate[tokenId][bribeToken][candidate] = period;

                    // Note: precision loss here will make some dust amount of bribe tokens unclaimable.
                    uint256 amount = totalBribeAmount * tokenVotes / totalVotes;
                    owed[i] += amount;
                    emit BribeClaimed(tokenId, bribeToken, candidate, period, amount);
                }
            }
        }

        for (uint256 i = 0; i < nBribeTokens; i++) {
            uint256 amount = owed[i];
            if (amount > 0) {
                IERC20(bribeTokens[i]).safeTransfer(msg.sender, amount);
            }
        }
    }

    /// @inheritdoc IElection
    function addBribe(address bribeToken, uint256 amount, bytes32 candidate) external nonReentrant {
        if (!isBribeToken[bribeToken]) revert InvalidBribeToken();
        if (!isCandidate[candidate]) revert InvalidCandidate();
        if (amount > 0) {
            uint256 periodStart = _votingPeriodStart(block.timestamp);
            amountOfBribeTokenForCandidateInPeriod[bribeToken][candidate][periodStart] += amount;

            // Note: fee-on-transfer not currently supported.
            IERC20(bribeToken).safeTransferFrom(msg.sender, address(this), amount);
            emit BribeAdded(bribeToken, candidate, periodStart, amount);
        }
    }

    // --- Internals ---

    function _votingPeriodStart(uint256 timestamp) internal pure returns (uint256) {
        unchecked {
            return (timestamp / VOTE_PERIOD) * VOTE_PERIOD;
        }
    }

    function _votingPeriodEnd(uint256 timestamp) internal pure returns (uint256) {
        return _votingPeriodStart(timestamp) + VOTE_PERIOD;
    }
}
