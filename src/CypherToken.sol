pragma solidity =0.8.28;

import "./interfaces/ICypherToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @title CypherToken
/// @notice The token for the Cypher ecosystem.
contract CypherToken is ICypherToken, ERC20Permit, ERC20Votes {
    constructor(address treasury) ERC20("Cypher", "CYPR") ERC20Permit("Cypher") {
        // TODO: mint tokens to appropriate recipients or decide to do this via transfers
        // from the treasury
        _mint(treasury, 499_500_000 * 1e18);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20Votes, ERC20) {
        ERC20Votes._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return ERC20Permit.nonces(owner);
    }
}
