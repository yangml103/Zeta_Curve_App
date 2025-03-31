import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Adding liquidity to Gateway pool...");

  // Get the pool address from environment variables
  const poolAddress = process.env.GATEWAY_POOL_ADDRESS;
  if (!poolAddress) {
    throw new Error("GATEWAY_POOL_ADDRESS not set in environment variables");
  }

  // Get the token addresses from environment variables
  const usdtSepoliaAddress = process.env.USDT_SEPOLIA_ADDRESS;
  const usdtBscAddress = process.env.USDT_BSC_ADDRESS;
  
  if (!usdtSepoliaAddress || !usdtBscAddress) {
    throw new Error("Token addresses not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("ZetaGatewayStablecoinPool", poolAddress);
  
  // Get the token contracts
  const usdtSepolia = await ethers.getContractAt("MockZRC20", usdtSepoliaAddress);
  const usdtBsc = await ethers.getContractAt("MockZRC20", usdtBscAddress);
  
  // Amount to add as liquidity (in wei)
  const amount = ethers.parseUnits("100", 6); // Assuming 6 decimals for USDT

  console.log(`Adding ${ethers.formatUnits(amount, 6)} USDT from each source chain`);
  
  try {
    // First, approve tokens for the pool contract
    const tx1 = await usdtSepolia.approve(poolAddress, amount);
    await tx1.wait();
    console.log(`Approved ${ethers.formatUnits(amount, 6)} USDT Sepolia for pool`);
    
    const tx2 = await usdtBsc.approve(poolAddress, amount);
    await tx2.wait();
    console.log(`Approved ${ethers.formatUnits(amount, 6)} USDT BSC for pool`);
    
    // Add liquidity to the pool
    const amounts = [amount, amount];
    const minMintAmount = amount; // 1:1 ratio for simplicity
    
    const tx3 = await pool.addLiquidity(amounts, minMintAmount);
    console.log(`Transaction sent: ${tx3.hash}`);
    const receipt = await tx3.wait();
    
    if (!receipt) {
      console.error("Transaction receipt is null");
      return;
    }
    
    console.log(`Liquidity added successfully in transaction: ${receipt.hash}`);
    
    // Get LP token details
    const lpTokenAddress = await pool.lpToken();
    const lpToken = await ethers.getContractAt("OmniUSDT", lpTokenAddress);
    const lpBalance = await lpToken.balanceOf(signer.address);
    
    console.log(`LP token address: ${lpTokenAddress}`);
    console.log(`Your LP token balance: ${ethers.formatUnits(lpBalance, 6)}`);
    
    // Check pool balances
    const sepoliaBalance = await pool.balances(0);
    const bscBalance = await pool.balances(1);
    
    console.log(`\nPool balances:`);
    console.log(`USDT Sepolia: ${ethers.formatUnits(sepoliaBalance, 6)}`);
    console.log(`USDT BSC: ${ethers.formatUnits(bscBalance, 6)}`);
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