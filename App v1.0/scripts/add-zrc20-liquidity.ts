import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Adding liquidity to ZRC20 pool...");

  // Get addresses from environment variables
  const poolAddress = process.env.POOL_ADDRESS;
  const usdcSepoliaAddress = process.env.USDC_SEPOLIA_ADDRESS;
  const usdcBscAddress = process.env.USDC_BSC_ADDRESS;

  if (!poolAddress || !usdcSepoliaAddress || !usdcBscAddress) {
    throw new Error("Required addresses not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", poolAddress);
  
  // Get the token contracts
  const usdcSepolia = await ethers.getContractAt("IERC20", usdcSepoliaAddress);
  const usdcBsc = await ethers.getContractAt("IERC20", usdcBscAddress);

  // Check token balances
  const usdcSepoliaBalance = await usdcSepolia.balanceOf(signer.address);
  const usdcBscBalance = await usdcBsc.balanceOf(signer.address);

  console.log(`USDC Sepolia balance: ${ethers.formatUnits(usdcSepoliaBalance, 6)}`);
  console.log(`USDC BSC balance: ${ethers.formatUnits(usdcBscBalance, 6)}`);

  // Amount to add as liquidity (adjust based on your token balances)
  // Using a small amount for testing
  const amount = ethers.parseUnits("1", 6); // 1 USDC (with 6 decimals)

  console.log(`Adding ${ethers.formatUnits(amount, 6)} of each token as liquidity`);

  try {
    // Approve tokens for the pool
    console.log("Approving USDC Sepolia...");
    const approveTx1 = await usdcSepolia.approve(poolAddress, amount);
    await approveTx1.wait();
    console.log("USDC Sepolia approved");

    console.log("Approving USDC BSC...");
    const approveTx2 = await usdcBsc.approve(poolAddress, amount);
    await approveTx2.wait();
    console.log("USDC BSC approved");

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
    console.log(`Received ${ethers.formatUnits(lpBalance, 18)} LP tokens`);

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