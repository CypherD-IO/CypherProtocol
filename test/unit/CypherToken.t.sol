// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Test.sol";

import "src/CypherToken.sol";

contract CypherTokenUnitTest is Test {
    CypherToken token;

    function setUp() public {
        token = new CypherToken(address(this));
    }

    function testConstruction() public view {
        assertEq(token.name(), "Cypher");
        assertEq(token.symbol(), "CYPR");
        assertEq(token.totalSupply(), 1_000_000_000 * 1e18);
        assertEq(token.balanceOf(address(this)), token.totalSupply());
    }
}
