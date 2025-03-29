// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {ModuleManager} from "lib/safe-contracts/contracts/base/ModuleManager.sol";

import {Election} from "src/Election.sol";
import {BaseTemplate} from "script/BaseTemplate.sol";

contract DisableTemplate is BaseTemplate {
    function name() public pure override returns (string memory) {
        return "Disable Template";
    }

    function description() public pure override returns (string memory) {
        return "Disable Candidate and Tokens in Elections";
    }

    function build() public override addressModifier buildModifier(addresses.getAddress("GOVERNOR_MULTISIG")) {
        // add the distribution module to the treasury multisig
        (bytes32[] memory candidates, string[] memory tokens) = getCandidatesAndTokens("DISABLE_PATH");

        Election election = Election(addresses.getAddress("ELECTION"));

        /// enable the candidates
        for (uint256 i = 0; i < candidates.length; i++) {
            election.disableCandidate(candidates[i]);
        }

        /// enable the tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            election.disableBribeToken(addresses.getAddress(tokens[i]));
        }
    }

    function validate() public view override {
        (bytes32[] memory candidates, string[] memory tokens) = getCandidatesAndTokens("DISABLE_PATH");

        Election election = Election(addresses.getAddress("ELECTION"));

        /// assert the candidates are disabled
        for (uint256 i = 0; i < candidates.length; i++) {
            assertFalse(
                election.isCandidate(candidates[i]), string.concat("Candidate enabled: ", vm.toString(candidates[i]))
            );
        }

        /// assert the tokens are disabled
        for (uint256 i = 0; i < tokens.length; i++) {
            assertFalse(
                election.isBribeToken(addresses.getAddress(tokens[i])), string.concat("Candidate enabled: ", tokens[i])
            );
        }
    }
}
