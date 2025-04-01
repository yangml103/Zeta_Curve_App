import { ethers } from "hardhat";

async function main() {
  console.log("Deploying ZetaGateway-enhanced Curve-like Pool contracts to ZetaChain testnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  
  // Get ZetaChain Token address from environment or use the testnet address
  // You can find the correct address in the ZetaChain documentation
  const ZETA_TOKEN_ADDRESS = process.env.ZETA_TOKEN_ADDRESS || "0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf";
  console.log(`Using ZetaChain Token: ${ZETA_TOKEN_ADDRESS}`);

  // Deploy GatewayPoolFactory with ZetaChain Token
  console.log("Deploying GatewayPoolFactory...");
  const GatewayPoolFactory = await ethers.getContractFactory("GatewayPoolFactory");
  const gatewayPoolFactory = await GatewayPoolFactory.deploy(ZETA_TOKEN_ADDRESS);
  await gatewayPoolFactory.waitForDeployment();
  const gatewayPoolFactoryAddress = await gatewayPoolFactory.getAddress();
  console.log(`GatewayPoolFactory deployed to: ${gatewayPoolFactoryAddress}`);

  // Configure supported chains
  console.log("Configuring supported chains...");
  // Ethereum Sepolia testnet
  const tx1 = await gatewayPoolFactory.setSupportedChain(11155111, true);
  await tx1.wait();
  console.log("Ethereum Sepolia testnet supported");
  
  // BSC testnet
  const tx2 = await gatewayPoolFactory.setSupportedChain(97, true);
  await tx2.wait();
  console.log("BSC testnet supported");
  
  // Polygon Mumbai testnet
  const tx3 = await gatewayPoolFactory.setSupportedChain(80001, true);
  await tx3.wait();
  console.log("Polygon Mumbai testnet supported");

  console.log("Deployment completed successfully!");
  console.log("\nContract addresses to add to your .env file:");
  console.log(`GATEWAY_FACTORY_ADDRESS=${gatewayPoolFactoryAddress}`);
  console.log(`ZETA_TOKEN_ADDRESS=${ZETA_TOKEN_ADDRESS}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 