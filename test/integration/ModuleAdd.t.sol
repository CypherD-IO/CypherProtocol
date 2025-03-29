// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import "forge-std/Test.sol";

import {ModuleAdd} from "script/ModuleAdd.s.sol";
import {CypherToken} from "src/CypherToken.sol";
import {CypherTokenDeploy} from "script/CypherTokenDeploy.s.sol";

import {IntegrationBase} from "test/integration/IntegrationBase.sol";

/// @title ModuleAddIntegration
/// @notice Integration test for ModuleAdd script against a live system
/// @dev Run with: forge test --match-path test/integration/ModuleAdd.t.sol -vvv --fork-url $RPC_URL
contract ModuleAddIntegrationTest is IntegrationBase {
    function testValidateSuccess() public view {
        // Call validate function
        moduleAdd.validate();

        // Check if the distribution module is enabled
        assertTrue(addresses.isAddressSet("DISTRIBUTION_MODULE"), "Distribution module not set");

        // Check if the reward distributor is set
        assertTrue(addresses.isAddressSet("REWARD_DISTRIBUTOR"), "Reward distributor not set");
    }
}
