import { ethers } from "hardhat";

async function main() {
  console.log("Checking token balances...");

  // Get addresses from environment
  const TOKEN1_ADDRESS = process.env.TOKEN1_ADDRESS || "";
  const TOKEN2_ADDRESS = process.env.TOKEN2_ADDRESS || "";
  const POOL_ADDRESS = process.env.POOL_ADDRESS || "";
  
  if (!TOKEN1_ADDRESS || !TOKEN2_ADDRESS) {
    throw new Error("Please set TOKEN1_ADDRESS and TOKEN2_ADDRESS in your .env file");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Checking balances for account: ${signer.address}`);

  // Get the token contracts
  const token1 = await ethers.getContractAt("MockToken", TOKEN1_ADDRESS);
  const token2 = await ethers.getContractAt("MockToken", TOKEN2_ADDRESS);
  
  // Check token balances
  const token1Balance = await token1.balanceOf(signer.address);
  const token2Balance = await token2.balanceOf(signer.address);
  
  console.log(`Token 1 (${await token1.symbol()}) balance: ${ethers.formatUnits(token1Balance, 18)}`);
  console.log(`Token 2 (${await token2.symbol()}) balance: ${ethers.formatUnits(token2Balance, 18)}`);
  
  // Check token allowances for the pool
  if (POOL_ADDRESS) {
    const token1Allowance = await token1.allowance(signer.address, POOL_ADDRESS);
    const token2Allowance = await token2.allowance(signer.address, POOL_ADDRESS);
    
    console.log(`Token 1 allowance for pool: ${ethers.formatUnits(token1Allowance, 18)}`);
    console.log(`Token 2 allowance for pool: ${ethers.formatUnits(token2Allowance, 18)}`);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 