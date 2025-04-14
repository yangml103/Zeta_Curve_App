# FluidUSDC Axelar

A cross-chain USDC solution built using Axelar Network's secure cross-chain communication protocol. This application allows users to transfer USDC between multiple supported chains including Ethereum, Polygon, Avalanche, and more.

## Features

- Cross-chain balances display for USDC across multiple networks
- Secure cross-chain transfers of USDC between different blockchains
- Real-time balance updates on the current connected chain
- User-friendly interface with network switching capabilities
- Gas fee estimation and payment for faster cross-chain transfers
- Liquidity pooling with share token representation

## Project Structure

- `/src` - Frontend React application
- `/contracts` - Smart contracts for cross-chain USDC transfers and pooling
- `/public` - Static assets

## Smart Contracts

The project includes three main smart contracts:

1. **AxelarUSDCSender.sol** - Facilitates sending USDC from one chain to another
2. **AxelarUSDCReceiver.sol** - Receives USDC sent from other chains
3. **AxelarUSDCPool.sol** - Provides cross-chain liquidity pooling with share tokens (FluidUSDC)

For detailed information about the smart contracts, see the [Contracts README](./contracts/README.md).

## Supported Chains

- Ethereum
- Polygon
- Avalanche
- Arbitrum
- Optimism
- Base
- Fantom
- Moonbeam

## Technology Stack

- React.js for the frontend
- Ethers.js for Ethereum blockchain interaction
- Axelar Network SDK for cross-chain communication
- Tailwind CSS for styling
- Solidity for smart contracts

## Getting Started

### Prerequisites

- Node.js 16+ installed
- MetaMask or another Ethereum wallet browser extension

### Installation

1. Clone the repository
   ```
   git clone <repository-url>
   cd Axelar
   ```

2. Install dependencies
   ```
   npm install
   ```

3. Start the development server
   ```
   npm start
   ```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

## Contract Deployment

To deploy the smart contracts:

1. Navigate to the contracts directory
   ```
   cd contracts
   ```

2. Install contract dependencies
   ```
   npm install @axelar-network/axelar-gmp-sdk-solidity @openzeppelin/contracts
   ```

3. Set your private key as an environment variable
   ```
   export PRIVATE_KEY=your_private_key_here
   ```

4. Run the deployment script for specific networks
   ```
   node deploy.js ethereum
   node deploy.js polygon
   node deploy.js avalanche
   ```

## Usage

1. Connect your wallet using the "Connect Wallet" button
2. View your USDC balances across different chains
3. To transfer USDC cross-chain:
   - Select the destination chain
   - Enter the amount to transfer
   - Enter the recipient address
   - Choose whether to include gas payment
   - Click "Transfer USDC"

## Security Notes

This application is experimental and should be used with caution. Always verify transactions before confirming them in your wallet.

## License

MIT 