// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import "forge-std/Test.sol";

import {ModuleAdd} from "script/ModuleAdd.s.sol";
import {CypherToken} from "src/CypherToken.sol";
import {CypherTokenDeploy} from "script/CypherTokenDeploy.s.sol";

/// @title ModuleAddIntegration
/// @notice Integration test for ModuleAdd script against a live system
/// @dev Run with: forge test --match-path test/integration/ModuleAdd.t.sol -vvv --fork-url $RPC_URL
contract ModuleAddIntegrationTest is Test {
    Addresses public addresses;
    CypherToken public cypherToken;
    ModuleAdd public moduleAdd;

    // Mock addresses for testing
    address public constant GOVERNOR_MULTISIG = address(0x1111);
    address public constant TREASURY_MULTISIG = address(0x2222);

    // The timestamp when incentives will start (must be a week boundary)
    uint256 public startTime;

    function setUp() public {
        // Initialize Addresses contract with Base chain ID (8453)
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 8453;
        addresses = new Addresses("addresses", chainIds);

        /// TODO remove this completely once the cypher token has been deployed
        // Deploy CypherToken
        CypherTokenDeploy cypherTokenDeploy = new CypherTokenDeploy();
        address tokenAddress = cypherTokenDeploy.deploy(TREASURY_MULTISIG);
        cypherToken = CypherToken(tokenAddress);

        // Add CypherToken to Addresses
        addresses.changeAddress("CYPHER_TOKEN", tokenAddress, true);

        // Initialize ModuleAdd with our Addresses instance
        moduleAdd = new ModuleAdd();

        // Calculate a future start time that is a week boundary
        // Current timestamp + time until next week boundary
        uint256 currentTime = block.timestamp;
        uint256 weekInSeconds = 7 * 86400;
        uint256 timeUntilNextWeekBoundary = weekInSeconds - (currentTime % weekInSeconds);
        startTime = currentTime + timeUntilNextWeekBoundary;

        // Set START_TIME environment variable for deploy function in ModuleAdd
        vm.setEnv("START_TIME", vm.toString(startTime));

        moduleAdd.setAddresses(addresses);

        /// TODO remove this completely once the cypher smart contract system has been deployed
        moduleAdd.deploy();
        moduleAdd.build();
        moduleAdd.simulate();
    }

    function testValidateSuccess() public view {
        // Call validate function
        moduleAdd.validate();

        // Check if the distribution module is enabled
        assertTrue(addresses.isAddressSet("DISTRIBUTION_MODULE"), "Distribution module not set");

        // Check if the reward distributor is set
        assertTrue(addresses.isAddressSet("REWARD_DISTRIBUTOR"), "Reward distributor not set");
    }
}
