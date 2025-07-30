# Cypher Protocol

[![License: BUSL-1.1](https://img.shields.io/badge/License-BUSL--1.1-blue.svg)](https://mariadb.com/bsl11/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-2024.01-blue.svg)](https://getfoundry.sh/)

> **Cypher Protocol** is a decentralized governance and incentive system built on Base, featuring tokenized voting power, merchant incentives, and a sophisticated reward distribution mechanism.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Core Components](#core-components)
- [Getting Started](#getting-started)
- [Development](#development)
- [Deployment](#deployment)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

Cypher Protocol implements a comprehensive governance and incentive system with the following key features:

- **Voting Escrow (veNFT)**: Lock tokens to earn voting power with time-decay mechanics
- **Election System**: Democratic governance with candidate voting and bribe mechanisms
- **Distribution Module**: Automated token emissions with predefined schedules
- **Reward Distributor**: Merit-based reward distribution system
- **Merchant Incentives**: Tokenized points system for merchant engagement

### Key Innovations

- **ve(3,3) Mechanics**: Inspired by Curve's voting escrow with enhanced features
- **Cross-Chain Governance**: Built on Base for scalability and cost efficiency
- **Merchant Integration**: Tokenized points system for real-world adoption
- **Automated Emissions**: Predictable token distribution schedules

## 📖 Architecture

### System Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  VotingEscrow   │    │     Election    │    │ Distribution    │
│   (veNFT)       │◄──►│   (Governance)  │◄──►│    Module       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│RewardDistributor│    │   Bribe System  │    │   Safe Treasury │
│  (Merit-based)  │    │   (Incentives)  │    │   (Gnosis Safe) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Governance Flow

1. **Token Locking**: Users lock CYPHER tokens in VotingEscrow
2. **Voting Power**: Lock duration determines voting power with time decay
3. **Governance**: veNFT holders vote on candidates and proposals
4. **Rewards**: Merit-based distribution through RewardDistributor
5. **Emissions**: Automated token distribution via DistributionModule

## 🔧 Core Components

### 1. VotingEscrow (`src/VotingEscrow.sol`)

**Purpose**: Tokenized voting power with time-decay mechanics

**Key Features**:

- **Lock Duration**: 2-week to 2-year lock periods
- **Voting Power**: Time-weighted voting power calculation
- **Indefinite Locks**: Option for permanent voting power
- **Merge Functionality**: Combine multiple veNFTs
- **Usage Oracle**: Prevent voting conflicts

```solidity
// Create a lock for voting power
function createLock(uint256 value, uint256 duration) external returns (uint256);

// Merge two veNFTs
function merge(uint256 from, uint256 to) external;

// Lock indefinitely (no time decay)
function lockIndefinite(uint256 tokenId) external;
```

### 2. Election (`src/Election.sol`)

**Purpose**: Democratic governance with candidate voting and bribe mechanisms

**Key Features**:

- **Candidate Voting**: Vote for multiple candidates with weighted distribution
- **Bribe System**: Incentivize voting through token bribes
- **Period-based**: 2-week voting periods
- **Vote Persistence**: Automated vote refresh mechanism
- **Usage Oracle**: Prevent veNFT manipulation during voting

```solidity
// Vote for candidates with weights
function vote(uint256 tokenId, bytes32[] calldata candidates, uint256[] calldata weights) external;

// Add bribes for candidates
function addBribe(address bribeToken, uint256 amount, bytes32 candidate) external;

// Claim bribes for voting
function claimBribes(uint256 tokenId, address[] calldata bribeTokens, bytes32[] calldata candidates, uint256 from, uint256 until) external;
```

### 3. DistributionModule (`src/DistributionModule.sol`)

**Purpose**: Automated token emissions with predefined schedules

**Key Features**:

- **Emission Schedules**: Multi-phase emission with decreasing rates
- **Week-aligned**: All emissions aligned to week boundaries
- **Safe Integration**: Uses Gnosis Safe for secure token transfers
- **Governance Control**: Owner can update emission address

```solidity
// Emission schedule phases:
// 0-3 months: 5M tokens/week
// 3-6 months: 10M tokens/week
// 6-9 months: 15M tokens/week
// 9 months-2 years: 100M tokens/year
// Years 2-20: Decreasing rates (40M → 20M → 10M → 7.5M → 5M/year)
```

### 4. RewardDistributor (`src/RewardDistributor.sol`)

**Purpose**: Merit-based reward distribution system

**Key Features**:

- **Merit Calculation**: Algorithmic merit scoring
- **Distribution**: Automated reward distribution
- **Governance**: Owner-controlled parameters
- **Transparency**: Public merit and reward tracking

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- [Node.js](https://nodejs.org/) (v18+)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/CypherProtocol.git
cd CypherProtocol

# Install dependencies
forge install

# Build the project
forge build
```

### Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Set required environment variables
export START_TIME=1744243200  # Must be multiple of 2 weeks
export BASESCAN_API_KEY=your_api_key
export DEPLOYER_PRIVATE_KEY=your_private_key
```

## 🛠️ Development

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract VotingEscrow

# Run with verbose output
forge test -vvv

# Run with gas reporting
forge test --gas-report
```

### Code Quality

```bash
# Format code
forge fmt

# Lint code
forge build --force

# Run slither analysis
slither .
```

### Local Development

```bash
# Start local node
anvil

# Deploy to local network
forge script SystemDeploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

## 📦 Deployment

### Prerequisites

1. **Environment Variables**:

   ```bash
   export START_TIME=1744243200  # Must be multiple of 2 weeks
   export BASESCAN_API_KEY=your_api_key
   export DEPLOYER_PRIVATE_KEY=your_private_key
   ```

2. **Address Configuration**:
   - Update `addresses/8453.json` with required addresses
   - Ensure all required contracts are deployed

### Deployment Commands

```bash
# Deploy to Base mainnet
forge script SystemDeploy.s.sol \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY

# Deploy to Base Sepolia testnet
forge script SystemDeploy.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

### Deployment Workflow

1. **Deploy Contracts**:

   ```bash
   forge script SystemDeploy.s.sol --sig "deploy()" --rpc-url <rpc> --broadcast
   ```

2. **Configure System**:

   ```bash
   forge script SystemDeploy.s.sol --sig "build()" --rpc-url <rpc> --broadcast
   ```

3. **Validate Setup**:
   ```bash
   forge script SystemDeploy.s.sol --sig "validate()" --rpc-url <rpc>
   ```

## 🔒 Security

### Security Features

- **Reentrancy Protection**: All critical functions use `ReentrancyGuard`
- **Access Control**: Role-based access control with `Ownable`
- **Input Validation**: Comprehensive parameter validation
- **Safe Integration**: Uses Gnosis Safe for treasury management
- **Usage Oracle**: Prevents veNFT manipulation during voting

### Audit Status

- **Internal Review**: ✅ Complete
- **External Audit**: 🔄 In Progress

### Known Limitations

- **Gas Limits**: Large candidate sets may hit block gas limits
- **Time Alignment**: All timestamps must align to 2-week periods
- **Bribe Precision**: Small precision loss in bribe calculations

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes
4. **Test** thoroughly
5. **Submit** a pull request

### Code Standards

- Follow Solidity style guide
- Write comprehensive tests
- Add detailed documentation
- Include gas optimization considerations

## 📄 License

This project is licensed under the **BUSL-1.1 License** - see the [LICENSE](LICENSE) file for details.

## 📚 Resources

- **Whitepaper**: [Cypher Protocol Whitepaper](https://public.cypherd.io/CypherWhitePaper.pdf)

## ✨ Acknowledgments

- **Curve Finance**: Inspiration for ve(3,3) mechanics
- **Gnosis Safe**: Treasury management infrastructure
- **Base**: Scalable L2 infrastructure
- **OpenZeppelin**: Security libraries and contracts

---

**Built with ❤️ by the Cypher Protocol team**

> **Disclaimer**: This software is provided "as is" without warranty. Use at your own risk. The Cypher Protocol team is not responsible for any financial losses incurred through the use of this software.
