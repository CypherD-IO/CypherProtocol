// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICypherToken} from "src/interfaces/ICypherToken.sol";
import {IAirdropDistributor} from "src/interfaces/IAirdropDistributor.sol";
import {IVotingEscrow} from "src/interfaces/IVotingEscrow.sol";
import {IElection} from "src/interfaces/IElection.sol";

contract AirdropDistributor is IAirdropDistributor, Ownable, ReentrancyGuard {
    ICypherToken public immutable cypher;
    IVotingEscrow public immutable votingEscrow;
    IElection public immutable election;

    uint256 private nextRootId;
    mapping(uint256 id => bytes32 root) public override idToRoot;
    mapping(uint256 id => uint256 expiry) public override idToExpiry;
    mapping(uint256 rootId => mapping(address claimant => bool hasClaimed))
        public
        override claimed;

    // --- NEW: Root status tracking ---
    /// @notice Mapping to track if a root is active (true) or inactive (false)
    /// @dev Only active roots can be used for claiming
    mapping(uint256 id => bool isActive) public rootStatus;

    // --- NEW: Events for root management ---
    /// @notice Emitted when a root is deactivated
    /// @param rootId The ID of the deactivated root
    /// @param root The root hash that was deactivated
    event RootDeactivated(uint256 indexed rootId, bytes32 root);

    /// @notice Error thrown when trying to deactivate an already inactive root
    error RootAlreadyInactive(uint256 rootId);

    /// @notice Error thrown when trying to claim from an inactive root
    error RootInactive(uint256 rootId);

    constructor(
        address initialOwner,
        address _cypherAddress,
        address _votingEscrowAddress,
        address _electionAddress
    ) Ownable(initialOwner) {
        cypher = ICypherToken(_cypherAddress);
        votingEscrow = IVotingEscrow(_votingEscrowAddress);
        election = IElection(_electionAddress);

        cypher.approve(address(votingEscrow), 1_000_000_000e18);
    }

    // --- Mutations ---

    /// @inheritdoc IAirdropDistributor
    /// @dev Note that this allows roots to be added multiple times. This is to allow for the exact same set
    ///      of claimants and claim amounts to recur.
    function addRoot(
        bytes32 root,
        uint256 expiry
    ) external onlyOwner returns (uint256 id) {
        if (root == bytes32(0)) revert InvalidRoot();
        if (expiry < block.timestamp) revert InvalidExpiry();
        id = nextRootId++;
        idToRoot[id] = root;
        idToExpiry[id] = expiry;
        
        // --- NEW: Set new root as active by default ---
        rootStatus[id] = true;
        
        emit RootAdded(id, root, expiry);
    }

    /// @inheritdoc IAirdropDistributor
    /// @dev This allows the owner to withdraw the cypher tokens that are not claimed.
    function withdraw(
        address toAddress,
        uint256 amount
    ) external onlyOwner returns (bool) {
        return cypher.transfer(toAddress, amount);
    }

    /// @inheritdoc IAirdropDistributor
    /// @dev Protected with nonReentrant to prevent reentrancy attacks during token transfers and NFT creation
    function claim(
        bytes32[] calldata proof,
        uint256 rootId,
        uint256 tokenAirdropValue,
        uint256 nftTokenValue,
        bytes32[] calldata candidates,
        uint256[] calldata weights
    ) external nonReentrant {
        _claim(
            proof,
            rootId,
            tokenAirdropValue,
            nftTokenValue,
            candidates,
            weights
        );
    }

    // --- NEW: Root deactivation function ---
    /// @notice Deactivate a specific root by ID
    /// @param rootId The ID of the root to deactivate
    /// @dev Only the owner can deactivate roots
    /// @dev This prevents new claims from this root while preserving existing claim records
    /// @dev Emits RootDeactivated event when successful
    function deactivateRoot(uint256 rootId) external onlyOwner {
        // Validate that the root exists
        if (idToRoot[rootId] == bytes32(0)) {
            revert InvalidRootId(rootId);
        }
        
        // Validate that the root is currently active
        if (!rootStatus[rootId]) {
            revert RootAlreadyInactive(rootId);
        }

        // Deactivate the root
        rootStatus[rootId] = false;

        // Emit event for tracking
        emit RootDeactivated(rootId, idToRoot[rootId]);
    }

    // --- NEW: View function to check root status ---
    /// @notice Check if a root is active
    /// @param rootId The ID of the root to check
    /// @return True if the root is active, false otherwise
    function isRootActive(uint256 rootId) external view returns (bool) {
        return rootStatus[rootId];
    }

    // --- Internals ---
    function _claim(
        bytes32[] calldata proof,
        uint256 rootId,
        uint256 tokenAirdropValue,
        uint256 nftTokenValue,
        bytes32[] calldata candidates,
        uint256[] calldata weights
    ) internal {
        bytes32 root = idToRoot[rootId];
        uint256 expiry = idToExpiry[rootId];

        if (root == bytes32(0)) revert InvalidRootId(rootId);
        if (expiry < block.timestamp) revert ExpiredRoot(rootId, expiry);
        if (claimed[rootId][msg.sender]) revert AlreadyClaimed(rootId);
        
        // --- NEW: Check if root is active before allowing claims ---
        if (!rootStatus[rootId]) {
            revert RootInactive(rootId);
        }
        
        if (
            !MerkleProof.verifyCalldata(
                proof,
                root,
                _hashLeaf(msg.sender, tokenAirdropValue, nftTokenValue)
            )
        ) revert InvalidProof(rootId);

        claimed[rootId][msg.sender] = true;

        if (tokenAirdropValue > 0) {
            cypher.transfer(msg.sender, tokenAirdropValue);
            emit CypherTokenClaimed(
                msg.sender,
                tokenAirdropValue,
                rootId,
                root
            );
        }
        if (nftTokenValue > 0) {
            uint256 tokenId = votingEscrow.createLock(
                nftTokenValue,
                2 * 52 * 7 days
            );
            emit VeCypherNftClaimed(
                msg.sender,
                tokenId,
                nftTokenValue,
                rootId,
                root
            );
            if (weights.length > 0) {
                election.vote(tokenId, candidates, weights);
            }
            
            // Transfer the tokenId to msg.sender
            votingEscrow.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function _hashLeaf(
        address claimant,
        uint256 tokenAirdropValue,
        uint256 nftTokenValue
    ) internal pure returns (bytes32) {
        // Matches the default behavior of OZ's Merkle tree library:
        // https://github.com/OpenZeppelin/merkle-tree/tree/master)
        // The double hashing mitigates any possibility of a second preimage attack.
        return
            keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(claimant, tokenAirdropValue, nftTokenValue)
                    )
                )
            );
    }
}