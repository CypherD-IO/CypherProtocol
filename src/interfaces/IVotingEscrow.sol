// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVotingEscrow is IERC721 {
    // --- Data Types ---

    /// @dev Locked position info.
    struct LockedBalance {
        /// @dev Quantity of tokens locked.
        int128 amount;
        /// @dev Time at which the lock expires and tokens can be withdrawn.
        /// @dev Zero is `isIndefinite` is `true`.
        uint256 end;
        /// @dev Whether the lock is indefinite.
        bool isIndefinite;
    }

    /// @dev Used to record both token and aggregate checkpoints.
    struct Point {
        /// @dev Effective weight at time of checkpoint.
        int128 bias;
        /// @dev Quantity by which voting weight decreases per-second.
        int128 slope; // # -dweight / dt
        /// @dev Timestamp of this checkpoint.
        uint256 ts;
        /// @dev Amount of indefinitely locked tokens.
        uint256 indefinite;
    }

    // --- Events ---

    event CreateLock(
        address indexed from, address indexed to, uint256 indexed tokenId, uint256 value, uint256 unlockTime
    );

    event DepositFor(address indexed from, address indexed tokenOwner, uint256 indexed tokenId, uint256 valueAdded);

    event IncreaseUnlockTime(address indexed tokenOwner, uint256 indexed tokenId, uint256 newUnlockTime);

    event Withdraw(address indexed tokenOwner, uint256 indexed tokenId, uint256 value);

    event LockIndefinite(address indexed tokenOwner, uint256 indexed tokenId, uint256 value);

    event UnlockIndefinite(address indexed tokenOwner, uint256 indexed tokenId, uint256 value, uint256 unlockTime);

    event Merge(
        address indexed sender,
        uint256 indexed from,
        uint256 indexed to,
        uint256 amountFrom,
        uint256 amountTo,
        uint256 unlockTime
    );

    // --- Errors ---

    error ZeroValue();
    error UnlockTimeNotInFuture();
    error LockDurationExceedsMaximum();
    error LockExpired();
    error LockedIndefinitely();
    error LockNotExpired();
    error NotLockedIndefinitely();
    error NewUnlockTimeNotAfterOld();
    error IdenticalTokenIds();

    // --- Mutations ---

    /// @notice Lock tokens to create a veNFT with a given lock duration.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    function createLock(uint256 value, uint256 duration) external returns (uint256);

    /// @notice Lock tokens to create a veNFT with a given lock duration and assign it to a specific address.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    /// @param to Address that will receive the minted NFT
    function createLockFor(uint256 value, uint256 duration, address to) external returns (uint256);

    /// @notice Add tokens to an existing veNFT. Any address may add tokens to any veNFT.
    /// @param tokenId Id of the veNFT to add tokens to
    /// @param value Amount of additional tokens to lock
    function depositFor(uint256 tokenId, uint256 value) external;

    /// @notice Increase the lock duration of an existing veNFT.
    /// @param tokenId Id of the veNFT to extend the lock duration of
    /// @param unlockTime Timestamp of new unlock; must exceed prior unlock time
    function increaseUnlockTime(uint256 tokenId, uint256 unlockTime) external;

    /// @notice Withdraw underlying tokens. Position must not be indefinitely locked and
    ///         must be fully decayed.
    /// @param tokenId Id of the veNFT to burn and return the deposit of
    function withdraw(uint256 tokenId) external;

    /// @notice Locked position with no decay.
    /// @param tokenId Id of the veNFT to lock indefinitely
    function lockIndefinite(uint256 tokenId) external;

    /// @notice Convert an indefinitely locked position into a decaying one with the maximum duration.
    /// @param tokenId Id of the veNFT to covert to a time decaying position
    function unlockIndefinite(uint256 tokenId) external;

    /// @notice Merge two veNFTs into one.
    function merge(uint256 from, uint256 to) external;

    // --- Views ---

    /// @notice Determine whether an address has authority over a token's voting power.
    /// @param actor The entity attempting to vote using the token's voting power.
    /// @param tokenId The id of the vote escrowed position the actor wishes to use the voting power of.
    function isAuthorizedToVoteFor(address actor, uint256 tokenId) external view returns (bool);

    /// @notice Calculate total voting power
    /// @param timestamp Time at which to caluclate voting power
    function totalSupplyAt(uint256 timestamp) external view returns (uint256);

    /// @notice Calculate a position's total voting power.
    /// @param tokenId Id of the token to calculate the voting power for
    /// @param timestamp Time at which to caluclate voting power
    function balanceOfAt(uint256 tokenId, uint256 timestamp) external view returns (uint256);
}
