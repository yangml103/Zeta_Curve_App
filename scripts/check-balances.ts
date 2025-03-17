import { ethers } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Checking token balances...");

  // Get the signer
  const [signer] = await ethers.getSigners();
  console.log(`Account address: ${signer.address}`);

  // Check ETH balance
  const ethBalance = await ethers.provider.getBalance(signer.address);
  console.log(`ETH balance: ${ethers.formatEther(ethBalance)} ETH`);

  // Get ZRC20 token addresses
  const usdcSepoliaAddress = process.env.USDC_SEPOLIA_ADDRESS;
  const usdcBscAddress = process.env.USDC_BSC_ADDRESS;
  const mockUsdcAddress = process.env.MOCK_USDC_ADDRESS;
  const mockUsdtAddress = process.env.MOCK_USDT_ADDRESS;

  // Check ZRC20 token balances
  if (usdcSepoliaAddress) {
    const usdcSepolia = await ethers.getContractAt("IERC20", usdcSepoliaAddress);
    const usdcSepoliaBalance = await usdcSepolia.balanceOf(signer.address);
    console.log(`USDC Sepolia (ZRC20) balance: ${ethers.formatUnits(usdcSepoliaBalance, 6)} USDC`);
  }

  if (usdcBscAddress) {
    const usdcBsc = await ethers.getContractAt("IERC20", usdcBscAddress);
    const usdcBscBalance = await usdcBsc.balanceOf(signer.address);
    console.log(`USDC BSC (ZRC20) balance: ${ethers.formatUnits(usdcBscBalance, 6)} USDC`);
  }

  // Check mock token balances
  if (mockUsdcAddress) {
    const mockUsdc = await ethers.getContractAt("IERC20", mockUsdcAddress);
    const mockUsdcBalance = await mockUsdc.balanceOf(signer.address);
    console.log(`Mock USDC balance: ${ethers.formatEther(mockUsdcBalance)} mUSDC`);
  }

  if (mockUsdtAddress) {
    const mockUsdt = await ethers.getContractAt("IERC20", mockUsdtAddress);
    const mockUsdtBalance = await mockUsdt.balanceOf(signer.address);
    console.log(`Mock USDT balance: ${ethers.formatEther(mockUsdtBalance)} mUSDT`);
  }

  // Check pool LP token balance if pool exists
  const poolAddress = process.env.POOL_ADDRESS;
  if (poolAddress) {
    try {
      const pool = await ethers.getContractAt("StablecoinPool", poolAddress);
      const lpTokenAddress = await pool.lpToken();
      const lpToken = await ethers.getContractAt("IERC20", lpTokenAddress);
      const lpBalance = await lpToken.balanceOf(signer.address);
      console.log(`LP Token balance: ${ethers.formatEther(lpBalance)} LP`);
    } catch (error) {
      console.log("Could not check LP token balance");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 