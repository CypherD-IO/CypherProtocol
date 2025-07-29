// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ICypherToken} from "src/interfaces/ICypherToken.sol";
import {IVeNftUsageOracle} from "./IVeNftUsageOracle.sol";

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

    event VeNftUsageOracleUpdated(address newOracle);

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
    error TokenInUse(uint256 tokenId);
    error InvalidStartIndex();

    // --- Admin ---

    /// @notice Sets the veNFT usage oracle.
    /// @param newOracle The address of the new oracle
    function setVeNftUsageOracle(address newOracle) external;

    // --- Mutations ---

    /// @notice Lock tokens to create a veNFT with a given lock duration.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    /// @return The id of the created veNFT
    function createLock(uint256 value, uint256 duration) external returns (uint256);

    /// @notice Lock tokens to create a veNFT with a given lock duration and assign it to a specific address.
    /// @param value Amount of tokens to lock
    /// @param duration Seconds to lock for (will be rounded down to nearest voting period)
    /// @param to Address that will receive the minted NFT
    /// @return The id of the created veNFT
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
    /// @param toTokenOwner If true, send funds to the owner of the token; if false, send them to the caller
    function withdraw(uint256 tokenId, bool toTokenOwner) external;

    /// @notice Locked position with no decay.
    /// @param tokenId Id of the veNFT to lock indefinitely
    function lockIndefinite(uint256 tokenId) external;

    /// @notice Convert an indefinitely locked position into a decaying one with the maximum duration.
    /// @param tokenId Id of the veNFT to covert to a time decaying position
    function unlockIndefinite(uint256 tokenId) external;

    /// @notice Merge two veNFTs into one.
    function merge(uint256 from, uint256 to) external;

    // --- Views ---

    /// @notice The Cypher token.
    /// @return The Cypher token interface.
    function cypher() external view returns (ICypherToken);

    // @notice The oracle used to determine whether a veNFT is in use.
    // @return The veNFT usage oracle (as an interface).
    function veNftUsageOracle() external view returns (IVeNftUsageOracle);

    /// @notice The id that will be assigned to the next created veNFT.
    /// @return The id of the next veNFT (returned by either `createLock` or `createLockFor`)
    function nextId() external view returns (uint256);

    /// @notice Vote period index.
    /// @return The latest vote period index.
    function epoch() external view returns (uint256);

    /// @notice The quantity of Cypher tokens that are locked indefinitely.
    /// @return The total amount of indefinitely locked tokens.
    function indefiniteLockBalance() external view returns (uint256);

    /// @notice Fetch the defining data of veNFT.
    /// @param tokenId The id of the veNFT to query data for.
    /// @return amount The quantity of Cypher locked.
    /// @return end The timestamp at which the veNFT will be expired
    /// @return isIndefinite A flag indicating whether or not the position is locked indefinitely
    function locked(uint256 tokenId) external view returns (int128 amount, uint256 end, bool isIndefinite);

    /// @notice Fetch the slope change that must be applied at a given timestamp.
    /// @dev Will return zero except possibly at timestamps that are a multiple of the interval between vote periods.
    /// @param timestamp The timestamp to query for
    /// @return slopeChange The change in the rate of overall vote weight decay at the given timestamp
    function slopeChanges(uint256 timestamp) external view returns (int128 slopeChange);

    /// @notice Fetch the global checkpoint data for a given vote period index
    /// @param epoch The vote period index to query for
    /// @return bias Total effective voting weight at the given epoch
    /// @return slope Quantity by which voting weight decreases per-second until the next non-zero slope change
    /// @return ts Timestamp of the epoch (multiple of the vote period interval)
    /// @return indefinite Total amount of indefinitely locked tokens at the given epoch
    function pointHistory(uint256 epoch)
        external
        view
        returns (int128 bias, int128 slope, uint256 ts, uint256 indefinite);

    /// @notice Fetch index of the last checkpoint recorded for a given veNFT
    /// @param tokenId Id of the veNFT to query the token epoch of
    /// @return tokenEpoch Index of the last checkpoint for the given veNFT
    function tokenPointEpoch(uint256 tokenId) external view returns (uint256 tokenEpoch);

    /// @notice Fetch token checkpoint data at a given token checkpoint index
    /// @param tokenId Id of the veNFT to query checkpoint data of
    /// @param tokenEpoch The index of the checkpoint to fetch
    /// @return bias Effective voting weight at the token checkpoint (if not locked indefinitely)
    /// @return slope Quantity by which the voting weight of the position is decreasing per-second until the next token checkpoint
    /// @return ts The timestamp of the token checkpoint (not necessarily a multiple of the voting period, unlike global checkpoints)
    /// @return indefinite The quantity of indefinitely locked tokens belonging to the veNFT
    function tokenPointHistory(uint256 tokenId, uint256 tokenEpoch)
        external
        view
        returns (int128 bias, int128 slope, uint256 ts, uint256 indefinite);

    /// @notice Determine whether an address has authority over a token's voting power.
    /// @param actor The entity attempting to vote using the token's voting power.
    /// @param tokenId The id of the vote escrowed position the actor wishes to use the voting power of.
    /// @return isAuthorized Whether the actor can vote on behalf of the tokenId
    function isAuthorizedToVoteFor(address actor, uint256 tokenId) external view returns (bool isAuthorized);

    /// @notice Get the tokens owned by a given address as an array.
    /// @param owner The address to fetch the owned tokens of.
    /// @return tokenIds The array of owned tokens (empty if none are owned by the provided address).
    function tokensOwnedBy(address owner) external view returns (uint256[] memory tokenIds);

    /// @notice Get a consecutive subset of the tokens owned by a given address as an array.
    /// @param owner The address to fetch the owned tokens of.
    /// @param startIndex Index of the first token id owned by the user to fetch.
    /// @param maxTokens The maximum number of tokens to fetch (may be larger than the fetchable tokens).
    /// @return tokenIds An array of up to maxTokens owned tokens from the given start index.
    function tokensOwnedByFromIndexWithMax(address owner, uint256 startIndex, uint256 maxTokens)
        external
        view
        returns (uint256[] memory tokenIds);

    /// @notice Calculate total voting power (including indefinitely locked positions).
    /// @param timestamp Time at which to caluclate voting power
    /// @return totalSupply The total decaying vote weight at the given timestamp
    function totalSupplyAt(uint256 timestamp) external view returns (uint256 totalSupply);

    /// @notice Calculate a position's total voting power.
    /// @param tokenId Id of the token to calculate the voting power for
    /// @param timestamp Time at which to caluclate voting power
    /// @return balanceOf Effective voting weight of the veNFT at the given timestamp (does account for indefinite versus decaying locks)
    function balanceOfAt(uint256 tokenId, uint256 timestamp) external view returns (uint256);
}
