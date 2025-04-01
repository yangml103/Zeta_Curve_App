import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Creating a pool with ZRC20 tokens using Zeta Gateway...");

  // Get the factory address from environment variables
  const factoryAddress = process.env.GATEWAY_FACTORY_ADDRESS;
  if (!factoryAddress) {
    throw new Error("GATEWAY_FACTORY_ADDRESS not set in environment variables");
  }

  // Get the ZRC20 token addresses from environment variables
  const usdtSepoliaAddress = process.env.USDT_SEPOLIA_ADDRESS;
  const usdtBscAddress = process.env.USDT_BSC_ADDRESS;
  
  if (!usdtSepoliaAddress || !usdtBscAddress) {
    throw new Error("ZRC20 token addresses not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the factory contract
  const factory = await ethers.getContractAt("GatewayPoolFactory", factoryAddress);

  // Create the pool
  console.log(`Creating pool with tokens: ${usdtSepoliaAddress} and ${usdtBscAddress}`);
  
  try {
    // Create an array of token addresses
    const tokens = [usdtSepoliaAddress, usdtBscAddress];
    
    const tx = await factory.createPool(
      tokens,
      "OmniUSDT Pool",
      "omUSDT-LP"
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
      const lpTokenAddress = event.args.lpToken;
      console.log(`Pool address: ${poolAddress}`);
      console.log(`LP token address: ${lpTokenAddress}`);
      console.log("Please update your .env file with these addresses");
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