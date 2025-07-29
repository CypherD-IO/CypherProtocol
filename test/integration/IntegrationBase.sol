// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import "forge-std/Test.sol";

import {SystemDeploy} from "script/SystemDeploy.s.sol";
import {CypherToken} from "src/CypherToken.sol";
import {CypherTokenDeploy} from "script/CypherTokenDeploy.s.sol";

/// @title ModuleIntegrationBase
contract IntegrationBase is Test {
    Addresses public addresses;
    CypherToken public cypherToken;
    SystemDeploy public systemDeploy;

    // Mock addresses for testing
    address public GOVERNOR_MULTISIG;
    address public TREASURY_MULTISIG;

    // The timestamp when incentives will start (must be a week boundary)
    uint256 public startTime;

    function setUp() public {
        // Initialize Addresses contract with Base chain ID (8453)
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 8453;
        addresses = new Addresses("addresses", chainIds);

        GOVERNOR_MULTISIG = addresses.getAddress("GOVERNOR_MULTISIG");
        TREASURY_MULTISIG = addresses.getAddress("TREASURY_MULTISIG");

        // Deploy CypherToken
        CypherTokenDeploy cypherTokenDeploy = new CypherTokenDeploy();
        address tokenAddress = cypherTokenDeploy.deploy(TREASURY_MULTISIG);
        cypherToken = CypherToken(tokenAddress);

        // Add CypherToken to Addresses
        addresses.changeAddress("CYPHER_TOKEN", tokenAddress, true);

        // Initialize SystemDeploy with our Addresses instance
        systemDeploy = new SystemDeploy();

        // Calculate a future start time that is a week boundary
        // Current timestamp + time until next week boundary
        uint256 currentTime = block.timestamp;
        uint256 twoWeeksInSeconds = 14 * 86400;
        uint256 timeUntilNextTwoWeekBoundary = twoWeeksInSeconds - (currentTime % twoWeeksInSeconds);
        startTime = currentTime + timeUntilNextTwoWeekBoundary;

        // Set START_TIME environment variable for deploy function in SystemDeploy
        vm.setEnv("START_TIME", vm.toString(startTime));

        systemDeploy.setAddresses(addresses);

        systemDeploy.deploy();
        systemDeploy.build();
        systemDeploy.simulate();
    }
}
