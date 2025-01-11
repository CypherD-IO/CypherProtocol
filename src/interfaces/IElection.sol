pragma solidity 0.8.28;

interface IElection {
    // --- Events ---

    event CandidateEnabled(bytes32 indexed candidate);
    event CandidateDisabled(bytes32 indexed candidate);
    event BribeTokenEnabled(address indexed bribeToken);
    event BribeTokenDisabled(address indexed bribeToken);
    event Vote(uint256 indexed tokenId, bytes32 indexed candidate, uint256 indexed periodStart, uint256 votes);
    event BribeClaimed(uint256 indexed tokenId, address indexed bribeToken, bytes32 indexed candidate, uint256 periodStart, uint256 amount);
    event BribeAdded(address indexed bribeToken, bytes32 indexed candidate, uint256 periodStart, uint256 amount);

    // --- Errors ---

    error NotAuthorizedForVoting();
    error LengthMismatch();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidCandidate();
    error CanOnlyClaimBribesForPastPeriods();
    error InvalidBribeToken();

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

    /// @notice Clear voting record.
    /// @param tokenId The token to clear the voting record of.
    function clear(uint256 tokenId) external;

    /// @notice Claim bribes.
    /// @param tokenId Id of the token to claim bribes for.
    /// @param bribeTokens Bribe tokens to claim.
    /// @param candidates Candidates to claim for voting for.
    /// @param from Timestamp contained in the first period to claim from.
    /// @param until Timestamp contained in the last period to claim from.
    function claimBribes(uint256 tokenId, address[] calldata bribeTokens, bytes32[] calldata candidates, uint256 from, uint256 until) external;

    /// @notice Add a bribe for a given candidate in the current voting period.
    function addBribe(address bribeToken, uint256 amount, bytes32 candidate) external;

    // --- Views ---

}
