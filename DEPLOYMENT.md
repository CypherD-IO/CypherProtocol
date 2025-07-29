# Cypher System Deployment Guide for Base

## Cypher Token Deployment

This document provides instructions for deploying the Cypher Token (`CYPR`) to the Base network using the Foundry framework.

## Overview

The `CypherTokenDeploy` script deploys the Cypher Token contract to the Base network. The Cypher Token is an ERC20 token with Permit and Votes extensions, designed specifically for the Cypher ecosystem on Base.

Key features of the Cypher Token:
- Symbol: CYPR
- Name: Cypher
- Decimals: 18
- Initial Supply: 1,000,000,000 CYPR (1 billion)
- Extensions: ERC20Permit, ERC20Votes

## Prerequisites

Before running the deployment script, ensure you have the following:

1. **Private Key Setup**
   - Ensure a keystore file exists for your deployer account:
     ```bash
     cast wallet import <deployer_name> --private-key <your_private_key>
     ```
   - This will store your encrypted keystore at `~/.foundry/keystores/<deployer_name>`

2. **ETH on Base**
   - Ensure your deployer account has sufficient ETH on Base for gas fees
   - You can bridge ETH to Base using the [Base Bridge](https://bridge.base.org)

## Deployment Process

### 1. Set Environment Variables

Set the treasury address as an environment variable. This address will receive the initial token supply (1 billion CYPR).

```bash
export TREASURY_ADDRESS=0x<YourTreasuryAddressHere>
```

### 2. Run the Deployment Script

#### Base Mainnet Deployment

```bash
TREASURY_ADDRESS=0x<YourTreasuryAddressHere> forge script CypherTokenDeploy -vvvvv \
  --rpc-url base \
  --chain-id 8453 \
  --broadcast \
  --account ~/.foundry/keystores/<your_keystore_file> \ 
  --verify --etherscan-api-key <YOUR_BASESCAN_API_KEY>
```

#### Base Testnet (Sepolia) Deployment

```bash
TREASURY_ADDRESS=0xYourTreasuryAddressHere forge script CypherTokenDeploy -vvvvv \
  --rpc-url https://sepolia.base.org \
  --chain-id 84531 \
  --broadcast \
  --account ~/.foundry/keystores/<your_keystore_file> \ 
  --verify --etherscan-api-key <YOUR_BASESCAN_API_KEY>
```

### 3. Command Parameters Explained

- `TREASURY_ADDRESS=0x...`: Environment variable specifying the address that will receive the initial token supply
- `forge script CypherTokenDeploy`: Runs the Foundry script for deploying the Cypher Token
- `-vvvvv`: Sets verbosity level to maximum for detailed output
- `--rpc-url`: Specifies the Base network RPC endpoint
- `--chain-id`: Specifies the Base network chain ID (8453 for mainnet, 84531 for testnet)
- `--broadcast`: Broadcasts the transaction to the network (remove this flag for simulation only)
- `--account`: Specifies the keystore file containing the deployer's private key

### 4. Dry Run / Simulation

To simulate the deployment without broadcasting transactions:

```bash
TREASURY_ADDRESS=0xYourTreasuryAddressHere forge script CypherTokenDeploy -vvvvv \
  --rpc-url base \
  --chain-id 8453 \
  --account ~/.foundry/keystores/<your_keystore_file>
```

Note the absence of the `--broadcast` flag, which prevents the transaction from being sent to the network.

## Post-Deployment Steps

### 1. Verify Contract on Basescan

After deployment, verify the contract on [Basescan](https://basescan.org) (for mainnet) or [Sepolia Basescan](https://sepolia.basescan.org) (for testnet):

```bash
forge verify-contract \
  --chain-id 8453 \
  --compiler-version 0.8.28 \
  --constructor-args $(cast abi-encode "constructor(address)" "0xYourTreasuryAddressHere") \
  <DEPLOYED_CONTRACT_ADDRESS> \
  src/CypherToken.sol:CypherToken \
  --etherscan-api-key <YOUR_BASESCAN_API_KEY>
```

### 2. Confirm Treasury Balance

Verify that the treasury address received the initial token supply:

```bash
cast call <DEPLOYED_CONTRACT_ADDRESS> "balanceOf(address)(uint256)" <TREASURY_ADDRESS> --rpc-url base
```

The result should be `1000000000000000000000000000` (1 billion tokens with 18 decimals).

### 3. Basic Interaction Commands

Check total supply:
```bash
cast call <DEPLOYED_CONTRACT_ADDRESS> "totalSupply()(uint256)" --rpc-url base
```

Check token name:
```bash
cast call <DEPLOYED_CONTRACT_ADDRESS> "name()(string)" --rpc-url base
```

Check token symbol:
```bash
cast call <DEPLOYED_CONTRACT_ADDRESS> "symbol()(string)" --rpc-url base
```


## Cypher Smart Contract Deployment

## Overview

This script will deploy all non-token contracts in the Cypher system.
- `DistributionModule`: Sends emissions to the Reward Distributor
- `RewardDistributor`: Distributes Cypher rewards via Merkle Proofs
- `Election`: Manages the voting and bribing processes for Cypher governance
- `VotingEscrow`: Locks up CYPHER tokens for voting and emissions

## Prerequisites

Before running the deployment script, the following addresses must be set to their correct values in [8453.json](addresses/8453.json) as they are currently set to random values:
- `TREASURY_MULTISIG`: The address to add the DistributionModule to
- `GOVERNOR_MULTISIG`: The governor address
- `CYPHER_TOKEN`: The Cypher Governance Token
- `DEPLOYER_EOA`: The address being used to deploy the contracts

### Environment Variables
- `START_TIME`: The start time at which point emissions will go live in unix time. This number modulo `7 * 86400` must equal 0 (be at the week boundary), otherwise deployment will fail.
- `DO_UPDATE_JSON=true`: Set to true to update the addresses in the [8453.json](addresses/8453.json) file during deployment. This is set to false by default.
- `ETHERSCAN_API_KEY`: Your etherscan API key for verifying the contracts on basescan.

### Voting - Starting Candidates and Bribe Tokens

To set the starting candidates and bribe tokens, you will need to change the [election.json](genesis/election.json) file in the genesis directory. The structure is as follows:

```json
{
    "candidates": [
        "0xa210df63555e6bcab6f13f8827ac79db7a7a7dd84114b8f8c57a8f1e64619902"
    ],
    "tokens": ["CYPHER_TOKEN"]
}
```

The tokens array should contain the identifiers of the tokens in the addresses.json file. The candidates array should contain the bytes32 hashes of the candidates you want to start with.

### Dry Run / Simulation
To simulate the deployment without broadcasting transactions:

```bash
START_TIME=1743638400 forge script SystemDeploy -vvv --rpc-url base
```

### Deployment
To deploy and verify the contracts on basescan, run the following command:

```bash
START_TIME=1743638400 DO_UPDATE_JSON=true forge script SystemDeploy -vvv --rpc-url base --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --account ~/.foundry/keystores/<path_to_key_file>
```


### Post Deployment

After deploying the smart contracts, the following steps should be taken:
- Check the contracts have been verified on basescan by pasting each contract's addresses into [basescan](https://basescan.org/).
- Check that [8453.json](addresses/8453.json) has been updated with the correct addresses. Ensure all 4 addresses were added to this file.
- Check the changes in [8453.json](addresses/8453.json) into git.
