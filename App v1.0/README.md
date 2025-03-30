# ZetaChain Curve-like Pool

A Curve-like stablecoin pool implementation for ZetaChain, enabling cross-chain stablecoin swaps with minimal slippage.

## Overview

This project implements a Curve-like stablecoin pool on ZetaChain, allowing for efficient swapping of stablecoins from different chains. The implementation includes:

1. A `StablecoinPool` contract that implements the Curve stableswap algorithm
2. A `PoolFactory` contract for creating new pools
3. ZetaChain integration for cross-chain functionality

## Features

- Efficient stablecoin swaps with minimal slippage
- Support for ZRC20 tokens (ZetaChain's cross-chain token standard)
- Cross-chain liquidity provision and swaps
- Factory pattern for easy pool creation

## Testing on ZetaChain Athens Testnet

We've successfully tested the following functionality on the ZetaChain Athens testnet:

### 1. ZRC20 Pool Creation and Testing

- Created a pool with ZRC20 tokens (USDC from Sepolia and BSC)
- Pool address: `0xCC1a110e6595899e56273ba440c85F3e49c494a1`

### 2. Mock Token Testing

Since we don't have actual ZRC20 tokens for testing, we created mock tokens to simulate the behavior:

- Created mock tokens to represent ZRC20 tokens:
  - Mock USDC Sepolia: `0x34732807A7FE22f336e8e39227e15e7FD6a78f44`
  - Mock USDC BSC: `0x63952976B47916b60bFFB975b1129dA5D06b4b64`
- Created a pool with these mock tokens: `0xC4F0CA2882BB1D589946a3C0ed7C3E482410126f`
- Added liquidity to the pool (100 tokens of each)
- Swapped tokens in the pool (10 Mock USDC Sepolia for ~9.995 Mock USDC BSC)
- Verified pool information and balances

## ZetaChain Integration

The contracts have been enhanced to leverage ZetaChain's cross-chain capabilities:

- Integration with ZRC20 tokens for cross-chain asset representation
- Use of ZetaChain's connector for cross-chain messaging
- Support for creating pools with tokens from different chains
- Cross-chain swaps through ZetaChain's messaging system

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
   ZETA_CONNECTOR_ADDRESS=0x239e96c8f17C85c30100AC26F635Ea15f23E9c67
   ```

### Available Scripts

The project includes the following scripts for interacting with the ZetaChain testnet:

#### Deployment
```
npx hardhat run scripts/deploy-zeta-testnet.ts --network zetachain-testnet
```

#### Working with ZRC20 Tokens
```
# Create a pool with ZRC20 tokens
npx hardhat run scripts/create-zrc20-pool.ts --network zetachain-testnet

# Add liquidity to a ZRC20 pool
npx hardhat run scripts/add-zrc20-liquidity.ts --network zetachain-testnet

# Perform cross-chain swaps
npx hardhat run scripts/cross-chain-swap.ts --network zetachain-testnet
```

#### Working with Mock Tokens (for testing)
```
# Mint mock ZRC20 tokens
npx hardhat run scripts/mint-mock-zrc20.ts --network zetachain-testnet

# Create a pool with mock tokens
npx hardhat run scripts/create-mock-pool.ts --network zetachain-testnet

# Add liquidity to a mock pool
npx hardhat run scripts/add-mock-liquidity.ts --network zetachain-testnet

# Swap tokens in a mock pool
npx hardhat run scripts/swap-mock-tokens.ts --network zetachain-testnet
```

#### Utility Scripts
```
# Check token balances
npx hardhat run scripts/check-balances.ts --network zetachain-testnet

# Check pool information
npx hardhat run scripts/check-pool-info.ts --network zetachain-testnet
```

## License

MIT
