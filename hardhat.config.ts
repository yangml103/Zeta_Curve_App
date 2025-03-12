import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@zetachain/toolkit/hardhat";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";

// Load environment variables from .env file
dotenvConfig({ path: resolve(__dirname, ".env") });

// Get private key from environment variables or use a default one for testing
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    // ZetaChain testnet
    "zetachain-testnet": {
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      accounts: [PRIVATE_KEY],
      chainId: 7001,
    },
    // ZetaChain mainnet
    "zetachain-mainnet": {
      url: "https://zetachain-evm.blockpi.network/v1/rpc/public",
      accounts: [PRIVATE_KEY],
      chainId: 7000,
    },
    // Local development network
    hardhat: {
      // No special configuration needed for local development
    },
  },
  // Etherscan API key for contract verification
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
};

export default config;
