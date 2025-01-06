pragma solidity =0.8.28;

import "./interfaces/ICypherToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title CypherToken
/// @notice The token for the Cypher ecosystem.
contract CypherToken is ICypherToken, ERC20Permit {
    constructor(address treasury) ERC20("Cypher", "CYPR") ERC20Permit("Cypher") {
       // TODO: mint tokens to appropriate recipients or decide to do this via transfers
       // from the treasury
       _mint(treasury, 499_500_000 * 1e18);
    }
}
