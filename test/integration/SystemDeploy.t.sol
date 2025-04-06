// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import "forge-std/Test.sol";

import {SystemDeploy} from "script/SystemDeploy.s.sol";
import {CypherToken} from "src/CypherToken.sol";
import {CypherTokenDeploy} from "script/CypherTokenDeploy.s.sol";

import {IntegrationBase} from "test/integration/IntegrationBase.sol";

/// @title SystemDeployIntegration
/// @notice Integration test for SystemDeploy script against a live system
/// @dev Run with: forge test --match-path test/integration/SystemDeploy.t.sol -vvv --fork-url $RPC_URL
contract SystemDeployIntegrationTest is IntegrationBase {
    function testValidateSuccess() public view {
        // Call validate function
        systemDeploy.validate();

        // Check if the distribution module is enabled
        assertTrue(addresses.isAddressSet("DISTRIBUTION_MODULE"), "Distribution module not set");

        // Check if the reward distributor is set
        assertTrue(addresses.isAddressSet("REWARD_DISTRIBUTOR"), "Reward distributor not set");
    }
}
