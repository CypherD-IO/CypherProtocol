// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "src/CypherToken.sol";

contract CypherTokenDeploy is Script {
    function deploy(address treasury) public returns (address) {
        return address(new CypherToken(treasury));
    }

    function run() public returns (CypherToken) {
        // Retrieve treasury address from environment variable
        address treasury = vm.envAddress("TREASURY_ADDRESS");

        // Start broadcast to record and send transactions
        vm.startBroadcast();

        // Deploy the CypherToken contract
        CypherToken token = CypherToken(deploy(treasury));

        // End broadcast
        vm.stopBroadcast();

        require(token.balanceOf(treasury) == 1_000_000_000 * 1e18, "CypherTokenDeploy: treasury balance mismatch");

        // Return the deployed contract
        return token;
    }
}
