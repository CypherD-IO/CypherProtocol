// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "src/TestnetRewardDistributor.sol";

contract TestnetRewardDistributorDeploy is Script {
    function deploy(address usdc) public returns (address) {
        return address(new TestnetRewardDistributor(usdc));
    }

    function run() public returns (TestnetRewardDistributor) {
        // Retrieve treasury address from environment variable
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Start broadcast to record and send transactions
        vm.startBroadcast();

        // Deploy the TestnetRewardDistributor contract
        TestnetRewardDistributor distributor = TestnetRewardDistributor(deploy(usdc));

        // End broadcast
        vm.stopBroadcast();

        // Return the deployed contract
        return distributor;
    }
}
