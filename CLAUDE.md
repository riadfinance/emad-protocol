# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the EMAD Protocol - a Foundry-based smart contract project implementing a Digital Dirham (E-MAD) token system with advanced minting, burning, governance, and vault functionality.

## Development Commands

### Build & Compilation
```bash
forge build           # Compile all contracts
forge clean          # Clean build artifacts
```

### Testing
```bash
forge test           # Run all tests
forge test -vvv      # Run tests with detailed output
forge test --match-test <testName>  # Run specific test
forge test --match-contract <contractName>  # Test specific contract
forge coverage       # Generate coverage report
```

### Code Quality
```bash
forge fmt            # Format Solidity code
forge snapshot       # Generate gas snapshots
```

### Deployment
```bash
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
forge script script/Upgrade.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

### Local Development
```bash
anvil                # Start local Ethereum node
cast <subcommand>    # Interact with contracts
```

## Architecture Overview

### Core Contracts

1. **EMAD.sol** - ERC20 token with minting rights management
   - Max supply: 1 billion tokens
   - Controlled minting through designated minter address
   - Pausable minting functionality

2. **EMADMinter.sol** - Advanced minting and burning controller
   - Role-based access control (MINTER_ROLE, BURNER_ROLE, OPERATOR_ROLE, GUARDIAN_ROLE)
   - Rate limiting (daily, hourly, per-transaction)
   - Dynamic fee system
   - Cross-chain minting capabilities
   - Integrates with oracle for price feeds

3. **EMADVault.sol** - Vault for collateral management
   - Manages collateral deposits and withdrawals
   - Debt ceiling enforcement
   - Treasury integration

4. **EMADGovernor.sol** - Governance contract for protocol decisions
   - On-chain governance for protocol parameters
   - Proposal and voting mechanisms

### Supporting Components

- **interfaces/** - Contains IEMAD.sol and IOracle.sol interfaces
- **libraries/** - Helper libraries (Errors.sol, Math.sol, TransferHelper.sol)
- **test/** - Test files including fuzz tests (test/fuzz/)
- **script/** - Deployment and upgrade scripts

## Key Dependencies

- OpenZeppelin Contracts v5.4.0 - Standard implementations for ERC20, AccessControl, etc.
- Forge Standard Library - Testing utilities and helpers

## Environment Variables Required

For deployment scripts:
- `PRIVATE_KEY` - Deployer's private key
- `EMAD_ADDRESS` - Address of deployed EMAD token (for vault deployment)
- `TREASURY_ADDRESS` - Treasury address for fee collection
- `RPC_URL` - Network RPC endpoint

## Testing Approach

The project uses Foundry's testing framework with:
- Unit tests for individual contract functions
- Fuzz testing for property-based testing (in test/fuzz/)
- Integration tests for contract interactions

Run tests with increased verbosity (`-vvv`) to debug issues.