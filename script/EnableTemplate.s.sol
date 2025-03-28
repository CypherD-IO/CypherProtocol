// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";

import {Election} from "src/Election.sol";

contract EnableTemplate is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "Enable Template";
    }

    function description() public pure override returns (string memory) {
        return "Enable Candidate and Tokens in Elections";
    }

    function getCandidatesAndTokens() public view returns (bytes32[] memory, address[] memory) {
        string memory path = vm.envString("ENABLE_PATH");
        string memory fileContents = vm.readFile(path);
        bytes32[] memory candidates = vm.parseJsonBytes32Array(fileContents, ".candidates");
        address[] memory tokens = vm.parseJsonAddressArray(fileContents, ".tokens");

        return (candidates, tokens);
    }

    function build() public override buildModifier(addresses.getAddress("GOVERNOR_MULTISIG")) {
        // add the distribution module to the treasury multisig
        (bytes32[] memory candidates, address[] memory tokens) = getCandidatesAndTokens();

        Election election = Election(addresses.getAddress("ELECTION"));

        /// enable the candidates
        for (uint256 i = 0; i < candidates.length; i++) {
            election.enableCandidate(candidates[i]);
        }

        /// enable the tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            election.enableBribeToken(tokens[i]);
        }
    }

    function simulate() public override {
        _simulateActions(addresses.getAddress("GOVERNOR_MULTISIG"));
    }

    function validate() public view override {
        (bytes32[] memory candidates, address[] memory tokens) = getCandidatesAndTokens();

        Election election = Election(addresses.getAddress("ELECTION"));

        /// assert the candidates are enabled
        for (uint256 i = 0; i < candidates.length; i++) {
            assertTrue(
                election.isCandidate(candidates[i]),
                string.concat("Candidate not enabled: ", vm.toString(candidates[i]))
            );
        }

        /// assert the tokens are enabled
        for (uint256 i = 0; i < tokens.length; i++) {
            assertTrue(
                election.isBribeToken(tokens[i]), string.concat("Candidate not enabled: ", vm.toString(tokens[i]))
            );
        }
    }
}
