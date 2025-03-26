// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVotingEscrow} from "./IVotingEscrow.sol";

interface IElection {
    // --- Events ---

    event CandidateEnabled(bytes32 indexed candidate);
    event CandidateDisabled(bytes32 indexed candidate);
    event BribeTokenEnabled(address indexed bribeToken);
    event BribeTokenDisabled(address indexed bribeToken);
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
    error LengthMismatch();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidCandidate();
    error CanOnlyClaimBribesForPastPeriods();
    error InvalidBribeToken();
    error NotAuthorizedToClaimBribesFor(uint256 tokenId);
    error ZeroAmount();
    error TimestampPrecedesFirstPeriod(uint256 timestamp);

    // --- Mutations ---

    /// @notice Enable voting for a candidate.
    /// @param candidate The candidate to enable.
    function enableCandidate(bytes32 candidate) external;

    /// @notice Disable voting for a candidate.
    /// @param candidate The candidate to disable.
    function disableCandidate(bytes32 candidate) external;

    /// @notice Enable making bribes with a particular token.
    /// @param bribeToken The token to enable making bribes with.
    function enableBribeToken(address bribeToken) external;

    /// @notice Disable making bribes with a particular token.
    /// @param bribeToken The token to disable making bribes with.
    function disableBribeToken(address bribeToken) external;

    /// @notice Vote using the weight of `tokenId` for a set of candidates, with an assigned portion of weight for each.
    /// @param tokenId The token to assign the weight of.
    /// @param candidates The candidates to vote for.
    /// @param weights Per-candidate weight fraction.
    function vote(uint256 tokenId, bytes32[] calldata candidates, uint256[] calldata weights) external;

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
}
