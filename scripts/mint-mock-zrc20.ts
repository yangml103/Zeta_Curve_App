import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Minting mock ZRC20 tokens for testing...");

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Account address: ${signer.address}`);

  // Get ZRC20 token addresses
  const usdcSepoliaAddress = process.env.USDC_SEPOLIA_ADDRESS;
  const usdcBscAddress = process.env.USDC_BSC_ADDRESS;

  if (!usdcSepoliaAddress || !usdcBscAddress) {
    throw new Error("ZRC20 token addresses not set in environment variables");
  }

  // Since we can't directly mint ZRC20 tokens (they're minted when assets are deposited from connected chains),
  // we'll create mock ERC20 tokens that we can use for testing our pool
  console.log("Deploying mock tokens that will represent ZRC20 tokens...");

  // Deploy mock tokens
  const MockToken = await ethers.getContractFactory("MockToken");
  
  const mockUsdcSepolia = await MockToken.deploy("Mock USDC Sepolia", "mUSDCS");
  await mockUsdcSepolia.waitForDeployment();
  const mockUsdcSepoliaAddress = await mockUsdcSepolia.getAddress();
  console.log(`Mock USDC Sepolia deployed to: ${mockUsdcSepoliaAddress}`);

  const mockUsdcBsc = await MockToken.deploy("Mock USDC BSC", "mUSDCB");
  await mockUsdcBsc.waitForDeployment();
  const mockUsdcBscAddress = await mockUsdcBsc.getAddress();
  console.log(`Mock USDC BSC deployed to: ${mockUsdcBscAddress}`);

  // Mint tokens
  const amount = ethers.parseUnits("1000", 18); // 1000 tokens with 18 decimals
  
  console.log("Minting tokens...");
  await mockUsdcSepolia.mint(signer.address, amount);
  await mockUsdcBsc.mint(signer.address, amount);
  console.log(`Minted ${ethers.formatEther(amount)} tokens of each type to ${signer.address}`);

  // Create a new pool with these mock tokens
  console.log("\nNow you can create a pool with these mock tokens using the following command:");
  console.log("npx hardhat run scripts/create-mock-pool.ts --network zetachain-testnet");
  
  console.log("\nAdd the following to your .env file:");
  console.log(`MOCK_USDC_SEPOLIA_ADDRESS=${mockUsdcSepoliaAddress}`);
  console.log(`MOCK_USDC_BSC_ADDRESS=${mockUsdcBscAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 