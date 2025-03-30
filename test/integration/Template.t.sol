// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import "forge-std/Test.sol";

import {EnableTemplate} from "script/EnableTemplate.s.sol";
import {DisableTemplate} from "script/DisableTemplate.s.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

/// @title TemplateIntegrationTest
/// @notice Integration test for Enable and Disable script against a live system
/// @dev Run with: forge test --match-path test/integration/Template.t.sol -vvv --fork-url base
contract TemplateIntegrationTest is IntegrationBase {
    function testAddTemplateSuccess() public {
        vm.setEnv("ENABLE_PATH", "test/mocks/enable.json");
        EnableTemplate enableTemplate = new EnableTemplate();
        enableTemplate.setAddresses(addresses);
        enableTemplate.build();
        enableTemplate.simulate();
        enableTemplate.validate();
    }

    function testRemoveTemplateSuccess() public {
        testAddTemplateSuccess();

        vm.setEnv("DISABLE_PATH", "test/mocks/disable.json");
        DisableTemplate disableTemplate = new DisableTemplate();
        disableTemplate.setAddresses(addresses);
        disableTemplate.build();
        disableTemplate.simulate();
        disableTemplate.validate();
    }
}
