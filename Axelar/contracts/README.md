# Axelar USDC Cross-Chain Contracts

This folder contains smart contracts that enable cross-chain USDC transfers and pooling using Axelar Network's secure cross-chain communication protocol.

## Contract Overview

### AxelarUSDCSender.sol
A contract that enables sending USDC from one chain to another via Axelar's Gateway.

- **Key functions**:
  - `sendUSDC`: Send USDC to another chain
  - `setFeePercentage`: Set the fee for transfers (admin only)
  - `withdrawFees`: Withdraw collected fees (admin only)

### AxelarUSDCReceiver.sol
A contract that receives USDC sent from other chains via Axelar.

- **Key functions**:
  - `executeWithToken`: Called by Axelar Gateway when tokens are received
  - `sendUSDC`: Send USDC back to another chain
  - `setTrustedSourceChain`: Set which chains are trusted
  - `setTrustedSender`: Set trusted sender addresses on source chains

### AxelarUSDCPool.sol
A liquidity pool contract that facilitates cross-chain USDC transfers and provides liquidity shares.

- **Key functions**:
  - `deposit`: Add USDC to the pool and receive FluidUSDC tokens
  - `withdraw`: Redeem FluidUSDC tokens for USDC
  - `withdrawToChain`: Redeem FluidUSDC tokens and send USDC to another chain
  - `executeWithToken`: Handle incoming cross-chain deposits

## Deployment

To deploy these contracts, you'll need to:

1. Deploy contracts on each chain where you want to support cross-chain transfers
2. Configure the contracts to trust each other
3. Initialize contracts with proper Axelar Gateway addresses

### Required Dependencies

```
npm install @axelar-network/axelar-gmp-sdk-solidity @openzeppelin/contracts
```

### Deployment Addresses

The contracts should be deployed with the following parameters:

- **Axelar Gateway** addresses:
  - Ethereum: `0x4F4495243837681061C4743b74B3eEdf548D56A5`
  - Polygon: `0x6f015F16De9fC8791b234eF68D486d2bF203FBA8`
  - Avalanche: `0x5029C0EFf6C34351a0CEc334542cDb22c7928f78`
  - Arbitrum: `0xe432150cce91c13a887f7D836923d5597adD8E31`
  - Optimism: `0xe432150cce91c13a887f7D836923d5597adD8E31`
  - Base: `0xe432150cce91c13a887f7D836923d5597adD8E31`

- **Axelar Gas Service** address: `0x2d5d7d31F671F86C782533cc367F14109a082712`

- **USDC** addresses:
  - Ethereum: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
  - Polygon: `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`
  - Avalanche: `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E`
  - Arbitrum: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
  - Optimism: `0x7F5c764cBc14f9669B88837ca1490cCa17c31607`
  - Base: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

## Security Considerations

- Ensure proper access control
- Audit contracts before deploying to mainnet
- Test thoroughly on testnet
- Implement proper slippage protection

## After Deployment

After deploying the contracts, make sure to:

1. Set trusted source chains and senders
2. Set appropriate fee levels
3. Verify contracts on Etherscan/block explorers
4. Test transfers with small amounts first 