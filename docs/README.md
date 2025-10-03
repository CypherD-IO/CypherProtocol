# Cypher Protocol: Decentralized Governance & Incentive Infrastructure

[![License: BUSL-1.1](https://img.shields.io/badge/License-BUSL--1.1-blue.svg)](https://mariadb.com/bsl11/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-2024.01-blue.svg)](https://getfoundry.sh/)

> **Cypher Protocol** is a sophisticated decentralized governance and incentive system built on Base, implementing tokenized voting power, automated emissions, and merit-based reward distribution to create a sustainable DeFi ecosystem.

## 📋 Table of Contents

- [Understanding DeFi Fundamentals](#understanding-defi-fundamentals)
- [The Cypher Protocol Solution](#the-cypher-protocol-solution)
- [Core Mechanics Explained](#core-mechanics-explained)
- [Infrastructure Architecture](#infrastructure-architecture)
- [Contract Deep Dive](#contract-deep-dive)
- [CYPR Token Significance](#cypr-token-significance)
- [DeFi Principles Implementation](#defi-principles-implementation)
- [Getting Started](#getting-started)
- [Resources](#resources)

## 🌐 Understanding DeFi Fundamentals

### What is Decentralized Finance (DeFi)?

Decentralized Finance represents a paradigm shift from traditional financial systems to open, permissionless, and transparent financial protocols built on blockchain technology. Unlike traditional finance where intermediaries control access and decision-making, DeFi enables:

- **Permissionless Access**: Anyone can participate without approval
- **Transparency**: All transactions and rules are publicly verifiable
- **Decentralization**: No single entity controls the system
- **Composability**: Protocols can interact and build upon each other
- **Programmability**: Financial logic is encoded in smart contracts

### Why DeFi Matters

DeFi addresses fundamental problems in traditional finance:

1. **Centralization Risk**: Traditional systems rely on trusted intermediaries who can fail or act maliciously
2. **Access Barriers**: Geographic, economic, and regulatory restrictions limit participation
3. **Opacity**: Complex financial products hide risks and true costs
4. **Inefficiency**: Multiple intermediaries add costs and delays
5. **Censorship**: Central authorities can freeze or seize assets

### The Governance Challenge in DeFi

One of the most critical challenges in DeFi is **governance** - how decisions are made about protocol changes, parameter updates, and resource allocation. Poor governance can lead to:

- **Centralization**: Small groups controlling protocol decisions
- **Short-termism**: Decisions that benefit immediate stakeholders over long-term health
- **Inequality**: Unequal participation in governance processes
- **Instability**: Rapid changes that destabilize the ecosystem

## 🎯 The Cypher Protocol Solution

Cypher Protocol addresses these DeFi governance challenges through a comprehensive infrastructure that combines:

### 1. **Tokenized Voting Power (veNFT)**

- Lock CYPR tokens to earn voting power
- Longer locks = more voting power
- Time decay encourages long-term commitment
- NFT representation enables flexible management

### 2. **Democratic Governance**

- Vote for multiple candidates with weighted preferences
- 2-week voting periods for regular participation
- Automated vote refresh for convenience
- Bribe system incentivizes informed voting

### 3. **Automated Token Distribution**

- 20-year emission schedule with decreasing rates
- Merit-based reward distribution
- Predictable and transparent token economics
- Sustainable long-term incentives

### 4. **Secure Infrastructure**

- Gnosis Safe integration for treasury management
- Battle-tested smart contracts
- Comprehensive security measures
- Decentralized governance controls

## ⚙️ Core Mechanics Explained

### Token Locking Mechanism

**How It Works:**

1. Users lock CYPR tokens for a specific duration (2 weeks to 2 years)
2. The system mints a veNFT (voting escrow NFT) representing the locked position
3. Voting power is calculated based on amount locked and duration
4. Users can add more tokens or extend lock duration

**Voting Power Formula:**

```
Voting Power = Locked Amount × (Time Remaining / Maximum Lock Duration)
```

**Examples:**

- Lock 1,000 CYPR for 1 year → ~500 voting power
- Lock 1,000 CYPR for 2 years → ~1,000 voting power
- Lock 1,000 CYPR indefinitely → Always 1,000 voting power

### Power Decay System

**Why Decay Exists:**

- Encourages active participation
- Prevents stale voting power
- Creates urgency for decision-making
- Aligns incentives with current stakeholders

**How Decay Works:**

- Voting power decreases linearly over time
- Decay rate is proportional to lock duration
- Longer locks decay slower
- Indefinite locks have no decay

**Benefits:**

- Prevents accumulation of stale voting power
- Encourages regular participation
- Creates dynamic governance participation
- Aligns voting power with current commitment

### Voting System

**Voting Process:**

1. Users vote for multiple candidates with different weights
2. Total voting power is distributed proportionally
3. Votes are recorded for the current 2-week period
4. Users can claim bribes after each period ends

**Vote Weighting:**

- Users can allocate voting power across multiple candidates
- Weights must sum to 100% of available voting power
- Proportional distribution ensures fair representation
- Example: 60% Candidate A, 40% Candidate B

**Bribe Mechanism:**

- Anyone can offer bribes to incentivize voting for specific candidates
- Bribes are distributed proportionally to vote weight
- Multiple tokens can be used for bribes
- Creates market-driven governance incentives

## 🏗️ Infrastructure Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cypher Protocol Infrastructure                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │  VotingEscrow   │    │     Election    │    │ Distribution │ │
│  │   (veNFT)       │◄──►│   (Governance)  │◄──►│    Module    │ │
│  │                 │    │                 │    │              │ │
│  │ • Token Locking │    │ • Candidate     │    │ • Automated  │ │
│  │ • Power Decay   │    │   Voting        │    │   Emissions   │ │
│  │ • veNFT Minting │    │ • Bribe System  │    │ • 20-Year    │ │
│  │ • Merge Support │    │ • Period Sync   │    │   Schedule   │ │
│  └─────────────────┘    └─────────────────┘    └──────────────┘ │
│         │                       │                       │       │
│         │                       │                       │       │
│         ▼                       ▼                       ▼       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │RewardDistributor│    │   Usage Oracle   │    │   Gnosis     │ │
│  │                 │    │                 │    │     Safe     │ │
│  │ • Merkle Proofs │    │ • Conflict       │    │              │ │
│  │ • Merit Rewards │    │   Prevention     │    │ • Treasury    │ │
│  │ • Batch Claims  │    │ • Usage Tracking │    │   Management │ │
│  │ • Fair Dist.    │    │ • System         │    │ • Multi-sig  │ │
│  │                 │    │   Protection     │    │   Control    │ │
│  └─────────────────┘    └─────────────────┘    └──────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Key Infrastructure Components

#### 1. **Base Network Foundation**

- **Layer 2 Solution**: Built on Base for scalability and cost efficiency
- **Ethereum Security**: Inherits security from Ethereum mainnet
- **Low Fees**: Affordable transaction costs for all users
- **High Throughput**: Supports high-frequency governance activities

#### 2. **Gnosis Safe Integration**

- **Treasury Management**: Secure multi-signature wallet for protocol funds
- **Module System**: DistributionModule operates as Safe module
- **Governance Control**: Multi-signature approval for critical operations
- **Asset Protection**: Battle-tested security for protocol treasury

#### 3. **OpenZeppelin Standards**

- **ERC721**: Standard NFT implementation for veNFTs
- **ERC20**: Standard token implementation for CYPR
- **Security Libraries**: ReentrancyGuard, Ownable, SafeMath
- **Battle-tested Code**: Proven security patterns and implementations

#### 4. **Merkle Tree Distribution**

- **Efficient Claims**: Cryptographic proofs for reward distribution
- **Gas Optimization**: Batch claiming reduces transaction costs
- **Fair Distribution**: Prevents double-claiming and ensures fairness
- **Scalable**: Supports large numbers of recipients

## 🔧 Contract Deep Dive

### 1. VotingEscrow Contract

**Purpose**: Manages token locking and voting power calculation

**Key Features**:

- **Lock Management**: Create, extend, and manage token locks
- **Power Calculation**: Real-time voting power computation with decay
- **veNFT Minting**: ERC721 NFTs representing locked positions
- **Merge Functionality**: Combine multiple positions for efficiency
- **Usage Oracle**: Integration with Election for conflict prevention

**Technical Implementation**:

```solidity
struct LockedBalance {
    int128 amount;        // Locked token amount
    uint256 end;          // Unlock timestamp
    bool isIndefinite;    // Permanent lock flag
}

struct Point {
    int128 bias;          // Effective voting weight
    int128 slope;         // Decay rate per second
    uint256 ts;           // Checkpoint timestamp
    uint256 indefinite;   // Indefinite lock amount
}
```

**Critical Functions**:

- `createLock()`: Lock tokens and mint veNFT
- `depositFor()`: Add tokens to existing position
- `increaseUnlockTime()`: Extend lock duration
- `merge()`: Combine multiple positions
- `lockIndefinite()`: Create permanent lock
- `balanceOfAt()`: Calculate voting power at specific time

**Security Measures**:

- ReentrancyGuard protection
- Input validation and bounds checking
- Usage oracle integration prevents conflicts
- Checkpoint system for efficient calculations

### 2. Election Contract

**Purpose**: Manages merchant voting and cashback reward distribution for Cypher card users

**Real-World Use Case**:

- **Cypher Card Users**: Vote for merchants they want to receive higher cashback from
- **Merchants**: Participate as candidates to attract more users and increase business
- **Cashback Optimization**: Users strategically vote to maximize their token rewards
- **Merchant Competition**: Merchants compete for votes to attract more card users

**Key Features**:

- **Merchant Candidates**: Merchants register as voting candidates
- **Weighted Voting**: Card users vote for multiple merchants with different weights
- **Cashback Bribes**: Merchants offer additional rewards to incentivize votes
- **Period Synchronization**: 2-week voting periods aligned with VotingEscrow
- **Vote Persistence**: Automated vote refresh mechanism

**How It Works for Card Users**:

1. **Strategic Voting**: Users vote for merchants where they spend most
2. **Token Rewards**: Users receive token emissions based on their voting power
3. **Merchant Competition**: Merchants offer bribes (additional cashback) to attract votes
4. **Reward Claiming**: Users claim both token rewards and merchant bribes

**How It Works for Merchants**:

1. **Candidate Registration**: Merchants register to participate in elections
2. **Vote Competition**: Merchants compete for votes to attract more card users
3. **Bribe Offering**: Merchants offer additional rewards to incentivize voting
4. **Business Growth**: More votes = more visibility = more card users = increased business

**Technical Implementation**:

```solidity
// Voting period calculation
function _votingPeriodStart(uint256 timestamp) private view returns (uint256) {
    return INITIAL_PERIOD_START + ((timestamp - INITIAL_PERIOD_START) / VOTE_PERIOD) * VOTE_PERIOD;
}

// Vote execution with weight distribution
function vote(uint256 tokenId, bytes32[] calldata candidates, uint256[] calldata weights) external {
    uint256 power = ve.balanceOfAt(tokenId, block.timestamp);
    uint256 totalWeight = sum(weights);

    for (uint256 i = 0; i < candidates.length; i++) {
        uint256 votesToAdd = power * weights[i] / totalWeight;
        _doVote(tokenId, votesToAdd, candidates[i], periodStart);
    }
}

// Merchant bribe offering
function addBribe(address bribeToken, uint256 amount, bytes32 candidate) external {
    // Merchants can offer additional rewards (cashback tokens) to attract votes
    require(isBribeToken[bribeToken], "Invalid bribe token");
    require(isCandidate[candidate], "Invalid merchant candidate");

    uint256 periodStart = _votingPeriodStart(block.timestamp);
    amountOfBribeTokenForCandidateInPeriod[bribeToken][candidate][periodStart] += amount;

    IERC20(bribeToken).safeTransferFrom(msg.sender, address(this), amount);
    emit BribeAdded(bribeToken, candidate, periodStart, amount);
}

// Cashback claim for card users
function claimBribes(uint256 tokenId, address[] calldata bribeTokens, bytes32[] calldata candidates, uint256 from, uint256 until) external {
    // Card users claim cashback rewards from merchants they voted for
    require(ve.isAuthorizedToVoteFor(msg.sender, tokenId), "Not authorized to claim");

    uint256 firstPeriod = _votingPeriodStart(from);
    uint256 lastPeriod = _votingPeriodStart(until);

    for (uint256 period = firstPeriod; period <= lastPeriod; period += VOTE_PERIOD) {
        for (uint256 i = 0; i < bribeTokens.length; i++) {
            address bribeToken = bribeTokens[i];
            for (uint256 j = 0; j < candidates.length; j++) {
                bytes32 candidate = candidates[j];

                uint256 totalBribeAmount = amountOfBribeTokenForCandidateInPeriod[bribeToken][candidate][period];
                uint256 totalVotes = votesForCandidateInPeriod[candidate][period];
                uint256 tokenVotes = votesByTokenForCandidateInPeriod[tokenId][candidate][period];

                if (totalBribeAmount > 0 && totalVotes > 0 && tokenVotes > 0) {
                    uint256 amount = totalBribeAmount * tokenVotes / totalVotes;
                    if (amount > 0 && !_isBribeClaimed(tokenId, bribeToken, candidate, period)) {
                        _recordBribeClaimed(tokenId, bribeToken, candidate, period);
                        IERC20(bribeToken).safeTransfer(msg.sender, amount);
                        emit BribeClaimed(tokenId, bribeToken, candidate, period, amount);
                    }
                }
            }
        }
    }
}
```

**Critical Functions**:

- `vote()`: Cast weighted votes for merchant candidates
- `addBribe()`: Merchants offer cashback bribes for votes
- `claimBribes()`: Card users claim earned cashback rewards
- `refreshVotesFor()`: Automated vote refresh for convenience
- `enableCandidate()`: Add new merchant candidates

**Security Measures**:

- Period synchronization prevents manipulation
- Usage oracle integration prevents conflicts
- Bitfield tracking for efficient bribe claims
- Input validation and authorization checks

### 3. DistributionModule Contract

**Purpose**: Manages automated token emissions according to predefined schedule, directing tokens to card users

**Real-World Use Case**:

- **Weekly Emissions**: Tokens are automatically distributed every week
- **User Distribution**: Emissions are sent to RewardDistributor, which distributes to card users based on merit
- **Token Rewards**: Card users receive tokens for their participation and voting
- **Sustainable Economics**: Decreasing emission schedule creates scarcity and value over time

**Key Features**:

- **Multi-phase Schedule**: 20-year emission schedule with decreasing rates
- **Week Alignment**: All emissions aligned to week boundaries
- **Safe Integration**: Uses Gnosis Safe for secure token transfers
- **Governance Control**: Owner can update emission parameters
- **User Flow**: Emissions flow to RewardDistributor for user allocation

**Emission Schedule**:

```solidity
// Phase 1: 0-3 months (13 weeks) - 5M tokens/week
_startTime = _pushEmissionSchedule(5, 13, _startTime);

// Phase 2: 3-6 months (13 weeks) - 10M tokens/week
_startTime = _pushEmissionSchedule(10, 13, _startTime);

// Phase 3: 6-9 months (13 weeks) - 15M tokens/week
_startTime = _pushEmissionSchedule(15, 13, _startTime);

// Phase 4: 9 months-2 years (65 weeks) - 100M tokens/week
_startTime = _pushEmissionSchedule(100, 65, _startTime);

// Years 2-4: 80M tokens/week (104 weeks)
_startTime = _pushEmissionSchedule(80, 104, _startTime);

// Years 4-6: 40M tokens/week (104 weeks)
_startTime = _pushEmissionSchedule(40, 104, _startTime);

// Years 6-10: 40M tokens/week (208 weeks)
_startTime = _pushEmissionSchedule(40, 208, _startTime);

// Years 10-14: 30M tokens/week (208 weeks)
_startTime = _pushEmissionSchedule(30, 208, _startTime);

// Years 14-20: 30M tokens/week (312 weeks)
_startTime = _pushEmissionSchedule(30, 312, _startTime);
```

**Critical Functions**:

- `emitTokens()`: Execute token emissions
- `getPendingEmission()`: Calculate pending emission amount
- `updateEmissionAddress()`: Update emission destination
- `getEmissionSchedules()`: Retrieve emission schedule data

**Security Measures**:

- Safe module integration for secure transfers
- Input validation and bounds checking
- Owner-only critical functions
- Predictable and transparent emission schedule

### 4. RewardDistributor Contract

**Purpose**: Distributes merit-based rewards to card users using Merkle proofs

**Real-World Use Case**:

- **User Rewards**: Card users receive tokens based on their participation and merit
- **Voting Rewards**: Users earn tokens for participating in governance
- **Merit Distribution**: Additional tokens distributed to contributors and active participants
- **Efficient Claims**: Users can claim rewards efficiently

**Key Features**:

- **Merkle Tree Distribution**: Efficient distribution of rewards
- **Batch Claims**: Claim multiple rewards in single transaction
- **Double Hashing**: Mitigates second preimage attacks
- **Governance Control**: Owner manages reward roots
- **User Integration**: Distributes tokens to card users for participation rewards

**Technical Implementation**:

```solidity
// Merkle proof verification with double hashing
function _hashLeaf(address claimant, uint256 value) internal pure returns (bytes32) {
    return keccak256(bytes.concat(keccak256(abi.encode(claimant, value))));
}

function _claim(bytes32[] calldata proof, uint256 rootId, uint256 value) internal {
    bytes32 root = idToRoot[rootId];

    // Verify Merkle proof
    if (!MerkleProof.verifyCalldata(proof, root, _hashLeaf(msg.sender, value))) {
        revert InvalidProof(rootId);
    }

    // Mark as claimed and transfer tokens
    claimed[rootId][msg.sender] = true;
    cypher.transfer(msg.sender, value);
}
```

**Critical Functions**:

- `addRoot()`: Add new reward distribution root
- `claim()`: Claim single reward using Merkle proof
- `claimMultiple()`: Claim multiple rewards in batch
- `claimed()`: Check if reward already claimed

**Security Measures**:

- Merkle proof verification
- Double hashing for security
- Claim tracking prevents double-claiming
- Owner-only root management

### 5. CypherToken Contract

**Purpose**: The native token of the Cypher ecosystem

**Key Features**:

- **ERC20 Standard**: Full ERC20 compliance
- **ERC20Permit**: Gasless approvals via signatures
- **Initial Supply**: 1 billion tokens minted to treasury
- **Governance Ready**: Designed for voting and governance

**Technical Implementation**:

```solidity
contract CypherToken is ICypherToken, ERC20Permit {
    constructor(address treasury) ERC20("Cypher", "CYPR") ERC20Permit("Cypher") {
        // Mint 1 billion tokens to treasury
        _mint(treasury, 1_000_000_000 * 1e18);
    }
}
```

**Token Economics**:

- **Symbol**: CYPR
- **Name**: Cypher
- **Decimals**: 18
- **Total Supply**: 1,000,000,000 CYPR
- **Initial Distribution**: All tokens minted to treasury
- **Governance Token**: Used for voting and protocol decisions

## 💎 CYPR Token Significance

### Economic Foundation

The CYPR token serves as the economic foundation of the entire Cypher ecosystem:

**1. Governance Token**

- Voting power is derived from locked CYPR tokens
- Token holders participate in protocol governance
- Long-term holders have more influence
- Aligns incentives between users and protocol

**2. Utility Token**

- Required for participating in governance
- Used for voting on protocol changes
- Earned through participation and merit
- Can be locked to earn additional rewards

**3. Value Accrual**

- Token value increases with protocol adoption
- Governance decisions affect token utility
- Emission schedule creates scarcity over time
- Merit-based distribution rewards contributors

### Token Distribution Strategy

**Initial Distribution**:

- 1 billion CYPR tokens minted to treasury
- No pre-sale or private allocation
- Fair launch approach
- Treasury controlled by governance

**Emission Schedule**:

- 20-year decreasing emission schedule
- Rewards long-term participants
- Creates sustainable incentives
- Prevents token inflation

**Merit-Based Distribution**:

- Rewards distributed based on contributions
- Encourages active participation
- Fair distribution mechanism
- Prevents whale dominance

### Long-term Value Proposition

**Scarcity Creation**:

- Decreasing emission rates over time
- Fixed total supply after 20 years
- Demand increases with protocol adoption
- Deflationary pressure from usage

**Utility Growth**:

- More use cases as protocol evolves
- Integration with other DeFi protocols
- Governance becomes more valuable
- Network effects increase utility

**Governance Rights**:

- Control over protocol parameters
- Decision-making power
- Influence over ecosystem direction
- Long-term value alignment

## 🛡️ DeFi Principles Implementation

### 1. Decentralization

**How Cypher Ensures Decentralization**:

- **No Single Point of Control**: Governance distributed across token holders
- **Multi-signature Governance**: Critical functions require multiple approvals
- **Open Source**: All code is publicly available and auditable
- **Permissionless**: Anyone can participate without approval
- **Transparent**: All transactions and decisions are publicly verifiable

**Technical Implementation**:

- Gnosis Safe multi-signature wallets
- Decentralized governance mechanisms
- Open source smart contracts
- Public transaction history

### 2. Transparency

**How Cypher Ensures Transparency**:

- **Public Code**: All smart contracts are open source
- **Auditable**: Regular security audits and reviews
- **Transparent Governance**: All votes and decisions are public
- **Open Economics**: Token distribution and emission schedules are public
- **Verifiable**: All operations can be verified on-chain

**Technical Implementation**:

- Public smart contract code
- On-chain governance records
- Transparent token economics
- Public audit reports

### 3. Composability

**How Cypher Enables Composability**:

- **Standard Interfaces**: Uses standard ERC20 and ERC721 interfaces
- **Modular Design**: Components can be used independently
- **Integration Ready**: Easy integration with other DeFi protocols
- **Extensible**: New features can be added through governance
- **Interoperable**: Works with other Base ecosystem protocols

**Technical Implementation**:

- Standard token interfaces
- Modular contract architecture
- Integration-friendly design
- Governance-controlled upgrades

### 4. Security

**How Cypher Ensures Security**:

- **Battle-tested Code**: Uses proven OpenZeppelin libraries
- **Security Audits**: Regular professional security audits
- **Reentrancy Protection**: All critical functions protected
- **Input Validation**: Comprehensive parameter validation
- **Safe Integration**: Uses Gnosis Safe for treasury management

**Technical Implementation**:

- OpenZeppelin security libraries
- ReentrancyGuard protection
- Comprehensive input validation
- Safe module integration

### 5. Sustainability

**How Cypher Ensures Sustainability**:

- **Long-term Incentives**: 20-year emission schedule
- **Sustainable Economics**: Decreasing emission rates
- **Merit-based Rewards**: Rewards contributors fairly
- **Governance Evolution**: Protocol can adapt over time
- **Community Ownership**: Governance distributed to community

**Technical Implementation**:

- Long-term emission schedule
- Merit-based distribution
- Governance-controlled parameters
- Community-driven development

## 🔄 How It Works

### Cypher Card User Journey

Here's how Cypher card users interact with the protocol to maximize cashback rewards:

1. **Lock Tokens**: Card user locks CYPR tokens for a specific duration
2. **Earn Voting Power**: User receives voting power proportional to lock amount and duration
3. **Vote for Merchants**: User votes for merchants where they spend most
4. **Earn Rewards**: User earns both token rewards and merchant bribes (additional cashback)
5. **Claim Rewards**: User claims all earned rewards

### Merchant Journey

Here's how merchants participate in the ecosystem:

1. **Register as Candidate**: Merchant registers to participate in elections
2. **Compete for Votes**: Merchant competes with other merchants for votes
3. **Offer Bribes**: Merchant offers additional cashback rewards to attract votes
4. **Attract Users**: More votes = more visibility = more card users = increased business
5. **Business Growth**: Increased card user traffic leads to higher revenue

### Complete System Flow

```
Cypher Card User → Merchant → Token Flow
├─ Lock CYPR → VotingEscrow → Receive veNFT + Voting Power
├─ Vote for Merchants → Election → Influence Merchant Visibility
├─ Auto Emission → DistributionModule → Tokens to RewardDistributor
├─ User Receives Tokens → RewardDistributor → Merit-based Rewards
└─ User Claims Rewards → Election + RewardDistributor → Receive Tokens + Bribes
```

### Cashback Optimization Strategy

**For Card Users**:

- Vote for merchants where you spend the most
- Higher votes = more visibility for merchants = better cashback rates
- Claim both token rewards and merchant bribes
- Strategically allocate voting power across multiple merchants

**For Merchants**:

- Offer competitive bribes to attract votes
- More votes = more visibility = more card users = increased business
- Compete with other merchants for user attention
- Use increased traffic to enhance cashback programs

### Key Interactions

- **VotingEscrow ↔ Election**: Election checks voting power and prevents conflicts
- **DistributionModule ↔ Safe**: Secure token transfers from treasury
- **DistributionModule → RewardDistributor**: Automatic token distribution to users
- **Election → Merchants**: Vote-based visibility and user attraction
- **Governance Controls**: All major functions controlled by governance multisig

## 🚀 Getting Started

### For Users

**1. Acquire CYPR Tokens**

- Purchase from decentralized exchanges
- Earn through participation rewards
- Receive from merit-based distributions

**2. Lock Tokens**

- Connect wallet to Cypher Protocol
- Choose lock duration (2 weeks to 2 years)
- Lock CYPR tokens to earn voting power

**3. Participate in Governance**

- Vote for candidates in elections
- Earn bribes for voting
- Claim merit-based rewards

**4. Manage Position**

- Add more tokens to existing lock
- Extend lock duration
- Merge multiple positions
- Claim rewards

### For Developers

**1. Understand the System**

- Read through this documentation
- Study the smart contract code
- Understand the governance mechanisms

**2. Set Up Development Environment**

- Install Foundry framework
- Clone the repository
- Set up development environment

**3. Deploy Contracts**

- Follow deployment instructions
- Configure addresses and parameters
- Deploy to Base network

**4. Integrate with Applications**

- Use standard interfaces
- Implement voting mechanisms
- Integrate reward distribution

### For Governance Participants

**1. Understand Governance**

- Learn about voting mechanisms
- Understand bribe system
- Study governance parameters

**2. Participate Actively**

- Vote in elections
- Propose changes
- Monitor protocol health

**3. Contribute to Ecosystem**

- Build applications
- Provide liquidity
- Contribute to development

## 📚 Resources

### Deployed Contracts

All Cypher Protocol contracts are deployed on Base mainnet:

| Contract               | Address                                      | Basescan                                                                        |
| ---------------------- | -------------------------------------------- | ------------------------------------------------------------------------------- |
| **CYPR Token**         | `0xD262A4c7108C8139b2B189758e8D17c3DFC91a38` | [View](https://basescan.org/address/0xD262A4c7108C8139b2B189758e8D17c3DFC91a38) |
| **VotingEscrow**       | `0x34Eba627690d3Db91353b4948270BF7b62a865A8` | [View](https://basescan.org/address/0x34Eba627690d3Db91353b4948270BF7b62a865A8) |
| **Election**           | `0x6a70dbBf029B00F177D697Bc549386A3b163c80F` | [View](https://basescan.org/address/0x6a70dbBf029B00F177D697Bc549386A3b163c80F) |
| **RewardDistributor**  | `0x3aDCB5664d9ABB0bD7991Bcd295E095a95295BE5` | [View](https://basescan.org/address/0x3aDCB5664d9ABB0bD7991Bcd295E095a95295BE5) |
| **DistributionModule** | `0xE60Db760a38c323C898851fFAAE03c4C7B985cE7` | [View](https://basescan.org/address/0xE60Db760a38c323C898851fFAAE03c4C7B985cE7) |

### Documentation

- **Main Repository**: [CypherProtocol](https://github.com/CypherD-IO/CypherProtocol)
- **Deployment Guide**: See `DEPLOYMENT.md` for detailed deployment instructions
- **API Documentation**: Smart contract interfaces and functions

### External Resources

- **Base Network**: [Base Documentation](https://docs.base.org)
- **Gnosis Safe**: [Safe Documentation](https://docs.safe.global)
- **OpenZeppelin**: [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- **Foundry**: [Foundry Documentation](https://book.getfoundry.sh)

### Community

- **Discord**: Join our Discord community for discussions
- **Twitter**: Follow us on Twitter for updates
- **Telegram**: Join our Telegram group for announcements
- **GitHub**: Contribute to the open source development

### Educational Resources

- **DeFi Fundamentals**: Learn about decentralized finance
- **Governance Mechanisms**: Understand token-based governance
- **Smart Contract Security**: Learn about security best practices
- **Base Ecosystem**: Explore Base network capabilities

## 📄 License

This project is licensed under the **BUSL-1.1 License** - see the [LICENSE](../LICENSE) file for details.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](../CONTRIBUTING.md) for details.

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

## ✨ Acknowledgments

- **Curve Finance**: Inspiration for ve(3,3) mechanics
- **Gnosis Safe**: Treasury management infrastructure
- **Base**: Scalable L2 infrastructure
- **OpenZeppelin**: Security libraries and contracts

---

**Built with ❤️ by the Cypher team**

> **Disclaimer**: This software is provided "as is" without warranty. Use at your own risk. The Cypher Protocol team is not responsible for any financial losses incurred through the use of this software.
