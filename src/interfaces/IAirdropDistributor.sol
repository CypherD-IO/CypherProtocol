// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAirdropDistributor {
    // --- Events ---
    event RootAdded(uint256 indexed id, bytes32 indexed root, uint256 expiry);
    event CypherTokenClaimed(address indexed claimant, uint256 value, uint256 indexed rootId, bytes32 indexed root);
    event VeCypherNftClaimed(
        address indexed claimant, uint256 tokenId, uint256 value, uint256 indexed rootId, bytes32 indexed root
    );
    // --- Errors ---

    error InvalidRoot();
    error InvalidRootId(uint256);
    error AlreadyClaimed(uint256);
    error InvalidProof(uint256);
    error LengthMismatch();
    error InvalidExpiry();
    error ExpiredRoot(uint256, uint256);

    // --- Mutations ---
    /// @notice Add a new valid root. Note that the same root may be added multiple times.
    /// @param root The Merkle tree root to add.
    /// @return rootId The id assigned to the added root.
    function addRoot(bytes32 root, uint256 expiry) external returns (uint256 rootId);

    /// @notice Withdraws the cypher tokens that are not claimed.
    /// @param toAddress The address to withdraw the tokens to.
    /// @param amount The amount of tokens to withdraw.
    /// @return success Whether the withdrawal was successful.
    function withdraw(address toAddress, uint256 amount) external returns (bool);

    /// @notice Claim rewards for a single root id.
    /// @param proof The Merkle proof.
    /// @param rootId The root id.
    /// @param tokenAirdropValue The amount of tokens to claim (must claim full amount).
    /// @param nftTokenValue The amount of tokens to send as veCYPR (must claim full amount).
    function claim(
        bytes32[] calldata proof,
        uint256 rootId,
        uint256 tokenAirdropValue,
        uint256 nftTokenValue,
        bytes32[] calldata candidates,
        uint256[] calldata weights
    ) external;

    // --- Views ---
    /// @notice Gets the root corresponding to the given id.
    /// @param id The id of the root to fetch.
    /// @return root The root corresponding to the id, or bytes32(0) if no such root exists.
    function idToRoot(uint256 id) external view returns (bytes32 root);

    // --- Views ---
    /// @notice Gets the expiry corresponding to the given id.
    /// @param id The id of the root to fetch.
    /// @return expiry The expiry corresponding to the id, or 0 if no such root exists.
    function idToExpiry(uint256 id) external view returns (uint256 expiry);

    /// @notice Determine whether `claimant` has already claimed rewards from root identified by `rootId`.
    /// @param rootId The id of the root to check claiming status for.
    /// @param claimant The address to checked the claiming status for.
    /// @return hasClaimed Whether or not the claimant claimed rewards from the given rootId.
    function claimed(uint256 rootId, address claimant) external view returns (bool hasClaimed);
}
