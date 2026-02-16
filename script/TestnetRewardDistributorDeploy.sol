// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "src/TestnetRewardDistributor.sol";

contract TestnetRewardDistributorDeploy is Script {
    function deploy(address initialOwner, address usdc) public returns (address) {
        return address(new TestnetRewardDistributor(initialOwner, usdc));
    }

    function run() public returns (TestnetRewardDistributor) {
        // Retrieve treasury address from environment variable
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Start broadcast to record and send transactions
        vm.startBroadcast();

        // Deploy the TestnetRewardDistributor contract
        TestnetRewardDistributor distributor =
            TestnetRewardDistributor(deploy(address(0x4Cdb559aD4b9Deef56044b3BC5f438A0964a950c), usdc));

        // End broadcast
        vm.stopBroadcast();

        // Return the deployed contract
        return distributor;
    }
}
