// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {MultisigProposal} from "forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import {Addresses} from "forge-proposal-simulator/addresses/Addresses.sol";

abstract contract BaseTemplate is MultisigProposal {
    /// sets the address object if not already set
    modifier addressModifier() {
        if (address(addresses) == address(0)) {
            uint256[] memory chainIds = new uint256[](1);
            chainIds[0] = 8453;
            addresses = new Addresses("addresses", chainIds);
        }
        _;
    }

    function getCandidatesAndTokens(string memory pathEnvVariable)
        public
        view
        returns (bytes32[] memory, string[] memory)
    {
        string memory path = vm.envString(pathEnvVariable);
        string memory fileContents = vm.readFile(path);
        bytes32[] memory candidates = vm.parseJsonBytes32Array(fileContents, ".candidates");
        string[] memory tokens = vm.parseJsonStringArray(fileContents, ".tokens");

        return (candidates, tokens);
    }

    function simulate() public override {
        _simulateActions(addresses.getAddress("GOVERNOR_MULTISIG"));
    }
}
