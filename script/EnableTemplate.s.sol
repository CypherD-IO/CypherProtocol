// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {IElection} from "src/interfaces/IElection.sol";
import {BaseTemplate} from "script/BaseTemplate.sol";

contract EnableTemplate is BaseTemplate {
    function name() public pure override returns (string memory) {
        return "Enable Template";
    }

    function description() public pure override returns (string memory) {
        return "Enable Candidate and Tokens in Elections";
    }

    function build() public override addressModifier buildModifier(addresses.getAddress("GOVERNOR_MULTISIG")) {
        // add the distribution module to the treasury multisig
        (bytes32[] memory candidates, string[] memory tokens) = getCandidatesAndTokens("ENABLE_PATH");

        IElection election = IElection(addresses.getAddress("ELECTION"));

        /// enable the candidates
        for (uint256 i = 0; i < candidates.length; i++) {
            election.enableCandidate(candidates[i]);
        }

        /// enable the tokens
        for (uint256 i = 0; i < tokens.length; i++) {
            election.enableBribeToken(addresses.getAddress(tokens[i]));
        }
    }

    function validate() public view override {
        (bytes32[] memory candidates, string[] memory tokens) = getCandidatesAndTokens("ENABLE_PATH");

        IElection election = IElection(addresses.getAddress("ELECTION"));

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
                election.isBribeToken(addresses.getAddress(tokens[i])),
                string.concat("Candidate not enabled: ", tokens[i])
            );
        }
    }
}
