import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Swapping tokens in mock pool...");

  // Get addresses from environment variables
  const poolAddress = process.env.MOCK_POOL_ADDRESS;
  const mockUsdcSepoliaAddress = process.env.MOCK_USDC_SEPOLIA_ADDRESS;
  const mockUsdcBscAddress = process.env.MOCK_USDC_BSC_ADDRESS;

  if (!poolAddress || !mockUsdcSepoliaAddress || !mockUsdcBscAddress) {
    throw new Error("Required addresses not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", poolAddress);
  
  // Get the token contracts
  const mockUsdcSepolia = await ethers.getContractAt("IERC20", mockUsdcSepoliaAddress);
  const mockUsdcBsc = await ethers.getContractAt("IERC20", mockUsdcBscAddress);

  // Check token balances before swap
  const mockUsdcSepoliaBalanceBefore = await mockUsdcSepolia.balanceOf(signer.address);
  const mockUsdcBscBalanceBefore = await mockUsdcBsc.balanceOf(signer.address);

  console.log("Balances before swap:");
  console.log(`Mock USDC Sepolia: ${ethers.formatEther(mockUsdcSepoliaBalanceBefore)}`);
  console.log(`Mock USDC BSC: ${ethers.formatEther(mockUsdcBscBalanceBefore)}`);

  // Amount to swap
  const amountIn = ethers.parseEther("10"); // 10 tokens

  try {
    // Approve token for the pool
    console.log(`Approving ${ethers.formatEther(amountIn)} Mock USDC Sepolia for swap...`);
    const approveTx = await mockUsdcSepolia.approve(poolAddress, amountIn);
    await approveTx.wait();
    console.log("Token approved");

    // Execute swap
    console.log("Executing swap...");
    // Set a minimum amount out with some slippage tolerance
    const minAmountOut = ethers.parseEther("9.9"); // 1% slippage tolerance
    
    const swapTx = await pool.swap(
      mockUsdcSepoliaAddress, // token in
      mockUsdcBscAddress,     // token out
      amountIn,               // amount in
      minAmountOut            // min amount out
    );
    
    const receipt = await swapTx.wait();
    
    if (!receipt) {
      console.error("Transaction receipt is null");
      return;
    }
    
    console.log(`Swap executed successfully in transaction: ${receipt.hash}`);

    // Check token balances after swap
    const mockUsdcSepoliaBalanceAfter = await mockUsdcSepolia.balanceOf(signer.address);
    const mockUsdcBscBalanceAfter = await mockUsdcBsc.balanceOf(signer.address);

    console.log("Balances after swap:");
    console.log(`Mock USDC Sepolia: ${ethers.formatEther(mockUsdcSepoliaBalanceAfter)}`);
    console.log(`Mock USDC BSC: ${ethers.formatEther(mockUsdcBscBalanceAfter)}`);

    console.log("Swap summary:");
    console.log(`Swapped: ${ethers.formatEther(mockUsdcSepoliaBalanceBefore - mockUsdcSepoliaBalanceAfter)} Mock USDC Sepolia`);
    console.log(`Received: ${ethers.formatEther(mockUsdcBscBalanceAfter - mockUsdcBscBalanceBefore)} Mock USDC BSC`);

  } catch (error) {
    console.error("Error swapping tokens:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 