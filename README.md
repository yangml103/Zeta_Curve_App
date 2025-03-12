# ZetaChain Curve-Like Pool

A Curve-like stablecoin pool implementation on ZetaChain that enables cross-chain stablecoin swaps with low slippage.

## Overview

This project implements a Curve-like stablecoin pool on ZetaChain, allowing users to:

1. Deposit stablecoins from any connected chain and receive a unified representation on ZetaChain
2. Swap between different stablecoins with low slippage using the StableSwap invariant
3. Provide liquidity to the pool and earn fees
4. Withdraw stablecoins to any connected chain

The key advantage of building on ZetaChain is that it natively supports cross-chain assets, eliminating the need for complex bridging solutions.

## Architecture

The project consists of three main contracts:

1. **UnifiedStablecoin**: An ERC20 token that represents the unified stablecoin on ZetaChain. Users can deposit stablecoins from any connected chain and receive this token.

2. **StablecoinPool**: A Curve-like pool that allows swapping between different stablecoins with low slippage. It uses the StableSwap invariant (x^3*y + y^3*x >= k) for efficient stablecoin swaps.

3. **PoolFactory**: A factory contract for creating new stablecoin pools with different tokens and parameters.

## Getting Started

### Prerequisites

- Node.js v16 or higher
- npm or yarn
- Hardhat

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yangml103/Zeta_Curve_App.git
cd Zeta_Curve_App
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file with your private key and other configuration:
```
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### Deployment

1. Deploy the contracts to ZetaChain testnet:
```bash
npx hardhat run scripts/deploy.ts --network zetachain-testnet
```

2. Create a pool with ZRC20 tokens:
```bash
# First, add the factory address and ZRC20 token addresses to your .env file
FACTORY_ADDRESS=deployed_factory_address
ZRC20_USDC_ETH=zrc20_usdc_eth_address
ZRC20_USDC_BSC=zrc20_usdc_bsc_address

# Then run the create-pool script
npx hardhat run scripts/create-pool.ts --network zetachain-testnet
```

## Usage

### Depositing Stablecoins

Users can deposit stablecoins from any connected chain to ZetaChain. The process is as follows:

1. User initiates a transaction on the source chain (e.g., Ethereum) to send USDC to ZetaChain
2. ZetaChain receives the USDC and mints the equivalent amount of UnifiedStablecoin to the user
3. The user now has UnifiedStablecoin on ZetaChain that can be used in the stablecoin pool

### Swapping Stablecoins

Users can swap between different stablecoins in the pool with low slippage:

1. User approves the pool contract to spend their stablecoins
2. User calls the `swap` function with the input token, output token, and amount
3. The pool calculates the output amount based on the StableSwap invariant
4. The user receives the output stablecoins

### Providing Liquidity

Users can provide liquidity to the pool and earn fees:

1. User approves the pool contract to spend their stablecoins
2. User calls the `addLiquidity` function with the amounts of each token
3. The pool mints LP tokens to the user representing their share of the pool

### Withdrawing Stablecoins

Users can withdraw their stablecoins to any connected chain:

1. User calls the `withdraw` function on the UnifiedStablecoin contract
2. The contract burns the UnifiedStablecoin and releases the underlying stablecoin to the user
3. The user can then bridge the stablecoin back to their desired chain

## Testing

Run the tests with:

```bash
npx hardhat test
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
