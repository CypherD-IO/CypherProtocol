// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICypherToken} from "src/interfaces/ICypherToken.sol";
import {IRewardDistributor} from "src/interfaces/IRewardDistributor.sol";

contract RewardDistributor is IRewardDistributor, Ownable {
    ICypherToken public immutable cypher;

    uint256 private nextRootId;
    mapping(uint256 id => bytes32 root) public override idToRoot;
    mapping(uint256 rootId => mapping(address claimant => bool hasClaimed)) public override claimed;

    constructor(address initialOwner, address _cypher) Ownable(initialOwner) {
        cypher = ICypherToken(_cypher);
    }

    // --- Mutations ---

    /// @inheritdoc IRewardDistributor
    /// @dev Note that this allows roots to be added multiple times. This is to allow for the exact same set
    ///      of claimants and claim amounts to recur.
    function addRoot(bytes32 root) external onlyOwner returns (uint256 id) {
        if (root == bytes32(0)) revert InvalidRoot();
        id = nextRootId++;
        idToRoot[id] = root;
        emit RootAdded(id, root);
    }

    /// @inheritdoc IRewardDistributor
    function claim(bytes32[] calldata proof, uint256 rootId, uint256 value) external {
        _claim(proof, rootId, value);
    }

    /// @inheritdoc IRewardDistributor
    function claimMultiple(bytes32[][] calldata proofs, uint256[] calldata rootIds, uint256[] calldata values)
        external
    {
        uint256 len = proofs.length;
        if (rootIds.length != len) revert LengthMismatch();
        if (values.length != len) revert LengthMismatch();
        for (uint256 i = 0; i < len; i++) {
            _claim(proofs[i], rootIds[i], values[i]);
        }
    }

    // --- Internals ---
    function _claim(bytes32[] calldata proof, uint256 rootId, uint256 value) internal {
        bytes32 root = idToRoot[rootId];

        if (root == bytes32(0)) revert InvalidRootId(rootId);
        if (claimed[rootId][msg.sender]) revert AlreadyClaimed(rootId);
        if (!MerkleProof.verifyCalldata(proof, root, _hashLeaf(msg.sender, value))) revert InvalidProof(rootId);

        claimed[rootId][msg.sender] = true;

        cypher.transfer(msg.sender, value);
        emit Claimed(msg.sender, value, rootId, root);
    }

    function _hashLeaf(address claimant, uint256 value) internal pure returns (bytes32) {
        // Matches the default behavior of OZ's Merkle tree library:
        // https://github.com/OpenZeppelin/merkle-tree/tree/master)
        // The double hashing mitigates any possibility of a second preimage attack.
        return keccak256(bytes.concat(keccak256(abi.encode(claimant, value))));
    }
}
