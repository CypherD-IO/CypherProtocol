// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";

import {RewardDistributor} from "src/RewardDistributor.sol";
import {DistributionModule} from "src/DistributionModule.sol";

/// @notice this script requires environment variable START_TIME to be set
/// to a timestamp in the future that is a week boundary where the remainder
/// of the division by 7 * 86400 is 0. This is when incentives will start.
contract ModuleAdd is MultisigProposal {
    /// @notice returns the name of the proposal
    function name() public pure override returns (string memory) {
        return "CIP-00";
    }

    function description() public pure override returns (string memory) {
        return "Deploy Distribution Module and Reward Distributor, add Distribution Module to Treasury Multisig";
    }

    /// @notice deploy any contracts needed for the proposal.
    /// @dev contracts calls here are broadcast if the broadcast flag is set.
    function deploy() public override {
        if (!addresses.isAddressSet("REWARD_DISTRIBUTOR")) {
            /// TODO add all of the addresses to the base (8453) JSON file
            RewardDistributor rewardDistributor =
                new RewardDistributor(addresses.getAddress("GOVERNOR_MULTISIG"), addresses.getAddress("CYPHER_TOKEN"));
            addresses.addAddress("REWARD_DISTRIBUTOR", address(rewardDistributor), true);
        }

        if (!addresses.isAddressSet("DISTRIBUTION_MODULE")) {
            DistributionModule distributionModule = new DistributionModule(
                addresses.getAddress("GOVERNOR_MULTISIG"),
                addresses.getAddress("TREASURY_MULTISIG"),
                addresses.getAddress("CYPHER_TOKEN"),
                /// ??? who is this ??? and how does it decide on how much bribes / rewards to have
                addresses.getAddress("REWARD_DISTRIBUTOR"),
                /// start time is an environment variable set by deployer
                vm.envUint("START_TIME")
            );
            addresses.addAddress("DISTRIBUTION_MODULE", address(distributionModule), true);
        }
    }

    function build() public override buildModifier(addresses.getAddress("TREASURY_MULTISIG")) {
        // add the distribution module to the treasury multisig
        ModuleManager(addresses.getAddress("TREASURY_MULTISIG")).enableModule(
            addresses.getAddress("DISTRIBUTION_MODULE")
        );
    }

    function validate() public view override {
        assertTrue(
            ModuleManager(addresses.getAddress("TREASURY_MULTISIG")).isModuleEnabled(
                addresses.getAddress("DISTRIBUTION_MODULE")
            ),
            "Distribution module not enabled"
        );
        DistributionModule module = DistributionModule(addresses.getAddress("DISTRIBUTION_MODULE"));
        assertEq(
            module.safe(),
            addresses.getAddress("TREASURY_MULTISIG"),
            "Distribution module not pointing to treasury multisig"
        );

        address cypherToken = addresses.getAddress("CYPHER_TOKEN");
        address governor = addresses.getAddress("GOVERNOR_MULTISIG");
        address rewardDistributor = addresses.getAddress("REWARD_DISTRIBUTOR");

        assertEq(address(module.token()), cypherToken, "Distribution module not pointing to Cypher token");
        assertEq(module.owner(), governor, "Distribution module not owned by governor multisig");
        assertEq(module.emissionAddress(), rewardDistributor, "Reward Distributor not properly set");

        /// this check cannnot be run after the second period
        assertEq(module.lastEmissionTime(), vm.envUint("START_TIME"), "Distribution module start time incorrect");

        RewardDistributor distributor = RewardDistributor(rewardDistributor);
        assertEq(distributor.owner(), governor, "Reward Distributor not owned by governor multisig");
        assertEq(address(distributor.cypher()), cypherToken, "Reward Distributor not pointing to Cypher token");
    }
}
