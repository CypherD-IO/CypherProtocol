// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./interfaces/ICypherToken.sol";
import "./interfaces/IVoteLocker.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract VoteLocker is IVoteLocker, ERC721, ReentrancyGuard {
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 internal constant EPOCH = 2 weeks;
    uint256 internal constant MAX_LOCK_DURATION = 2 * 52 weeks; // approx 2 years; chosen to be a multiple of  EPOCH

    ICypherToken private immutable cypher;

    uint256 public nextId;
    uint256 public supply;
    mapping(uint256 => LockedBalance) internal locked;

    constructor(address _cypher) ERC721("Cypher veNFT", "veCYPR") {
        nextId = 1;  // 0 is not a valid id
        cypher = ICypherToken(_cypher);
    }

    // --- Auth Helpers ---
    function _checkExistenceAndAuthorization(address spender, uint256 tokenId) internal view {
        //  _ownerOf() requires the token to be owned, which is equivalent to existence.
        _checkAuthorized(_ownerOf(tokenId), msg.sender, tokenId);
    }

    /// @inheritdoc IVoteLocker
    function lock(uint256 value, uint256 duration) external nonReentrant returns (uint256) {
        return _lock(value, duration, msg.sender);
    }

    /// @inheritdoc IVoteLocker
    function lockFor(uint256 value, uint256 duration, address to) external nonReentrant returns (uint256) {
        return _lock(value, duration, to);
    }

    function _lock(uint256 value, uint256 duration, address to) internal returns (uint256 tokenId) {
        uint256 unlockTime = block.timestamp + duration;
        unchecked {
            unlockTime = (unlockTime / EPOCH) * EPOCH;
        }

        if (value == 0) revert ZeroValue();
        if (unlockTime <= block.timestamp) revert UnlockTimeNotInFuture();
        unchecked {
            // safe due to previous check
            if (unlockTime - block.timestamp > MAX_LOCK_DURATION) revert LockDurationExceedsMaximum();
        }

        tokenId = nextId++;
        _mint(to, tokenId);

        _depositFor(tokenId, value, unlockTime, locked[tokenId]);
    }

    function _depositFor(uint256 tokenId, uint256 value, uint256 unlockTime, LockedBalance memory lockedBalance) internal {
        supply += value;
        LockedBalance memory newLockedBalance;
        newLockedBalance.amount = lockedBalance.amount + value.toInt256().toInt128();
        if (unlockTime > 0) {  // unlockTime == 0 implies an indefinite lock
            newLockedBalance.end = unlockTime;
        }

        locked[tokenId] = newLockedBalance;
//        _checkpoint(tokenId, lockedBalance, newLockedBalance);

        if (value != 0) {
            // The Cypher token is fully ERC20-compliant, so no need for safeTransferFrom().
            cypher.transferFrom(msg.sender, address(this), value);
        }
    }

    /// @inheritdoc IVoteLocker
    function addValue(uint256 tokenId, uint256 value) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteLocker
    function addDuration(uint256 tokenId, uint256 duration) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteLocker
    function lockIndefinite(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteLocker
    function unlock(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteLocker
    function withdraw(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
        _burn(tokenId);
    }

    /// @inheritdoc IVoteLocker
    function totalSupplyAt(uint256 timestamp) external view returns (uint256) {
        return 0;  // TODO
    }
}
