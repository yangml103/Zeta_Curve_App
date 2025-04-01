import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Performing cross-chain swap using Gateway pool...");

  // Get the pool address from environment variables
  const poolAddress = process.env.GATEWAY_POOL_ADDRESS;
  if (!poolAddress) {
    throw new Error("GATEWAY_POOL_ADDRESS not set in environment variables");
  }

  // Get the token addresses from environment variables
  const usdtSepoliaAddress = process.env.USDT_SEPOLIA_ADDRESS;
  
  if (!usdtSepoliaAddress) {
    throw new Error("USDT_SEPOLIA_ADDRESS not set in environment variables");
  }

  // Get the destination chain information
  const destinationChainId = 97; // BSC Testnet
  const destinationAddress = process.env.DESTINATION_ADDRESS;
  if (!destinationAddress) {
    throw new Error("DESTINATION_ADDRESS not set in environment variables");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract
  const pool = await ethers.getContractAt("ZetaGatewayStablecoinPool", poolAddress);
  
  // Get the token contract
  const usdtSepolia = await ethers.getContractAt("MockZRC20", usdtSepoliaAddress);
  
  // Amount to swap (in wei)
  const amountIn = ethers.parseUnits("10", 6); // Assuming 6 decimals for USDT
  const minAmountOut = ethers.parseUnits("9.9", 6); // 1% slippage

  console.log(`Swapping ${ethers.formatUnits(amountIn, 6)} USDT from Sepolia to BSC Testnet`);
  console.log(`Destination address: ${destinationAddress}`);
  
  try {
    // First, approve token for the pool contract
    const tx1 = await usdtSepolia.approve(poolAddress, amountIn);
    await tx1.wait();
    console.log(`Approved ${ethers.formatUnits(amountIn, 6)} USDT Sepolia for pool`);
    
    // Encode the destination address as bytes
    const encodedDestinationAddress = ethers.toUtf8Bytes(destinationAddress);
    
    // Perform the cross-chain swap
    const tx2 = await pool.crossChainSwap(
      usdtSepoliaAddress,
      amountIn,
      minAmountOut,
      destinationChainId,
      encodedDestinationAddress
    );
    
    console.log(`Transaction sent: ${tx2.hash}`);
    const receipt = await tx2.wait();
    
    if (!receipt) {
      console.error("Transaction receipt is null");
      return;
    }
    
    console.log(`Cross-chain swap successfully initiated in transaction: ${receipt.hash}`);
    console.log("Note: The actual cross-chain transfer will take some time to complete");
    
    // Check pool balance after swap
    const sepoliaBalance = await pool.balances(0);
    
    console.log(`\nPool balance after swap:`);
    console.log(`USDT Sepolia: ${ethers.formatUnits(sepoliaBalance, 6)}`);
  } catch (error) {
    console.error("Error performing cross-chain swap:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 