import { ethers } from "hardhat";

async function main() {
  console.log("Deploying ZetaChain Curve-like Pool contracts...");

  // Deploy UnifiedStablecoin
  const UnifiedStablecoin = await ethers.getContractFactory("UnifiedStablecoin");
  const unifiedStablecoin = await UnifiedStablecoin.deploy();
  await unifiedStablecoin.waitForDeployment();
  console.log(`UnifiedStablecoin deployed to: ${await unifiedStablecoin.getAddress()}`);

  // Initialize the UnifiedStablecoin
  await unifiedStablecoin.initialize("Unified Stablecoin", "UUSDC");
  console.log("UnifiedStablecoin initialized");

  // Deploy PoolFactory
  const PoolFactory = await ethers.getContractFactory("PoolFactory");
  const poolFactory = await PoolFactory.deploy();
  await poolFactory.waitForDeployment();
  console.log(`PoolFactory deployed to: ${await poolFactory.getAddress()}`);

  console.log("Deployment completed successfully!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 