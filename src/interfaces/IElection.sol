// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVeNftUsageOracle} from "./IVeNftUsageOracle.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";

interface IElection is IVeNftUsageOracle {
    // --- Events ---

    event CandidateEnabled(bytes32 indexed candidate);
    event CandidateDisabled(bytes32 indexed candidate);
    event BribeTokenEnabled(address indexed bribeToken);
    event BribeTokenDisabled(address indexed bribeToken);
    event VoteRefresherAuthorized(address indexed keeper);
    event VoteRefresherDeauthorized(address indexed keeper);
    event MaxVotedCandidatesSet(uint256 newMaxVotedCandidates);
    event Vote(
        uint256 indexed tokenId,
        address indexed tokenOwner,
        bytes32 indexed candidate,
        uint256 periodStart,
        uint256 votes
    );
    event BribeClaimed(
        uint256 indexed tokenId,
        address indexed bribeToken,
        bytes32 indexed candidate,
        uint256 periodStart,
        uint256 amount
    );
    event BribeAdded(address indexed bribeToken, bytes32 indexed candidate, uint256 periodStart, uint256 amount);

    // --- Errors ---

    error CandidateAlreadyEnabled();
    error CandidateNotEnabled();
    error BribeTokenAlreadyEnabled();
    error BribeTokenNotEnabled();
    error NotAuthorizedForVoting();
    error ZeroMaxVotedCandidates();
    error NoCandidates();
    error TooManyCandidates();
    error LengthMismatch();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidCandidate();
    error DuplicateCandidate();
    error CanOnlyClaimBribesForPastPeriods();
    error InvalidBribeToken();
    error NotAuthorizedToClaimBribesFor(uint256 tokenId);
    error ZeroAmount();
    error TimestampPrecedesFirstPeriod();
    error AlreadyVoteRefresher();
    error NotVoteRefresher();
    error CallerNotVoteRefresher();
    error NotAuthorizedToClearVoteDataFor(uint256 tokenId);

    // --- Mutations ---

    /// @notice Enable voting for a candidate.
    /// @param candidate The candidate to enable.
    function enableCandidate(bytes32 candidate) external;

    /// @notice Enable voting for multiple candidates.
    /// @param candidates The array of candidates to enable.
    function batchEnableCandidates(bytes32[] calldata candidates) external;

    /// @notice Disable voting for a candidate.
    /// @param candidate The candidate to disable.
    function disableCandidate(bytes32 candidate) external;

    /// @notice Disable voting for multiple candidates.
    /// @param candidates The array of candidates to disable.
    function batchDisableCandidates(bytes32[] calldata candidates) external;

    /// @notice Enable making bribes with a particular token.
    /// @param bribeToken The token to enable making bribes with.
    function enableBribeToken(address bribeToken) external;

    /// @notice Disable making bribes with a particular token.
    /// @param bribeToken The token to disable making bribes with.
    function disableBribeToken(address bribeToken) external;

    /// @notice Authorize an address for refreshing user votes.
    /// @param keeper The address to authorize.
    function authorizeVoteRefresher(address keeper) external;

    /// @notice Deauthorize an address for refreshing user votes.
    /// @param keeper The address to deauthorize.
    function deauthorizeVoteRefresher(address keeper) external;

    /// @notice Set the maximum number of candidates a veNFT may vote for at once.
    /// @param newMaxVotedCandidates The new maximum number of candidates that can be voted for by a given veNFT.
    function setMaxVotedCandidates(uint256 newMaxVotedCandidates) external;

    /// @notice Vote using the weight of `tokenId` for a set of candidates, with an assigned portion of weight for each.
    /// @param tokenId The token to assign the weight of.
    /// @param candidates The candidates to vote for.
    /// @param weights Per-candidate weight fraction.
    function vote(uint256 tokenId, bytes32[] calldata candidates, uint256[] calldata weights) external;

    /// @notice Re-vote in the current period using the saved vote and weight state for the given veNFT ids.
    /// @dev Skips veNFTs (does not revert) that have already voted in the current period.
    /// @dev Skips veNFTs (does not revert) that have no stored voting data.
    /// @dev Skips veNFTs (does not revert) that have voted for more than the maximum allowed number of candidates.
    /// @dev Skips veNFTs (does not revert) that have no voting power due to expiry, merger, etc.
    /// @dev Skips veNFTs (does not revert) if none of veNFTs voted candidates are valid.
    /// @dev If some candidates are invalid, votes only for valid candidates.
    /// @param tokenIds An array of token ids for which to attempt to refresh votes for the current period.
    function refreshVotesFor(uint256[] calldata tokenIds) external;

    /// @notice Clears stored voting data--opts out of vote refreshing. Does not undo votes in current period.
    /// @param tokenId The id of the veNFT for which to clear vote data.
    function clearVoteData(uint256 tokenId) external;

    /// @notice Claim bribes.
    /// @param tokenId Id of the token to claim bribes for.
    /// @param bribeTokens Bribe tokens to claim.
    /// @param candidates Candidates to claim for voting for.
    /// @param from Timestamp contained in the first period to claim from.
    /// @param until Timestamp contained in the last period to claim from.
    function claimBribes(
        uint256 tokenId,
        address[] calldata bribeTokens,
        bytes32[] calldata candidates,
        uint256 from,
        uint256 until
    ) external;

