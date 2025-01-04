// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./interfaces/ICypherToken.sol";
import "./interfaces/IVoteEscrow.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Voting Escrow
/// @author Heavily inspired by Curve's VotingEscrow (https://github.com/curvefi/curve-dao-contracts/blob/567927551903f71ce5a73049e077be87111963cc/contracts/VotingEscrow.vy)
contract VoteEscrow is IVoteEscrow, ERC721, ReentrancyGuard {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for uint128;
    using SafeCast for int128;

    // --- Constants ---

    uint256 internal constant VOTE_PERIOD = 2 weeks;
    uint256 internal constant MAX_LOCK_DURATION = 2 * 52 weeks; // approx 2 years; chosen to be a multiple of  VOTE_PERIOD
    int128 internal constant iMAX_LOCK_DURATION = 2 * 52 weeks; // approx 2 years; chosen to be a multiple of  VOTE_PERIOD

    // --- Immutables ---

    ICypherToken private immutable cypher;

    // --- Storage ---

    uint256 public nextId;
    uint256 public supply;
    uint256 public epoch;
    uint256 public indefiniteLockBalance;
    mapping (uint256 tokenId => LockedBalance) internal locked;
    mapping (uint256 timestamp => int128 slopeChange) public slopeChanges;
    mapping (uint256 epoch => Point aggregatePoint) public pointHistory;
    mapping (uint256 tokenId => uint256 tokenEpoch) public tokenPointEpoch;
    mapping (uint256 tokenId => Point[1_000_000_000]) internal tokenPointHistory;

    // --- Constructor ---

    constructor(address _cypher) ERC721("Cypher veNFT", "veCYPR") {
        nextId = 1;  // 0 is not a valid id
        cypher = ICypherToken(_cypher);
    }

    // --- Mutations ---

    /// @inheritdoc IVoteEscrow
    function createLock(uint256 value, uint256 duration) external nonReentrant returns (uint256) {
        return _createLock(value, duration, msg.sender);
    }

    /// @inheritdoc IVoteEscrow
    function createLockFor(uint256 value, uint256 duration, address to) external nonReentrant returns (uint256) {
        return _createLock(value, duration, to);
    }

    /// @inheritdoc IVoteEscrow
    function depositFor(uint256 tokenId, uint256 value) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteEscrow
    function increaseUnlockTime(uint256 tokenId, uint256 duration) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteEscrow
    function withdraw(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
        _burn(tokenId);
    }

    /// @inheritdoc IVoteEscrow
    function lockIndefinite(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    /// @inheritdoc IVoteEscrow
    function unlock(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
    }

    // --- Views ---

    /// @inheritdoc IVoteEscrow
    function totalSupplyAt(uint256 timestamp) external view returns (uint256) {
        return 0;  // TODO
    }

    /// @inheritdoc IVoteEscrow
    function balanceOfAt(uint256 tokenId, uint256 timestamp) external view returns (uint256) {
        return 0;  // TODO
    }

    // --- Internal Logic ---

    function _checkExistenceAndAuthorization(address spender, uint256 tokenId) internal view {
        //  _ownerOf() requires the token to be owned, which is equivalent to existence.
        _checkAuthorized(_ownerOf(tokenId), spender, tokenId);
    }

    function _createLock(uint256 value, uint256 duration, address to) internal returns (uint256 tokenId) {
        uint256 unlockTime = block.timestamp + duration;
        unchecked {
            unlockTime = (unlockTime / VOTE_PERIOD) * VOTE_PERIOD;
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
        if (unlockTime > 0) {
            // Creating a new locked position.
            newLockedBalance.end = unlockTime;
        } else {
            newLockedBalance.end = lockedBalance.end;
        }
        newLockedBalance.isIndefinite = lockedBalance.isIndefinite;

        locked[tokenId] = newLockedBalance;
        _checkpoint(tokenId, lockedBalance, newLockedBalance);

        if (value != 0) {
            // The Cypher token is fully ERC20-compliant, so no need for safeTransferFrom().
            cypher.transferFrom(msg.sender, address(this), value);
        }
    }

    function _checkpoint(uint256 tokenId, LockedBalance memory oldLocked, LockedBalance memory newLocked) internal {
        Point memory uOld;
        Point memory uNew;
        int128 oldDSlope;
        int128 newDSlope;
        uint256 _epoch = epoch;

        if (tokenId != 0) {
            uNew.indefinite = newLocked.isIndefinite ? newLocked.amount.toInt128().toUint256() : 0;
            if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
                uOld.slope = oldLocked.amount / iMAX_LOCK_DURATION;
                uOld.bias = uOld.slope * (oldLocked.end - block.timestamp).toInt256().toInt128();
            }
            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                uNew.slope = newLocked.amount / iMAX_LOCK_DURATION;
                uNew.bias = uNew.slope * (newLocked.end - block.timestamp).toInt256().toInt128();
            }

            oldDSlope = slopeChanges[oldLocked.end];
            if (newLocked.end != 0) {
                if (newLocked.end == oldLocked.end) {
                    newDSlope = oldDSlope;
                } else {
                    newDSlope = slopeChanges[newLocked.end];
                }
            }
        }

        Point memory lastPoint = Point({bias: 0, slope: 0, ts: block.timestamp, indefinite: 0});
        if (_epoch > 0) {
            lastPoint = pointHistory[_epoch];
        }

        uint256 lastCheckpoint = lastPoint.ts;

        // Block approximation logic omitted.

        uint256 t_i;
        unchecked {
            t_i = (lastCheckpoint / VOTE_PERIOD) * VOTE_PERIOD;
        }

        // Iterate over epochs until reaching the present. Maximum lookback time is 256 * VOTE_PERIOD.
        // If more time than this passes without interaction, voting weight will be incorrect.
        // In such an event, users can still withdraw.
        for (uint256 i = 0; i < 255; i++) {
            t_i += VOTE_PERIOD;
            int128 dSlope = 0;
            if (t_i > block.timestamp) {
                t_i = block.timestamp;
            } else {
                dSlope = slopeChanges[t_i];
            }
            lastPoint.bias -= lastPoint.slope * (t_i - lastCheckpoint).toInt256().toInt128();
            lastPoint.slope += dSlope;
            if (lastPoint.bias < 0) {
                // Reachable.
                lastPoint.bias = 0;
            }
            if (lastPoint.slope < 0) {
                // Unreachable if implementation is correct.
                lastPoint.slope = 0;
            }
            lastCheckpoint = t_i;
            lastPoint.ts = t_i;
            _epoch += 1;
            if (t_i == block.timestamp) {
                break;
            } else {
                pointHistory[_epoch] = lastPoint;
            }
        }

        if (tokenId != 0) {
            lastPoint.slope += uNew.slope - uOld.slope;
            lastPoint.bias += uNew.bias - uOld.bias;
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }

            lastPoint.indefinite = indefiniteLockBalance;
        }

        // Since _epoch >= 1 always, it is unnecessary to enter this first branch
        // if _epoch == 1 (there is no prior data to overwrite).
        if (_epoch != 1 && pointHistory[_epoch - 1].ts == block.timestamp) {
            // No assignment to epoch as epochs must have unique timestamps;
            // rather, the existing one is updated.
            pointHistory[_epoch - 1] = lastPoint;
        } else {
            epoch = _epoch;
            pointHistory[_epoch] = lastPoint;
        }

        if (tokenId != 0) {
            if (oldLocked.end > block.timestamp) {
                oldDSlope += uOld.slope;
                if (newLocked.end == oldLocked.end) {
                    oldDSlope -= uNew.slope;
                }
                slopeChanges[oldLocked.end] = oldDSlope;
            }

            if (newLocked.end > block.timestamp) {
                if (newLocked.end > oldLocked.end) {
                    newDSlope -= uNew.slope;
                    slopeChanges[newLocked.end] = newDSlope;
                }
                // else: already accounted for above via inclusion in oldDSlope
            }

            uNew.ts = block.timestamp;
            uint256 tokenEpoch = tokenPointEpoch[tokenId];
            if (tokenEpoch != 0 && tokenPointHistory[tokenId][tokenEpoch].ts == block.timestamp) {
                tokenPointHistory[tokenId][tokenEpoch] = uNew;
            } else {
                tokenPointEpoch[tokenId] = tokenEpoch + 1;
                tokenPointHistory[tokenId][tokenEpoch] = uNew;
            }
        }
    }
}
