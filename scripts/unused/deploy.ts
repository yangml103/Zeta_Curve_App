import { ethers } from "hardhat";

async function main() {
  console.log("Deploying ZetaChain-enhanced Curve-like Pool contracts...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  
  // Get ZetaChain connector address from environment or use a default for testing
  const ZETA_CONNECTOR_ADDRESS = process.env.ZETA_CONNECTOR_ADDRESS || "0x000000000000000000000000000000000000ZeTA";
  console.log(`Using ZetaChain connector: ${ZETA_CONNECTOR_ADDRESS}`);

  // Deploy PoolFactory with ZetaChain connector
  console.log("Deploying PoolFactory...");
  const PoolFactory = await ethers.getContractFactory("PoolFactory");
  const poolFactory = await PoolFactory.deploy(ZETA_CONNECTOR_ADDRESS);
  await poolFactory.waitForDeployment();
  const poolFactoryAddress = await poolFactory.getAddress();
  console.log(`PoolFactory deployed to: ${poolFactoryAddress}`);

  // Configure supported chains
  console.log("Configuring supported chains...");
  // Ethereum Sepolia testnet
  const tx1 = await poolFactory.setSupportedChain(11155111, true);
  await tx1.wait();
  console.log("Ethereum Sepolia testnet supported");
  
  // BSC testnet
  const tx2 = await poolFactory.setSupportedChain(97, true);
  await tx2.wait();
  console.log("BSC testnet supported");
  
  // Polygon Mumbai testnet
  const tx3 = await poolFactory.setSupportedChain(80001, true);
  await tx3.wait();
  console.log("Polygon Mumbai testnet supported");

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