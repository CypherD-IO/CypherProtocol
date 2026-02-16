// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRewardDistributor} from "src/interfaces/IRewardDistributor.sol";

contract TestnetRewardDistributor is IRewardDistributor, Ownable {
    IERC20 public immutable USDC;

    uint256 private nextRootId;
    mapping(uint256 id => bytes32 root) public override idToRoot;
    mapping(uint256 rootId => mapping(address claimant => bool hasClaimed)) public override claimed;

    // Root management state variables
    mapping(uint256 rootId => bool) public disabledRoots;
    bool public claimsPaused;

    // Events for root management and pausing
    event RootDisabled(uint256 indexed rootId, bytes32 indexed root);
    event RootEnabled(uint256 indexed rootId, bytes32 indexed root);
    event ClaimsPaused(address indexed pausedBy);
    event ClaimsResumed(address indexed resumedBy);

    // Custom errors for better gas efficiency and error handling
    error RootIsDisabled(uint256 rootId);
    error ClaimsArePaused();
    error RootAlreadyDisabled(uint256 rootId);
    error RootAlreadyEnabled(uint256 rootId);
    error ClaimsAlreadyPaused();
    error ClaimsAlreadyResumed();

    constructor(address initialOwner, address _usdc) Ownable(initialOwner) {
        USDC = IERC20(_usdc);
        // Initialize claims as unpaused by default
        claimsPaused = false;
    }

    // --- Mutations ---

    /// @inheritdoc IRewardDistributor
    /// @dev Note that this allows roots to be added multiple times. This is to allow for the exact same set
    ///      of claimants and claim amounts to recur.
    function addRoot(bytes32 root) external onlyOwner returns (uint256 id) {
        if (root == bytes32(0)) revert InvalidRoot();
        id = nextRootId++;
        idToRoot[id] = root;
        // Ensure newly added roots are enabled by default
        disabledRoots[id] = false;
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

    // --- Root Management Functions ---

    /// @notice Disables a specific root, preventing new claims from it
    /// @param rootId The ID of the root to disable
    /// @dev Only callable by the contract owner
    /// @dev Emits RootDisabled event when successful
    function disableRoot(uint256 rootId) external onlyOwner {
        if (idToRoot[rootId] == bytes32(0)) revert InvalidRootId(rootId);
        if (disabledRoots[rootId]) revert RootAlreadyDisabled(rootId);

        disabledRoots[rootId] = true;
        emit RootDisabled(rootId, idToRoot[rootId]);
    }

    /// @notice Re-enables a previously disabled root
    /// @param rootId The ID of the root to enable
    /// @dev Only callable by the contract owner
    /// @dev Emits RootEnabled event when successful
    function enableRoot(uint256 rootId) external onlyOwner {
        if (idToRoot[rootId] == bytes32(0)) revert InvalidRootId(rootId);
        if (!disabledRoots[rootId]) revert RootAlreadyEnabled(rootId);

        disabledRoots[rootId] = false;
        emit RootEnabled(rootId, idToRoot[rootId]);
    }

    // --- Pause Management Functions ---

    /// @notice Pauses all claims across all roots
    /// @dev Only callable by the contract owner
    /// @dev Emits ClaimsPaused event when successful
    function pauseClaims() external onlyOwner {
        if (claimsPaused) revert ClaimsAlreadyPaused();

        claimsPaused = true;
        emit ClaimsPaused(msg.sender);
    }

    /// @notice Resumes all claims across all roots
    /// @dev Only callable by the contract owner
    /// @dev Emits ClaimsResumed event when successful
    function resumeClaims() external onlyOwner {
        if (!claimsPaused) revert ClaimsAlreadyResumed();

        claimsPaused = false;
        emit ClaimsResumed(msg.sender);
    }

    // --- View Functions ---

    /// @notice Checks if a specific root is disabled
    /// @param rootId The ID of the root to check
    /// @return True if the root is disabled, false otherwise
    function isRootDisabled(uint256 rootId) external view returns (bool) {
        return disabledRoots[rootId];
    }

    // --- Internals ---

    function _claim(bytes32[] calldata proof, uint256 rootId, uint256 value) internal {
        // Check if claims are globally paused
        if (claimsPaused) revert ClaimsArePaused();

        bytes32 root = idToRoot[rootId];

        if (root == bytes32(0)) revert InvalidRootId(rootId);
        if (claimed[rootId][msg.sender]) revert AlreadyClaimed(rootId);

        // Check if the specific root is disabled
        if (disabledRoots[rootId]) revert RootIsDisabled(rootId);

        if (!MerkleProof.verifyCalldata(proof, root, _hashLeaf(msg.sender, value))) revert InvalidProof(rootId);

        claimed[rootId][msg.sender] = true;

        USDC.transfer(msg.sender, value);
        emit Claimed(msg.sender, value, rootId, root);
    }

    function _hashLeaf(address claimant, uint256 value) internal pure returns (bytes32) {
        // Matches the default behavior of OZ's Merkle tree library:
        // https://github.com/OpenZeppelin/merkle-tree/tree/master)
        // The double hashing mitigates any possibility of a second preimage attack.
        return keccak256(bytes.concat(keccak256(abi.encode(claimant, value))));
    }
}
