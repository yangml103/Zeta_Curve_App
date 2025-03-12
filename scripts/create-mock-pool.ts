import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Creating a pool with mock tokens...");

  // Get the factory address from environment variables
  const factoryAddress = process.env.FACTORY_ADDRESS;
  if (!factoryAddress) {
    throw new Error("FACTORY_ADDRESS not set in environment variables");
  }

  // Get the mock token addresses from environment variables
  const mockUsdcSepoliaAddress = process.env.MOCK_USDC_SEPOLIA_ADDRESS;
  const mockUsdcBscAddress = process.env.MOCK_USDC_BSC_ADDRESS;
  
  if (!mockUsdcSepoliaAddress || !mockUsdcBscAddress) {
    throw new Error("Mock token addresses not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the factory contract
  const factory = await ethers.getContractAt("PoolFactory", factoryAddress);

  // Create the pool
  console.log(`Creating pool with tokens: ${mockUsdcSepoliaAddress} and ${mockUsdcBscAddress}`);
  
  try {
    // Create an array of token addresses
    const tokens = [mockUsdcSepoliaAddress, mockUsdcBscAddress];
    
    const tx = await factory.createPool(
      tokens,
      "Mock USDC Pool",
      "mUSDC-LP"
    );

    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    
    if (!receipt) {
      console.error("Transaction receipt is null");
      return;
    }
    
    console.log(`Pool created successfully in transaction: ${receipt.hash}`);

    // Get the pool address from the event
    const event = receipt.logs
      .map((log: any) => {
        try {
          return factory.interface.parseLog(log);
        } catch (e) {
          return null;
        }
      })
      .find((event: any) => event && event.name === "PoolCreated");

    if (event) {
      const poolAddress = event.args.pool;
      console.log(`Pool address: ${poolAddress}`);
      console.log("Please update your .env file with the pool address");
      console.log(`MOCK_POOL_ADDRESS=${poolAddress}`);
    } else {
      console.log("Could not find PoolCreated event in transaction logs");
    }
  } catch (error) {
    console.error("Error creating pool:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 