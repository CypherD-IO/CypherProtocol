// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IAirdropDistributor {
    // --- Events ---
    event RootAdded(uint256 indexed id, bytes32 indexed root);
    event CypherTokenClaimed(
        address indexed claimant,
        uint256 value,
        uint256 indexed rootId,
        bytes32 indexed root
    );
    event VeCypherNftClaimed(
        address indexed claimant,
        uint256 value,
        uint256 indexed rootId,
        bytes32 indexed root
    );
    // --- Errors ---
    error InvalidRoot();
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
    /// @param tokenAirdropValue The amount of tokens to claim (must claim full amount).
    /// @param nftTokenValue The amount of tokens to send as veCYPR (must claim full amount).
    function claim(
        bytes32[] calldata proof,
        uint256 rootId,
        uint256 tokenAirdropValue,
        uint256 nftTokenValue
    ) external;
    // --- Views ---
    /// @notice Gets the root corresponding to the given id.
    /// @param id The id of the root to fetch.
    /// @return root The root corresponding to the id, or bytes32(0) if no such root exists.
    function idToRoot(uint256 id) external view returns (bytes32 root);
    /// @notice Determine whether `claimant` has already claimed rewards from root identified by `rootId`.
    /// @param rootId The id of the root to check claiming status for.
    /// @param claimant The address to checked the claiming status for.
    /// @return hasClaimed Whether or not the claimant claimed rewards from the given rootId.
    function claimed(
        uint256 rootId,
        address claimant
    ) external view returns (bool hasClaimed);
    /// @notice Gets the address of the Cypher token.
    /// @return cypher The address of the Cypher token.
    function cypher() external view returns (address cypher);
    /// @notice Gets the address of the Voting Escrow.
    /// @return votingEscrow The address of the Voting Escrow.
    function votingEscrow() external view returns (address votingEscrow);
}