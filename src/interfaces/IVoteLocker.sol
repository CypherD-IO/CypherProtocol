pragma solidity =0.8.28;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVoteLocker is IERC721 {
    /// @notice Lock tokens to create a veNFT with a given lock duration.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    function lock(uint256 value, uint256 duration) external returns (uint256);

    /// @notice Lock tokens to create a veNFT with a given lock duration and assign it to a specific address.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    /// @param to Address that will receive the minted NFT
    function lockFor(uint256 value, uint256 duration, address to) external returns (uint256);

    /// @notice Add tokens to an existing veNFT.
    /// @param tokenId Id of the veNFT to add tokens to
    /// @param value Amount of additional tokens to lock
    function addValue(uint256 tokenId, uint256 value) external;

    /// @notice Increase the lock duration of an existing veNFT.
    /// @param tokenId Id of the veNFT to extend the lock duration of
    /// @param duration Seconds of additional time to add (rounded down to nearest voting period)
    function addDuration(uint256 tokenId, uint256 duration) external;

    /// @notice Locked position with no decay.
    /// @param tokenId Id of the veNFT to lock indefinitely
    function lockIndefinite(uint256 tokenId) external;

    /// @notice Convert an indefinitely locked position into a decaying one with the maximum duration.
    /// @param tokenId Id of the veNFT to covert to a time decaying position
    function unlock(uint256 tokenId) external;

    /// @notice Withdraw underlying tokens. Position must not be indefinitely locked and
    ///         must be fully decayed.
    /// @param tokenId Id of the veNFT to burn and return the deposit of
    function withdraw(uint256 tokenId) external;
}
