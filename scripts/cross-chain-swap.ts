import { ethers } from "hardhat";

async function main() {
  console.log("Testing cross-chain swap...");

  // Get addresses from environment
  const POOL_ADDRESS = process.env.POOL_ADDRESS || "";
  const ZRC20_USDC_ETH = process.env.ZRC20_USDC_ETH || "";
  const ZRC20_USDC_BSC = process.env.ZRC20_USDC_BSC || "";
  
  if (!POOL_ADDRESS || !ZRC20_USDC_ETH || !ZRC20_USDC_BSC) {
    throw new Error("Please set POOL_ADDRESS and ZRC20 token addresses in your .env file");
  }

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Get the pool contract - use ZetaStablecoinPool instead of StablecoinPool
  const pool = await ethers.getContractAt("ZetaStablecoinPool", POOL_ADDRESS);
  
  // Get the token contract
  const token = await ethers.getContractAt("IZRC20", ZRC20_USDC_ETH);
  
  // Amount to swap (1 token)
  const amountIn = ethers.parseUnits("1", 6); // Assuming 6 decimals for USDC
  
  // Destination chain ID (BSC testnet)
  const destinationChainId = 97;
  
  // Destination address (your address on BSC testnet)
  const destinationAddress = signer.address;
  
  // Get the expected output amount
  const expectedOutput = await pool.getSwapAmount(
    ZRC20_USDC_ETH,
    ZRC20_USDC_BSC,
    amountIn
  );
  
  console.log(`Expected output for swapping ${ethers.formatUnits(amountIn, 6)} ${ZRC20_USDC_ETH} to ${ZRC20_USDC_BSC}: ${ethers.formatUnits(expectedOutput, 6)}`);
  
  // Approve token for the pool
  console.log("Approving token...");
  const approveTx = await token.approve(POOL_ADDRESS, amountIn);
  await approveTx.wait();
  console.log("Token approved");
  
  // Perform cross-chain swap
  console.log("Performing cross-chain swap...");
  try {
    const tx = await pool.crossChainSwap(
      ZRC20_USDC_ETH,
      ZRC20_USDC_BSC,
      amountIn,
      0, // Min output amount (0 for testing)
      destinationChainId,
      destinationAddress
    );
    
    console.log("Transaction sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("Cross-chain swap initiated successfully!");
    console.log(`Check your wallet on BSC testnet (chain ID: ${destinationChainId}) for the received tokens.`);
  } catch (error) {
    console.error("Error performing cross-chain swap:", error);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 