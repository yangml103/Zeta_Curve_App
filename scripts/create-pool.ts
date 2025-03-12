import { ethers } from "hardhat";

// This script assumes you have already deployed the PoolFactory contract
// and have tokens available on ZetaChain

async function main() {
  console.log("Creating a new stablecoin pool...");

  // Get the factory address from environment or use a default for testing
  const FACTORY_ADDRESS = process.env.FACTORY_ADDRESS || "";
  if (!FACTORY_ADDRESS) {
    throw new Error("Please set FACTORY_ADDRESS in your .env file");
  }

  // Get token addresses (these would be the stablecoin tokens on ZetaChain)
  // For example, USDC, USDT, etc.
  const TOKEN1_ADDRESS = process.env.TOKEN1_ADDRESS || "";
  const TOKEN2_ADDRESS = process.env.TOKEN2_ADDRESS || "";
  
  if (!TOKEN1_ADDRESS || !TOKEN2_ADDRESS) {
    throw new Error("Please set TOKEN1_ADDRESS and TOKEN2_ADDRESS in your .env file");
  }

  // Get the PoolFactory contract
  const factory = await ethers.getContractAt("PoolFactory", FACTORY_ADDRESS);

  // Create a new pool with the tokens
  console.log("Creating pool with tokens:", [TOKEN1_ADDRESS, TOKEN2_ADDRESS]);
  
  const tx = await factory.createPool(
    [TOKEN1_ADDRESS, TOKEN2_ADDRESS],
    "Stablecoin LP Token",
    "SLP"
  );

  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  
  // Get the number of pools to find the latest one
  const poolCount = await factory.getPoolCount();
  const lastIndex = poolCount - 1n;
  const poolAddress = await factory.allPools(lastIndex);
  
  console.log(`New pool created at address: ${poolAddress}`);
  console.log("Pool creation completed successfully!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 