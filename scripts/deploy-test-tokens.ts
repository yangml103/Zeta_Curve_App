import { ethers } from "hardhat";

async function main() {
  console.log("Deploying test tokens for the Curve-like pool...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying tokens with the account: ${deployer.address}`);

  // Deploy first test token (Mock USDC)
  const MockToken = await ethers.getContractFactory("MockToken");
  const mockUSDC = await MockToken.deploy("Mock USDC", "mUSDC");
  await mockUSDC.waitForDeployment();
  const mockUSDCAddress = await mockUSDC.getAddress();
  console.log(`Mock USDC deployed to: ${mockUSDCAddress}`);

  // Deploy second test token (Mock USDT)
  const mockUSDT = await MockToken.deploy("Mock USDT", "mUSDT");
  await mockUSDT.waitForDeployment();
  const mockUSDTAddress = await mockUSDT.getAddress();
  console.log(`Mock USDT deployed to: ${mockUSDTAddress}`);

  // Mint some tokens to the deployer for testing
  const mintAmount = ethers.parseUnits("1000000", 18); // 1 million tokens
  await mockUSDC.mint(deployer.address, mintAmount);
  await mockUSDT.mint(deployer.address, mintAmount);
  console.log(`Minted ${ethers.formatUnits(mintAmount, 18)} tokens to ${deployer.address}`);

  console.log("Token deployment completed successfully!");
  console.log("\nToken addresses to add to your .env file:");
  console.log(`TOKEN1_ADDRESS=${mockUSDCAddress}`);
  console.log(`TOKEN2_ADDRESS=${mockUSDTAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 