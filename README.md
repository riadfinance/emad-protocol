
# E-MAD Protocol

E-MAD is a Moroccan Dirham-pegged stablecoin protocol built on Ethereum. It enables users to mint E-MAD tokens by depositing collateral, creating a decentralized digital version of the MAD currency for DeFi applications.

## Overview

E-MAD maintains a 1:1 peg with the Moroccan Dirham through overcollateralized positions. Users deposit accepted collateral (USDT, USDC, ETH) to mint E-MAD tokens, which can be used for payments, trading, and yield generation.

## Installation

```bash
git clone https://github.com/riadfinance/emad-protocol
cd emad-protocol
forge install
forge build
```

## Testing

```bash
forge test
forge test --gas-report
forge coverage
```

## Deployment

```bash
# Local deployment
anvil
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Testnet deployment
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Architecture

The protocol consists of four main contracts:

- **EMAD.sol**: ERC20 token implementation with mint/burn functionality
- **EMADVault.sol**: Manages collateral deposits and liquidations
- **EMADMinter.sol**: Controls minting/burning with rate limiting and access control
- **EMADGovernor.sol**: Handles protocol governance and parameter updates

## Configuration

Create a `.env` file with required parameters:

```
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_api_key
```

## License

MIT
