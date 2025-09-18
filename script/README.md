# EMAD Protocol Deployment Scripts

This directory contains deployment and interaction scripts for the EMAD Protocol.

## Environment Setup

Create a `.env` file in the project root with the following variables:

```bash
# Required for all deployments
PRIVATE_KEY=0x...                    # Deployer private key
TREASURY_ADDRESS=0x...               # Treasury address for fees

# Optional - will be set during deployment
EMAD_ADDRESS=0x...                  # EMAD token contract address
VAULT_ADDRESS=0x...                 # EMADVault contract address  
MINTER_ADDRESS=0x...                # EMADMinter contract address
ORACLE_ADDRESS=0x...                # Oracle contract address

# Network configuration
RPC_URL=https://...                 # RPC endpoint
```

## Scripts Overview

### Individual Deployment Scripts

1. **01_DeployEMAD.s.sol** - Deploy only the EMAD token
2. **02_DeployVault.s.sol** - Deploy only the EMADVault (requires EMAD_ADDRESS)
3. **03_DeployMinter.s.sol** - Deploy only the EMADMinter (requires EMAD_ADDRESS, VAULT_ADDRESS)

### Complete Deployment Scripts

4. **Deploy.s.sol** - **RECOMMENDED** - Complete deployment with detailed logging
5. **04_DeployAll.s.sol** - Alternative complete deployment script

### Utility Scripts

6. **Upgrade.s.sol** - Upgrade existing contracts
7. **TestInteractions.s.sol** - Test contract interactions after deployment

## Usage Examples

### Complete Deployment (Recommended)

```bash
# Deploy everything in one go
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Or use the alternative script
forge script script/04_DeployAll.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Step-by-Step Deployment

```bash
# 1. Deploy EMAD token
forge script script/01_DeployEMAD.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 2. Update .env with EMAD_ADDRESS, then deploy vault
forge script script/02_DeployVault.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 3. Update .env with VAULT_ADDRESS, then deploy minter
forge script script/03_DeployMinter.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Upgrades

```bash
# Upgrade minter contract
forge script script/Upgrade.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Update oracle price only
forge script script/Upgrade.s.sol --sig "upgradeOraclePrice()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Testing Interactions

```bash
# Test minting after deployment
forge script script/TestInteractions.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Local Development

For local testing with Anvil:

```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

## Script Features

- **Detailed logging** with clear deployment progress
- **Environment variable integration** for easy configuration management
- **Return values** for programmatic usage
- **Gas optimization** with efficient deployment order
- **Error handling** with meaningful error messages
- **Modular design** for flexible deployment strategies

## Security Notes

- Always verify contract addresses after deployment
- Test on testnets before mainnet deployment
- Keep private keys secure and never commit them
- Verify environment variables before running scripts
- Double-check gas prices for mainnet deployments

## Post-Deployment

After successful deployment:

1. Update your `.env` file with the deployed contract addresses
2. Verify contracts on Etherscan/block explorer
3. Set up any necessary access controls or governance
4. Test all contract interactions
5. Document the deployment for your team