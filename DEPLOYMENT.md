# Cypher Token Deployment Guide for Base

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
     cast wallet import --name <deployer_name> --private-key <your_private_key>
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

## Base-Specific Considerations

1. **RPC Errors**: If you encounter RPC errors, try using an alternative RPC endpoint or check the Base status page.

2. **Keystore Access**: If you have issues accessing your keystore, ensure the path is correct and that you have the password.
