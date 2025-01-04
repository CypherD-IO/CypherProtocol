pragma solidity =0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVoteLocker is IERC721 {
    struct LockedBalance {
        int128 amount;
        uint256 end;
        bool isIndefinite;
    }    

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 indefinite;
    }

    error ZeroValue();
    error UnlockTimeNotInFuture();
    error LockDurationExceedsMaximum();

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
    /// @param duration Seconds of additional time to add (rounded down to nearest voting period)
    function increaseUnlockTime(uint256 tokenId, uint256 duration) external;

    /// @notice Withdraw underlying tokens. Position must not be indefinitely locked and
    ///         must be fully decayed.
    /// @param tokenId Id of the veNFT to burn and return the deposit of
    function withdraw(uint256 tokenId) external;

    /// @notice Locked position with no decay.
    /// @param tokenId Id of the veNFT to lock indefinitely
    function lockIndefinite(uint256 tokenId) external;

    /// @notice Convert an indefinitely locked position into a decaying one with the maximum duration.
    /// @param tokenId Id of the veNFT to covert to a time decaying position
    function unlock(uint256 tokenId) external;

    // --- Views ---

    /// @notice Calculate total voting power
    /// @param timestamp Time at which to caluclate voting power
    function totalSupplyAt(uint256 timestamp) external view returns (uint256);

    /// @notice Calculate a position's total voting power
    /// @param tokenId Id of the token to calculate the voting power for
    /// @param timestamp Time at which to caluclate voting power
    function balanceOfAt(uint256 tokenId, uint256 timestamp) external view returns (uint256);
}
