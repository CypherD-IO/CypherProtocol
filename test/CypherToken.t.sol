pragma solidity =0.8.28;

import "forge-std/Test.sol";

import "../src/CypherToken.sol";

contract CyperTokenTest is Test {
    function testConstruction() public {
        CypherToken token = new CypherToken(address(this));

        assertEq(token.name(), "Cypher");
        assertEq(token.symbol(), "CYPR");
        assertEq(token.totalSupply(), 499_500_000 * 1e18);
        assertEq(token.balanceOf(address(this)), token.totalSupply());
    }
}
