// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "forge-std/Script.sol";
import "src/AirdropDistributor.sol";

contract AirdropDistributorDeploy is Script {
    function deploy(address initialOwner, address cypher, address votingEscrow, address election) public returns (address) {
        return address(new AirdropDistributor(initialOwner, cypher, votingEscrow, election));
    }

    function run() public returns (AirdropDistributor) {
        // Retrieve treasury address from environment variable
        address initialOwner = address(0x4F3299D378ee4643DfF92D5e76716682A321A650);
        address cypher = address(0xD262A4c7108C8139b2B189758e8D17c3DFC91a38);
        address votingEscrow = address(0x34Eba627690d3Db91353b4948270BF7b62a865A8);
        address election = address(0x6a70dbBf029B00F177D697Bc549386A3b163c80F);

        // Start broadcast to record and send transactions
        vm.startBroadcast();

        // Deploy the CypherToken contract
        AirdropDistributor distributor = AirdropDistributor(deploy(initialOwner, cypher, votingEscrow, election));

        // End broadcast
        vm.stopBroadcast();

        // Return the deployed contract
        return distributor;
    }
}
