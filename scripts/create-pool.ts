import { ethers } from "hardhat";

// This script assumes you have already deployed the PoolFactory contract
// and have ZRC20 tokens available on ZetaChain

async function main() {
  console.log("Creating a new stablecoin pool...");

  // Get the factory address from environment or use a default for testing
  const FACTORY_ADDRESS = process.env.FACTORY_ADDRESS || "";
  if (!FACTORY_ADDRESS) {
    throw new Error("Please set FACTORY_ADDRESS in your .env file");
  }

  // Get ZRC20 token addresses (these would be the ZetaChain representations of cross-chain stablecoins)
  // For example, USDC on Ethereum, BSC, etc.
  const ZRC20_USDC_ETH = process.env.ZRC20_USDC_ETH || "";
  const ZRC20_USDC_BSC = process.env.ZRC20_USDC_BSC || "";
  
  if (!ZRC20_USDC_ETH || !ZRC20_USDC_BSC) {
    throw new Error("Please set ZRC20 token addresses in your .env file");
  }

  // Get the PoolFactory contract
  const factory = await ethers.getContractAt("PoolFactory", FACTORY_ADDRESS);

  // Create a new pool with the ZRC20 tokens
  console.log("Creating pool with tokens:", [ZRC20_USDC_ETH, ZRC20_USDC_BSC]);
  
  const tx = await factory.createPool(
    [ZRC20_USDC_ETH, ZRC20_USDC_BSC],
    "Unified USDC LP Token",
    "UUSDC-LP"
  );

  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  
  // Get the number of pools to find the latest one
  const poolCount = await factory.getPoolCount();
  const poolAddress = await factory.allPools(poolCount - 1);
  
  console.log(`New pool created at address: ${poolAddress}`);
  console.log("Pool creation completed successfully!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 