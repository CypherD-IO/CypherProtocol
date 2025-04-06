# Template Scripts Guide

This guide explains how to use the Enable and Disable template scripts for managing candidates and tokens in the Election contract.

## Overview

- **EnableTemplate**: Enables candidates and tokens for voting in the Election contract
- **DisableTemplate**: Disables candidates and tokens in the Election contract

## Usage

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ENABLE_PATH` | Path to JSON file for enabling candidates/tokens | `test/mocks/enable.json` |
| `DISABLE_PATH` | Path to JSON file for disabling candidates/tokens | `test/mocks/disable.json` |

### JSON File Format

Both scripts use JSON files with the same structure:

```json
{
    "candidates": [
        "0xa210df63555e6bcab6f13f8827ac79db7a7a7dd84114b8f8c57a8f1e64619902",
        "0x162a4db4c0bea372fab4a5f9d819edcc74e98a86da3e1b0395a0e9f9b804e05a"
    ],
    "tokens": ["CYPHER_TOKEN"]
}
```

- `candidates`: Array of bytes32 candidate identifiers
- `tokens`: Array of token names (must match names in the Addresses contract)

## Running the Scripts

### Enable Template

```bash
# Set the path to your JSON file
export ENABLE_PATH=path/to/enable.json

# Run the script
forge script script/EnableTemplate.s.sol --fork-url <RPC_URL>
```

### Disable Template

```bash
# Set the path to your JSON file
export DISABLE_PATH=path/to/disable.json

# Run the script
forge script script/DisableTemplate.s.sol --fork-url <RPC_URL>
```

## Testing

Run integration tests with:

```bash
forge test --match-path test/integration/Template.t.sol -vvv --fork-url base
```

This will test both enabling and disabling functionality against a live system.
