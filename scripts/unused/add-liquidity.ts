import { ethers } from "hardhat";

async function main() {
  console.log("Adding liquidity to the stablecoin pool...");

  // Get addresses from environment
  const POOL_ADDRESS = process.env.POOL_ADDRESS || "0x689C9A95c37bfA4DBb1701A6f80822E4a21EcDa9";
  const TOKEN1_ADDRESS = process.env.TOKEN1_ADDRESS || "";
  const TOKEN2_ADDRESS = process.env.TOKEN2_ADDRESS || "";
  
  if (!TOKEN1_ADDRESS || !TOKEN2_ADDRESS) {
    throw new Error("Please set TOKEN1_ADDRESS and TOKEN2_ADDRESS in your .env file");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", POOL_ADDRESS);
  
  // Get the token contracts
  const token1 = await ethers.getContractAt("MockToken", TOKEN1_ADDRESS);
  const token2 = await ethers.getContractAt("MockToken", TOKEN2_ADDRESS);
  
  // Amount to add as liquidity (10 tokens of each)
  const amount = ethers.parseUnits("10", 18);
  
  console.log(`Adding ${ethers.formatUnits(amount, 18)} of each token as liquidity...`);
  
  // Approve tokens for the pool
  console.log("Approving tokens...");
  const approveTx1 = await token1.approve(POOL_ADDRESS, amount);
  await approveTx1.wait();
  console.log("Token 1 approved");
  
  const approveTx2 = await token2.approve(POOL_ADDRESS, amount);
  await approveTx2.wait();
  console.log("Token 2 approved");
  
  // Add liquidity
  console.log("Adding liquidity...");
  try {
    const tx = await pool.addLiquidity([amount, amount], 0);
    console.log("Transaction sent:", tx.hash);
    
    const receipt = await tx.wait();
    console.log("Liquidity added successfully!");
    
    // Get LP token address
    const lpTokenAddress = await pool.lpToken();
    const lpToken = await ethers.getContractAt("UnifiedStablecoin", lpTokenAddress);
    
    // Check LP token balance
    const lpBalance = await lpToken.balanceOf(signer.address);
    console.log(`Received ${ethers.formatUnits(lpBalance, 18)} LP tokens`);
  } catch (error) {
    console.error("Error adding liquidity:", error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 