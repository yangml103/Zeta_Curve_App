import { ethers } from "hardhat";

async function main() {
  console.log("Checking pool contract state...");

  // Get addresses from environment
  const POOL_ADDRESS = process.env.POOL_ADDRESS || "";
  const TOKEN1_ADDRESS = process.env.TOKEN1_ADDRESS || "";
  const TOKEN2_ADDRESS = process.env.TOKEN2_ADDRESS || "";
  
  if (!POOL_ADDRESS || !TOKEN1_ADDRESS || !TOKEN2_ADDRESS) {
    throw new Error("Please set POOL_ADDRESS, TOKEN1_ADDRESS, and TOKEN2_ADDRESS in your .env file");
  }

  // Get the pool contract
  const pool = await ethers.getContractAt("StablecoinPool", POOL_ADDRESS);
  
  // Check pool parameters
  const amplificationParameter = await pool.amplificationParameter();
  const swapFee = await pool.swapFee();
  const adminFee = await pool.adminFee();
  
  console.log("Pool parameters:");
  console.log(`- Amplification parameter: ${amplificationParameter}`);
  console.log(`- Swap fee: ${swapFee} basis points`);
  console.log(`- Admin fee: ${adminFee} basis points`);
  
  // Check tokens in the pool
  try {
    const token0 = await pool.tokens(0);
    const token1 = await pool.tokens(1);
    
    console.log("Pool tokens:");
    console.log(`- Token 0: ${token0}`);
    console.log(`- Token 1: ${token1}`);
    
    // Check if our tokens are in the pool
    console.log(`\nExpected tokens:`);
    console.log(`- TOKEN1_ADDRESS: ${TOKEN1_ADDRESS}`);
    console.log(`- TOKEN2_ADDRESS: ${TOKEN2_ADDRESS}`);
    
    // Check if tokens are registered correctly
    const isToken1 = await pool.isToken(TOKEN1_ADDRESS);
    const isToken2 = await pool.isToken(TOKEN2_ADDRESS);
    
    console.log(`\nToken registration:`);
    console.log(`- TOKEN1 registered: ${isToken1}`);
    console.log(`- TOKEN2 registered: ${isToken2}`);
  } catch (error) {
    console.error("Error checking tokens:", error);
  }
  
  // Get LP token
  try {
    const lpTokenAddress = await pool.lpToken();
    console.log(`\nLP token address: ${lpTokenAddress}`);
    
    const lpToken = await ethers.getContractAt("UnifiedStablecoin", lpTokenAddress);
    const name = await lpToken.name();
    const symbol = await lpToken.symbol();
    const totalSupply = await lpToken.totalSupply();
    
    console.log(`LP token details:`);
    console.log(`- Name: ${name}`);
    console.log(`- Symbol: ${symbol}`);
    console.log(`- Total supply: ${ethers.formatUnits(totalSupply, 18)}`);
  } catch (error) {
    console.error("Error checking LP token:", error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 