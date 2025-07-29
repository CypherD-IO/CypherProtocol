// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IVeNftUsageOracle} from "src/interfaces/IVeNftUsageOracle.sol";

contract MockVeNftUsageOracle is IVeNftUsageOracle {
    mapping(uint256 tokenId => bool inUse) public override isInUse;

    function setInUse(uint256 tokenId, bool inUse) external {
        isInUse[tokenId] = inUse;
    }
}
