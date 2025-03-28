// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";

import {Election} from "src/Election.sol";

contract DisableTemplate is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "Disable Template";
    }
    
    function description() public pure override returns (string memory) {
        return "Disable Candidate and Tokens in Elections";
    }

    function getCandidatesAndTokens() public view returns (bytes32[] memory, address[] memory) {
        string memory path = vm.envString("DISABLE_PATH");
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
            election.disableCandidate(candidates[i]);
        }

        /// enable the tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            election.disableBribeToken(tokens[i]);
        }
    }

    function simulate() public override {
        _simulateActions(addresses.getAddress("GOVERNOR_MULTISIG"));
    }

    function validate() public view override {
        (bytes32[] memory candidates, address[] memory tokens) = getCandidatesAndTokens();

        Election election = Election(addresses.getAddress("ELECTION"));

        /// assert the candidates are disabled
        for (uint256 i = 0; i < candidates.length; i++) {
            assertFalse(election.isCandidate(candidates[i]), string.concat("Candidate enabled: ", vm.toString(candidates[i])));
        }

        /// assert the tokens are disabled
        for (uint256 i = 0; i < tokens.length; i++) {
            assertFalse(election.isBribeToken(tokens[i]), string.concat("Candidate enabled: ", vm.toString(tokens[i])));
        }
    }
}
