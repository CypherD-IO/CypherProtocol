pragma solidity 0.8.28;

interface IRewardDistributor {
    // --- Events ---

    event RootAdded(uint256 indexed id, bytes32 indexed root);
    event Claimed(address indexed claimant, uint256 value, uint256 indexed rootId, bytes32 indexed root);

    // --- Errors ---

    error InvalidRootId(uint256);
    error AlreadyClaimed(uint256);
    error InvalidProof(uint256);
    error LengthMismatch();

    // --- Mutations ---

    /// @notice Add a new valid root. Note that the same root may be added multiple times.
    /// @param root The Merkle tree root to add.
    /// @return rootId The id assigned to the added root.
    function addRoot(bytes32 root) external returns (uint256 rootId);

    /// @notice Claim rewards for a single root id.
    /// @param proof The Merkle proof.
    /// @param rootId The root id.
    /// @param value The amount of tokens to claim (must claim full amount).
    function claim(bytes32[] calldata proof, uint256 rootId, uint256 value) external;

    /// @notice Claim rewards for multiple root ids simultaneously
    /// @param proofs The Merkle proofs.
    /// @param rootIds The root ids.
    /// @param values The amounts of tokens to claim (must claim full amount for each rootId).
    function claimMultiple(bytes32[][] calldata proofs, uint256[] calldata rootIds, uint256[] calldata values)
        external;

    // --- Views ---

    /// @notice Gets the root corresponding to the given id.
    /// @param id The id of the root to fetch.
    /// @return root The root corresponding to the id, or bytes32(0) if no such root exists.
    function idToRoot(uint256 id) external view returns (bytes32 root);

    /// @notice Determine whether `claimant` has already claimed rewards from root identified by `rootId`.
    /// @param claimant The address to checked the claiming status for.
    /// @param rootId The id of the root to check claiming status for.
    /// @return hasClaimed Whether or not the claimant claimed rewards from the given rootId.
    function claimed(address claimant, uint256 rootId) external view returns (bool hasClaimed);
}
