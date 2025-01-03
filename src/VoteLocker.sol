// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./interfaces/IVoteLocker.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VoteLocker is IVoteLocker, ERC721, ReentrancyGuard {

    uint256 nextId;

    constructor() ERC721("Cypher veNFT", "veCYPR") {
        nextId = 1;  // 0 is not a valid id
    }

    // --- Auth Helpers ---
    function _checkExistenceAndAuthorization(address spender, uint256 tokenId) internal {
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
        tokenId = nextId++;
        _mint(to, tokenId);
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
}
