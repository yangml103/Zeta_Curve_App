import { ethers } from "hardhat";

async function main() {
  console.log("Swapping tokens in the stablecoin pool...");

  // Get addresses from environment
  const POOL_ADDRESS = process.env.POOL_ADDRESS || "";
  const TOKEN1_ADDRESS = process.env.TOKEN1_ADDRESS || "";
  const TOKEN2_ADDRESS = process.env.TOKEN2_ADDRESS || "";
  
  if (!POOL_ADDRESS || !TOKEN1_ADDRESS || !TOKEN2_ADDRESS) {
    throw new Error("Please set POOL_ADDRESS, TOKEN1_ADDRESS, and TOKEN2_ADDRESS in your .env file");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", POOL_ADDRESS);
  
  // Get the token contracts
  const token1 = await ethers.getContractAt("MockToken", TOKEN1_ADDRESS);
  const token2 = await ethers.getContractAt("MockToken", TOKEN2_ADDRESS);
  
  // Amount to swap (1 token)
  const amountIn = ethers.parseUnits("1", 18);
  
  // Check expected output amount
  const expectedOutput = await pool.getSwapAmount(TOKEN1_ADDRESS, TOKEN2_ADDRESS, amountIn);
  console.log(`Expected output for swapping ${ethers.formatUnits(amountIn, 18)} ${await token1.symbol()} to ${await token2.symbol()}: ${ethers.formatUnits(expectedOutput, 18)}`);
  
  // Approve token for the pool
  console.log("Approving token...");
  const approveTx = await token1.approve(POOL_ADDRESS, amountIn);
  await approveTx.wait();
  console.log("Token approved");
  
  // Swap tokens
  console.log("Swapping tokens...");
  try {
    const tx = await pool.swap(
      TOKEN1_ADDRESS,
      TOKEN2_ADDRESS,
      amountIn,
      0 // Min output amount (0 for testing)
    );
    console.log("Transaction sent:", tx.hash);
    
    const receipt = await tx.wait();
    console.log("Swap completed successfully!");
    
    // Check token balances after swap
    const token1Balance = await token1.balanceOf(signer.address);
    const token2Balance = await token2.balanceOf(signer.address);
    
    console.log(`Token balances after swap:`);
    console.log(`- ${await token1.symbol()}: ${ethers.formatUnits(token1Balance, 18)}`);
    console.log(`- ${await token2.symbol()}: ${ethers.formatUnits(token2Balance, 18)}`);
  } catch (error) {
    console.error("Error swapping tokens:", error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 