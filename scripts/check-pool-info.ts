import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Checking pool information...");

  // Get addresses from environment variables
  const poolAddress = process.env.MOCK_POOL_ADDRESS;
  const mockUsdcSepoliaAddress = process.env.MOCK_USDC_SEPOLIA_ADDRESS;
  const mockUsdcBscAddress = process.env.MOCK_USDC_BSC_ADDRESS;

  if (!poolAddress) {
    throw new Error("Pool address not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", poolAddress);
  
  try {
    // Get basic pool information
    const lpTokenAddress = await pool.lpToken();
    const lpToken = await ethers.getContractAt("IERC20", lpTokenAddress);
    const lpTokenTotalSupply = await lpToken.totalSupply();
    
    console.log("\nPool Information:");
    console.log(`Pool Address: ${poolAddress}`);
    console.log(`LP Token Address: ${lpTokenAddress}`);
    console.log(`LP Token Total Supply: ${ethers.formatEther(lpTokenTotalSupply)}`);
    
    // Get token information
    if (mockUsdcSepoliaAddress && mockUsdcBscAddress) {
      const mockUsdcSepolia = await ethers.getContractAt("IERC20", mockUsdcSepoliaAddress);
      const mockUsdcBsc = await ethers.getContractAt("IERC20", mockUsdcBscAddress);
      
      const token0Balance = await mockUsdcSepolia.balanceOf(poolAddress);
      const token1Balance = await mockUsdcBsc.balanceOf(poolAddress);
      
      console.log("\nToken Balances in Pool:");
      console.log(`Mock USDC Sepolia (${mockUsdcSepoliaAddress}): ${ethers.formatEther(token0Balance)}`);
      console.log(`Mock USDC BSC (${mockUsdcBscAddress}): ${ethers.formatEther(token1Balance)}`);
    }
    
    // Get LP token balance of the signer
    const lpBalance = await lpToken.balanceOf(signer.address);
    console.log(`\nYour LP Token Balance: ${ethers.formatEther(lpBalance)}`);
    
    // Calculate the share of the pool
    if (lpTokenTotalSupply > 0n) {
      const sharePercentage = (lpBalance * 10000n) / lpTokenTotalSupply;
      console.log(`Your Share of the Pool: ${sharePercentage / 100n}.${sharePercentage % 100n}%`);
    } else {
      console.log("Total supply is zero, cannot calculate share percentage");
    }
  } catch (error) {
    console.error("Error getting pool information:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 