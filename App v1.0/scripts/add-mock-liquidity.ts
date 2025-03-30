import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Adding liquidity to mock pool...");

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

  // Check token balances
  const mockUsdcSepoliaBalance = await mockUsdcSepolia.balanceOf(signer.address);
  const mockUsdcBscBalance = await mockUsdcBsc.balanceOf(signer.address);

  console.log(`Mock USDC Sepolia balance: ${ethers.formatEther(mockUsdcSepoliaBalance)}`);
  console.log(`Mock USDC BSC balance: ${ethers.formatEther(mockUsdcBscBalance)}`);

  // Amount to add as liquidity
  const amount = ethers.parseEther("100"); // 100 tokens

  console.log(`Adding ${ethers.formatEther(amount)} of each token as liquidity`);

  try {
    // Approve tokens for the pool
    console.log("Approving Mock USDC Sepolia...");
    const approveTx1 = await mockUsdcSepolia.approve(poolAddress, amount);
    await approveTx1.wait();
    console.log("Mock USDC Sepolia approved");

    console.log("Approving Mock USDC BSC...");
    const approveTx2 = await mockUsdcBsc.approve(poolAddress, amount);
    await approveTx2.wait();
    console.log("Mock USDC BSC approved");

    // Add liquidity
    console.log("Adding liquidity...");
    const amounts = [amount, amount];
    const minLpAmount = 0; // Accept any amount of LP tokens

    const addLiquidityTx = await pool.addLiquidity(amounts, minLpAmount);
    const receipt = await addLiquidityTx.wait();
    
    if (!receipt) {
      console.error("Transaction receipt is null");
      return;
    }
    
    console.log(`Liquidity added successfully in transaction: ${receipt.hash}`);

    // Get LP token balance
    const lpToken = await ethers.getContractAt("IERC20", await pool.lpToken());
    const lpBalance = await lpToken.balanceOf(signer.address);
    console.log(`Received ${ethers.formatEther(lpBalance)} LP tokens`);

  } catch (error) {
    console.error("Error adding liquidity:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 