// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./interfaces/ICypherToken.sol";
import "./interfaces/IVotingEscrow.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title Voting Escrow
/// @author Heavily inspired by Curve's VotingEscrow (https://github.com/curvefi/curve-dao-contracts/blob/567927551903f71ce5a73049e077be87111963cc/contracts/VotingEscrow.vy)
contract VotingEscrow is IVotingEscrow, ERC721, ReentrancyGuard {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeCast for int128;

    // --- Constants ---

    // All unlock times are rounded down to the nearest mulitple of VOTE_PERIOD.
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
    mapping(uint256 tokenId => LockedBalance) public locked;
    mapping(uint256 timestamp => int128 slopeChange) public slopeChanges;
    mapping(uint256 epoch => Point aggregatePoint) public pointHistory;
    mapping(uint256 tokenId => uint256 tokenEpoch) public tokenPointEpoch;
    mapping(uint256 tokenId => mapping(uint256 tokenEpoch => Point tokenPoint)) public tokenPointHistory;

    // --- Constructor ---

    constructor(address _cypher) ERC721("Cypher veNFT", "veCYPR") {
        nextId = 1; // 0 is not a valid id
        cypher = ICypherToken(_cypher);
    }

    // --- Mutations ---

    /// @inheritdoc IVotingEscrow
    function createLock(uint256 value, uint256 duration) external nonReentrant returns (uint256) {
        return _createLock(value, duration, msg.sender);
    }

    /// @inheritdoc IVotingEscrow
    function createLockFor(uint256 value, uint256 duration, address to) external nonReentrant returns (uint256) {
        return _createLock(value, duration, to);
    }

    /// @inheritdoc IVotingEscrow
    function depositFor(uint256 tokenId, uint256 value) external nonReentrant {
        LockedBalance memory lockedBalance = locked[tokenId];

        if (value == 0) revert ZeroValue();
        address tokenOwner = _requireOwned(tokenId);
        if (lockedBalance.end <= block.timestamp && !lockedBalance.isIndefinite) revert LockExpired();

        if (lockedBalance.isIndefinite) indefiniteLockBalance += value;
        _depositFor(tokenId, value, /* unlockTime */ 0, lockedBalance);

        emit DepositFor(msg.sender, tokenOwner, tokenId, value);
    }

    /// @inheritdoc IVotingEscrow
    function increaseUnlockTime(uint256 tokenId, uint256 unlockTime) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);

        LockedBalance memory lockedBalance = locked[tokenId];
        if (lockedBalance.isIndefinite) revert LockedIndefinitely();
        if (lockedBalance.end <= block.timestamp) revert LockExpired();

        unchecked {
            // All unlock times are rounded down to the nearest mulitple of VOTE_PERIOD.
            unlockTime = (unlockTime / VOTE_PERIOD) * VOTE_PERIOD;
        }

        if (unlockTime > block.timestamp + MAX_LOCK_DURATION) revert LockDurationExceedsMaximum();
        if (unlockTime <= lockedBalance.end) revert NewUnlockTimeNotAfterOld();
        // Note: unlockTime > lockedBalance.end > block.timestamp, so unlockTime is not in the past.

        _depositFor(tokenId, /* value */ 0, unlockTime, lockedBalance);

        emit IncreaseUnlockTime(_ownerOf(tokenId), tokenId, unlockTime);
    }

    /// @inheritdoc IVotingEscrow
    function withdraw(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);

        LockedBalance memory lockedBalance = locked[tokenId];
        if (lockedBalance.isIndefinite) revert LockedIndefinitely();
        if (block.timestamp < lockedBalance.end) revert LockNotExpired();
        uint256 value = lockedBalance.amount.toUint256();

        address tokenOwner = _ownerOf(tokenId);
        _burn(tokenId);
        delete locked[tokenId];
        supply -= value;

        _checkpoint(tokenId, lockedBalance, LockedBalance(0, 0, false));

        // Cypher token is ERC20-compliant, no need for safeTransfer.
        cypher.transfer(msg.sender, value);

        emit Withdraw(tokenOwner, tokenId, value);
    }

    /// @inheritdoc IVotingEscrow
    function lockIndefinite(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
        LockedBalance memory lockedBalance = locked[tokenId];
        if (lockedBalance.isIndefinite) revert LockedIndefinitely();
        if (lockedBalance.end <= block.timestamp) revert LockExpired();

        int128 amount = lockedBalance.amount;
        indefiniteLockBalance += amount.toUint256();

        LockedBalance memory newLockedBalance = LockedBalance({amount: amount, end: 0, isIndefinite: true});
        locked[tokenId] = newLockedBalance;
        _checkpoint(tokenId, lockedBalance, newLockedBalance);

        emit LockIndefinite(_ownerOf(tokenId), tokenId, amount.toUint256());
    }

    /// @inheritdoc IVotingEscrow
    function unlockIndefinite(uint256 tokenId) external nonReentrant {
        _checkExistenceAndAuthorization(msg.sender, tokenId);
        LockedBalance memory lockedBalance = locked[tokenId];
        if (!lockedBalance.isIndefinite) revert NotLockedIndefinitely();

        int128 amount = lockedBalance.amount;
        indefiniteLockBalance -= amount.toUint256();

        LockedBalance memory newLockedBalance;
        newLockedBalance.amount = amount;

        // All unlock times are rounded down to the nearest multiple of VOTE_PERIOD.
        newLockedBalance.end = ((block.timestamp + MAX_LOCK_DURATION) / VOTE_PERIOD) * VOTE_PERIOD;
        newLockedBalance.isIndefinite = false; // default value, but want to be explicit
        locked[tokenId] = newLockedBalance;
        _checkpoint(tokenId, lockedBalance, newLockedBalance);

        emit UnlockIndefinite(_ownerOf(tokenId), tokenId, amount.toUint256(), newLockedBalance.end);
    }

    /// @inheritdoc IVotingEscrow
    function merge(uint256 from, uint256 to) external nonReentrant {
        if (from == to) revert IdenticalTokenIds();
        _checkExistenceAndAuthorization(msg.sender, from);
        _checkExistenceAndAuthorization(msg.sender, to);

        LockedBalance memory lockedTo = locked[to];
        if (lockedTo.end <= block.timestamp && !lockedTo.isIndefinite) revert LockExpired();

        LockedBalance memory lockedFrom = locked[from];
        if (lockedFrom.isIndefinite) revert LockedIndefinitely();

        uint256 unlockTime = lockedTo.end > lockedFrom.end ? lockedTo.end : lockedFrom.end;

        _burn(from);
        delete locked[from];
        _checkpoint(from, lockedFrom, LockedBalance(0, 0, false));

        LockedBalance memory newLockedTo;
        newLockedTo.amount = lockedTo.amount + lockedFrom.amount;
        newLockedTo.isIndefinite = lockedTo.isIndefinite;
        if (newLockedTo.isIndefinite) {
            indefiniteLockBalance += lockedFrom.amount.toUint256();
        } else {
            newLockedTo.end = unlockTime;
        }
        locked[to] = newLockedTo;
        _checkpoint(to, lockedTo, newLockedTo);

        emit Merge(msg.sender, from, to, lockedFrom.amount.toUint256(), lockedTo.amount.toUint256(), newLockedTo.end);
    }

    // --- Views ---

    /// @inheritdoc IVotingEscrow
    function isAuthorizedToVoteFor(address actor, uint256 tokenId) external override view returns (bool) {
        return _isAuthorized(_ownerOf(tokenId), actor, tokenId);
    }

    /// @inheritdoc IVotingEscrow
    function totalSupplyAt(uint256 timestamp) external view returns (uint256) {
        uint256 startEpoch = epochAtOrPriorTo(timestamp, epoch, pointHistory);
        if (startEpoch == 0) return 0;
        Point memory lastPoint = pointHistory[startEpoch];
        uint256 t_i = (lastPoint.ts / VOTE_PERIOD) * VOTE_PERIOD;
        for (uint256 i = 0; i < 255; i++) {
            t_i += VOTE_PERIOD;
            int128 dSlope = 0;
            if (t_i > timestamp) {
                t_i = timestamp;
            } else {
                dSlope = slopeChanges[t_i];
            }
            lastPoint.bias -= lastPoint.slope * (t_i - lastPoint.ts).toInt256().toInt128();
            if (t_i == timestamp) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = t_i;
        }

        if (lastPoint.bias < 0) return 0;
        return lastPoint.bias.toUint256();
    }

    /// @inheritdoc IVotingEscrow
    function balanceOfAt(uint256 tokenId, uint256 timestamp) external view returns (uint256) {
        uint256 tokenEpoch = epochAtOrPriorTo(timestamp, tokenPointEpoch[tokenId], tokenPointHistory[tokenId]);
        if (tokenEpoch == 0) return 0;
        Point memory lastPoint = tokenPointHistory[tokenId][tokenEpoch];
        if (lastPoint.indefinite != 0) return lastPoint.indefinite;
        lastPoint.bias -= lastPoint.slope * (timestamp - lastPoint.ts).toInt256().toInt128();
        if (lastPoint.bias < 0) return 0;
        return lastPoint.bias.toUint256();
    }

    // --- Internals ---

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

        emit CreateLock(msg.sender, to, tokenId, value, unlockTime);
    }

    function _depositFor(uint256 tokenId, uint256 value, uint256 unlockTime, LockedBalance memory lockedBalance)
        internal
    {
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
            uNew.indefinite = newLocked.isIndefinite ? newLocked.amount.toUint256() : 0;
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

        // Iterate over epochs until reaching the present. Maximum lookback time is 255 * VOTE_PERIOD.
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
                tokenPointEpoch[tokenId] = ++tokenEpoch;
                tokenPointHistory[tokenId][tokenEpoch] = uNew;
            }
        }
    }

    function epochAtOrPriorTo(uint256 timestamp, uint256 lastEpoch, mapping(uint256 => Point) storage points)
        internal
        view
        returns (uint256)
    {
        if (lastEpoch == 0 || points[1].ts > timestamp) return 0;
        if (points[lastEpoch].ts <= timestamp) return lastEpoch;

        // Established: points[1].ts <= timestamp && points[lastEpoch].ts > timestamp

        uint256 ub = lastEpoch;
        uint256 lb = 1;
        uint256 mid;
        uint256 ts;
        while (ub > lb) {
            mid = 1 + (ub + lb - 1) / 2; // divup
            ts = points[mid].ts;
            if (ts == timestamp) {
                return mid;
            } else if (ts < timestamp) {
                lb = mid;
            } else {
                ub = mid - 1;
            }
        }

        return lb;
    }
}