    /// @notice Add a bribe for a given candidate in the current voting period.
    /// @param bribeToken Address of the token to add a bribe with
    /// @param amount Total amount of the bribe
    /// @param candidate Candidate that voters must vote for to receive a share of the bribe
    function addBribe(address bribeToken, uint256 amount, bytes32 candidate) external;

    // --- Views ---

    /// @notice The earliest time that voting and bribing are possible.
    /// @return Unix timestamp at which voting and bribing are enabled.
    function INITIAL_PERIOD_START() external view returns (uint256);

    /// @notice Return the address of the voting escrow contract in use.
    /// @return ve The voting escrow.
    function ve() external view returns (IVotingEscrow ve);

    /// @notice Whether or not a given bytes32 represents a valid candidate.
    /// @param candidate A candidate identifier (bytes32).
    /// @return isCandidate The status of the candidate (true if a valid candidate, otherwise false).
    function isCandidate(bytes32 candidate) external view returns (bool isCandidate);

    /// @notice Whether or not a given address represents a valid bribe asset.
    /// @param token Token address to check the status of.
    /// @return isBribeToken The status of the token (true if valid as a bribe asset).
    function isBribeToken(address token) external view returns (bool isBribeToken);

    /// @notice Return the timestamp of the last voting action by a given veNFT.
    /// @param tokenId Id of the veNFT to query for.
    /// @return timestamp Timestamp at which the veNFT last voted (zero if it never voted).
    function lastVoteTime(uint256 tokenId) external view returns (uint256 timestamp);

    /// @notice Return the total votes for a given candidate during a given voting period.
    /// @param candidate The identifier of the candidate to query for.
    /// @param periodStart The first timestamp in the relevant voting period.
    /// @return votes The total vote weight received by the candidate in the specified period (can change if the period has not yet ended).
    function votesForCandidateInPeriod(bytes32 candidate, uint256 periodStart) external view returns (uint256 votes);

    /// @notice Return the votes cast by a specific veNFT for a specific candidate during a given vote period.
    /// @param tokenId Id of the veNFT to query for.
    /// @param candidate The identifier of the candidate to query for.
    /// @param periodStart The first timestamp in the relevant voting period.
    /// @return votes The total vote weight applied by the given veNFT to the given candidate in the specified period.
    function votesByTokenForCandidateInPeriod(uint256 tokenId, bytes32 candidate, uint256 periodStart)
        external
        view
        returns (uint256 votes);

    /// @notice Provides access to the array of candidates stored based on a veNFT's previous vote.
    /// @param tokenId The id of the veNFT to query for.
    /// @param index Index in the array of voted candidates to retrieve.
    /// @return candidate The candidate stored at the given array index.
    function votedCandidates(uint256 tokenId, uint256 index) external view returns (bytes32 candidate);

    /// @notice Returns the number of candidates stored based on a veNFT's previous vote.
    /// @param tokenId The id of the veNFT to query for.
    /// @return numVotedCandidates The number of candidates voted for.
    function numVotedCandidates(uint256 tokenId) external view returns (uint256 numVotedCandidates);

    /// @notice Provides access to the array of weights stored based on a veNFT's previous vote.
    /// @param tokenId The id of the veNFT to query for.
    /// @param index Index in the array of voted weights to retrieve.
    /// @return weight The weight assigned to candidate at the same index.
    function votedWeights(uint256 tokenId, uint256 index) external view returns (uint256 weight);

    /// @notice Informs the caller whether the provided address is an authorized vote refresher.
    /// @param keeper The address to query the vote refresh authorization status of.
    /// @return isVoteRefresher Whether the address is authorized to refresh votes.
    function isVoteRefresher(address keeper) external view returns (bool isVoteRefresher);

    /// @notice Check whether a bribe has been claimed.
    /// @param tokenId Id of the veNFT to query for.
    /// @param bribeToken The bribe token to query for.
    /// @param candidate The identifier of the candidate to query for.
    /// @param timestamp Any timestamp from the voting period to query for.
    /// @return isBribeClaimed Whether or not the bribe specified by the inputs has been claimed.
    function hasClaimedBribe(uint256 tokenId, address bribeToken, bytes32 candidate, uint256 timestamp)
        external
        view
        returns (bool isBribeClaimed);

    /// @notice Determine the amount of a bribe in a particular asset that can be claimed by a veNFT for a candidate during a specific period.
    /// @param tokenId Id of the veNFT to query for.
    /// @param bribeToken The bribe token to query for.
    /// @param candidate The identifier of the candidate to query for.
    /// @param timestamp Any timestamp from the voting period to query for.
    /// @return amount The claimable bribe amount (zero if none exists, it is not yet claimable, or has already been claimed).
    function claimableAmount(uint256 tokenId, address bribeToken, bytes32 candidate, uint256 timestamp)
        external
        view
        returns (uint256 amount);
}
