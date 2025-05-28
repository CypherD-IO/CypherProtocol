// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";
import {Addresses} from "lib/forge-proposal-simulator/addresses/Addresses.sol";

import {Election} from "src/Election.sol";
import {VotingEscrow} from "src/VotingEscrow.sol";
import {RewardDistributor} from "src/RewardDistributor.sol";
import {DistributionModule} from "src/DistributionModule.sol";

/// @notice this script requires environment variable START_TIME to be set
/// to a timestamp in the future that is a week boundary where the remainder
/// of the division by 7 * 86400 is 0. This is when incentives will start.
/// If the start time is set to the past, or not a week boundary, the script
/// will revert because the DistributionModule will fail to deploy.

/// start time must be set to a week boundary
///  example usage for local testing:
///     START_TIME=1743638400 forge script SystemDeploy -vvv --rpc-url base

///  mainnet usage:
///  please note the deployer EOA in 8453.json must be the same as the account broadcasting this transaction
///     START_TIME=1743638400 DO_UPDATE_JSON=true forge script SystemDeploy -vvv --rpc-url base --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --account ~/.foundry/keystores/<path_to_key_file>

contract SystemDeploy is MultisigProposal {
    /// @notice returns the name of the proposal
    function name() public pure override returns (string memory) {
        return "CIP-00";
    }

    function description() public pure override returns (string memory) {
        return "Deploy Cypher System, add Distribution Module to Treasury Multisig";
    }

    modifier addressModifier() {
        if (address(addresses) == address(0)) {
            uint256[] memory chainIds = new uint256[](1);
            /// lock to whichever chain is being used
            require(block.chainid == 8453 || block.chainid == 84532, "Chain ID must be base or base sepolia");
            chainIds[0] = block.chainid;
            addresses = new Addresses("addresses", chainIds);
        }
        _;
    }

    function run() public override addressModifier {
        super.run();
    }

    /// @notice deploy any contracts needed for the proposal.
    /// @dev contracts calls here are broadcast if the broadcast flag is set.
    function deploy() public override addressModifier {
        require(addresses.isAddressSet("CYPHER_TOKEN"), "Cypher token not set, cannot deploy");
        require(addresses.isAddressSet("DEPLOYER_EOA"), "Deployer EOA not set, cannot deploy");
        require(addresses.isAddressSet("GOVERNOR_MULTISIG"), "Governor Multisig not set, cannot deploy");
        require(addresses.isAddressSet("TREASURY_MULTISIG"), "Treasury Multisig not set, cannot deploy");

        if (!addresses.isAddressSet("VOTING_ESCROW")) {
            // The voting escrow is initially owned by the treasury multisig to allow a fully functional system deployment to be accomplished in one proposal.
            VotingEscrow voteEscrow = new VotingEscrow(addresses.getAddress("TREASURY_MULTISIG"), addresses.getAddress("CYPHER_TOKEN"));
            addresses.addAddress("VOTING_ESCROW", address(voteEscrow), true);
        }

        if (!addresses.isAddressSet("ELECTION")) {
            (bytes32[] memory startingCandidates, string[] memory startingBribeTokenIdentifiers) =
                getCandidatesAndTokens("genesis/election.json");

            address[] memory startingBribeTokens = new address[](startingBribeTokenIdentifiers.length);
            for (uint256 i = 0; i < startingBribeTokenIdentifiers.length; i++) {
                startingBribeTokens[i] = addresses.getAddress(startingBribeTokenIdentifiers[i]);
            }

            Election election = new Election(
                addresses.getAddress("GOVERNOR_MULTISIG"),
                addresses.getAddress("VOTING_ESCROW"),
                startingCandidates,
                startingBribeTokens
            );

            addresses.addAddress("ELECTION", address(election), true);
        }

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
                addresses.getAddress("REWARD_DISTRIBUTOR"),
                /// start time is an environment variable set by deployer
                vm.envUint("START_TIME")
            );
            addresses.addAddress("DISTRIBUTION_MODULE", address(distributionModule), true);
        }
    }

    function build() public override addressModifier buildModifier(addresses.getAddress("TREASURY_MULTISIG")) {
        // add the distribution module to the treasury multisig
        ModuleManager(addresses.getAddress("TREASURY_MULTISIG")).enableModule(
            addresses.getAddress("DISTRIBUTION_MODULE")
        );

        VotingEscrow voteEscrow = VotingEscrow(addresses.getAddress("VOTING_ESCROW"));

        // set the Election as the veNFT usage oracle on the VotingEscrow
        voteEscrow.setVeNftUsageOracle(addresses.getAddress("ELECTION"));

        // The owner of the VotingEscrow should be the governor multisig going forward.
        voteEscrow.transferOwnership(addresses.getAddress("GOVERNOR_MULTISIG"));
    }

    function simulate() public override addressModifier {
        vm.startPrank(addresses.getAddress("TREASURY_MULTISIG"));
        (address[] memory targets, uint256[] memory values, bytes[] memory arguments) = getProposalActions();

        /// execute all actions
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call{value: values[i]}(arguments[i]);
            require(success, "Transaction failed");
        }

        vm.stopPrank();
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

        Election election = Election(addresses.getAddress("ELECTION"));
        assertEq(election.owner(), governor, "Election not owned by governor multisig");
        assertEq(address(election.ve()), addresses.getAddress("VOTING_ESCROW"), "Voting Escrow not set");

        VotingEscrow voteEscrow = VotingEscrow(addresses.getAddress("VOTING_ESCROW"));
        assertEq(address(voteEscrow.cypher()), addresses.getAddress("CYPHER_TOKEN"), "Cypher Token not set");
        assertEq(voteEscrow.owner(), governor);
        assertEq(address(voteEscrow.veNftUsageOracle()), address(election));
    }

    function getCandidatesAndTokens(string memory path) public view returns (bytes32[] memory, string[] memory) {
        string memory fileContents = vm.readFile(path);
        bytes32[] memory candidates = vm.parseJsonBytes32Array(fileContents, ".candidates");
        string[] memory tokens = vm.parseJsonStringArray(fileContents, ".tokens");

        return (candidates, tokens);
    }
}
