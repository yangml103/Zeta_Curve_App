import { ethers } from "hardhat";

async function main() {
  const gatewayAddress = "0x03550070A36cA0547598810A72827d6CC2217a95"; // ZetaChain Athens 3 Gateway

  console.log("Deploying FluidUSDCUniversal contract...");

  const FluidUSDCUniversalFactory = await ethers.getContractFactory("FluidUSDCUniversal");
  const fluidUSDCUniversal = await FluidUSDCUniversalFactory.deploy(gatewayAddress);

  // Wait for the deployment to be confirmed
  await fluidUSDCUniversal.waitForDeployment();

  console.log(`FluidUSDCUniversal deployed to: ${fluidUSDCUniversal.target}`);
  console.log(`Constructor arguments:`);
  console.log(`  Gateway Address: ${gatewayAddress}`);
  
  // You can add verification steps here if desired, e.g., using hardhat-etherscan plugin
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 