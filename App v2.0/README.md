# ZetaChain Curve-like Pool with Gateway Integration

A Curve-like stablecoin pool implementation for ZetaChain using the Zeta Gateway API, enabling cross-chain stablecoin swaps with minimal slippage.

## Overview

This project implements a Curve-like stablecoin pool on ZetaChain that uses the Zeta Gateway API (instead of the connector) for cross-chain functionality. This approach provides a more direct and efficient way to handle cross-chain operations. The implementation includes:

1. A `ZetaGatewayStablecoinPool` contract that implements the Curve stableswap algorithm
2. An `OmniUSDT` token that represents a share in the pool and can be redeemed for USDT on any chain
3. A `GatewayPoolFactory` contract for creating new pools
4. ZetaChain Gateway integration for cross-chain functionality

## Features

- Efficient stablecoin swaps with minimal slippage using the Curve StableSwap algorithm
- Support for ZRC20 tokens (ZetaChain's cross-chain token standard)
- Cross-chain liquidity provision and swaps through the Zeta Gateway
- Unified liquidity token (OmniUSDT) that can be redeemed on any supported chain
- Factory pattern for easy pool creation

## Key Components

### ZetaGatewayStablecoinPool

This is the main pool contract that implements the Curve StableSwap algorithm. It allows users to:

- Add liquidity to the pool (both single-sided and balanced)
- Remove liquidity from the pool
- Swap tokens within the pool
- Perform cross-chain swaps using the Zeta Gateway

### OmniUSDT

This is a special ERC20 token that represents a share in the pool. It can be:

- Minted when liquidity is added to the pool
- Burned when liquidity is removed from the pool
- Transferred across chains using the Zeta Gateway
- Redeemed for USDT on any supported chain

### GatewayPoolFactory

A factory contract for creating new pools with different tokens and parameters. It:

- Creates new ZetaGatewayStablecoinPool instances
- Configures the pool parameters (amplification, swap fee, admin fee)
- Manages the supported chains

## Getting Started

### Prerequisites

- Node.js (v16+)
- Hardhat
- ZetaChain wallet with testnet ZETA tokens

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/zeta-curve-pool.git
   cd zeta-curve-pool
   ```

2. Install dependencies:
   ```
   npm install
   ```

3. Create a `.env` file with your configuration:
   ```
   PRIVATE_KEY=your_private_key
   ZETA_TOKEN_ADDRESS=0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf
   ```

### Deploying Contracts

To deploy the contracts to the ZetaChain testnet:

```
npx hardhat run scripts/deploy-gateway-testnet.ts --network zetachain-testnet
```

This will deploy the `GatewayPoolFactory` and configure it with supported chains.

### Creating a Pool

To create a pool with ZRC20 tokens:

```
npx hardhat run scripts/create-gateway-pool.ts --network zetachain-testnet
```

This will create a new pool with the specified ZRC20 tokens.

### Adding Liquidity

To add liquidity to an existing pool:

```
npx hardhat run scripts/add-gateway-liquidity.ts --network zetachain-testnet
```

### Performing Cross-Chain Swaps

To perform a cross-chain swap:

```
npx hardhat run scripts/gateway-cross-chain-swap.ts --network zetachain-testnet
```

## Zeta Gateway vs. Connector

This implementation uses the Zeta Gateway API instead of the connector for cross-chain messaging. Key differences:

1. **Direct Integration**: Uses direct ZRC20 token methods for cross-chain operations
2. **Simplified Cross-Chain Logic**: Streamlines the process of sending tokens across chains
3. **Gas Efficiency**: Potentially more gas-efficient for certain operations
4. **Unified Token**: Creates a unified stablecoin (OmniUSDT) that can be used across all chains

## License

MIT