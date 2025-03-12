import { ethers } from "hardhat";

async function main() {
  console.log("Deploying ZetaChain Curve-like Pool contracts...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Deploy UnifiedStablecoin
  const UnifiedStablecoin = await ethers.getContractFactory("UnifiedStablecoin");
  const unifiedStablecoin = await UnifiedStablecoin.deploy();
  await unifiedStablecoin.waitForDeployment();
  const unifiedStablecoinAddress = await unifiedStablecoin.getAddress();
  console.log(`UnifiedStablecoin deployed to: ${unifiedStablecoinAddress}`);

  // Initialize the UnifiedStablecoin
  const initTx = await unifiedStablecoin.initialize("Unified Stablecoin", "UUSDC");
  await initTx.wait();
  console.log("UnifiedStablecoin initialized");

  // Deploy PoolFactory
  const PoolFactory = await ethers.getContractFactory("PoolFactory");
  const poolFactory = await PoolFactory.deploy();
  await poolFactory.waitForDeployment();
  const poolFactoryAddress = await poolFactory.getAddress();
  console.log(`PoolFactory deployed to: ${poolFactoryAddress}`);

  console.log("Deployment completed successfully!");
  console.log("\nContract addresses to add to your .env file:");
  console.log(`FACTORY_ADDRESS=${poolFactoryAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 