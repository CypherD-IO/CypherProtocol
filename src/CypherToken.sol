// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.28;

import {ICypherToken} from "./interfaces/ICypherToken.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title CypherToken
/// @notice The token for the Cypher ecosystem.
contract CypherToken is ICypherToken, ERC20Permit {
    constructor(address treasury) ERC20("Cypher", "CYPR") ERC20Permit("Cypher") {
        // mint tokens to a single recipient and handle the rest via transfers from the treasury
        _mint(treasury, 1_000_000_000 * 1e18);
    }
}
