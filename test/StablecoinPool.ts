import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("StablecoinPool", function () {
  let unifiedStablecoin: Contract;
  let mockToken1: Contract;
  let mockToken2: Contract;
  let stablecoinPool: Contract;
  let owner: Signer;
  let user1: Signer;
  let user2: Signer;
  let ownerAddress: string;
  let user1Address: string;
  let user2Address: string;

  const INITIAL_AMOUNT = ethers.parseEther("1000");
  const AMPLIFICATION_PARAMETER = 2000; // A = 20
  const SWAP_FEE = 4; // 0.04%
  const ADMIN_FEE = 5000; // 50% of swap fees

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();

    // Deploy mock tokens for testing
    const MockToken = await ethers.getContractFactory("MockToken");
    mockToken1 = await MockToken.deploy("Mock Token 1", "MT1");
    mockToken2 = await MockToken.deploy("Mock Token 2", "MT2");

    // Mint tokens to users
    await mockToken1.mint(user1Address, INITIAL_AMOUNT);
    await mockToken1.mint(user2Address, INITIAL_AMOUNT);
    await mockToken2.mint(user1Address, INITIAL_AMOUNT);
    await mockToken2.mint(user2Address, INITIAL_AMOUNT);

    // Deploy UnifiedStablecoin
    const UnifiedStablecoin = await ethers.getContractFactory("UnifiedStablecoin");
    unifiedStablecoin = await UnifiedStablecoin.deploy();
    await unifiedStablecoin.initialize("Unified Stablecoin", "UUSDC");

    // Deploy StablecoinPool
    const StablecoinPool = await ethers.getContractFactory("StablecoinPool");
    stablecoinPool = await StablecoinPool.deploy(
      [await mockToken1.getAddress(), await mockToken2.getAddress()],
      AMPLIFICATION_PARAMETER,
      SWAP_FEE,
      ADMIN_FEE,
      await unifiedStablecoin.getAddress()
    );

    // Transfer ownership of UnifiedStablecoin to StablecoinPool
    await unifiedStablecoin.transferOwnership(await stablecoinPool.getAddress());
  });

  describe("Initialization", function () {
    it("Should initialize with correct parameters", async function () {
      expect(await stablecoinPool.amplificationParameter()).to.equal(AMPLIFICATION_PARAMETER);
      expect(await stablecoinPool.swapFee()).to.equal(SWAP_FEE);
      expect(await stablecoinPool.adminFee()).to.equal(ADMIN_FEE);
      expect(await stablecoinPool.tokens(0)).to.equal(await mockToken1.getAddress());
      expect(await stablecoinPool.tokens(1)).to.equal(await mockToken2.getAddress());
      expect(await stablecoinPool.lpToken()).to.equal(await unifiedStablecoin.getAddress());
    });
  });

  describe("Liquidity", function () {
    const LIQUIDITY_AMOUNT = ethers.parseEther("100");

    beforeEach(async function () {
      // Approve tokens for StablecoinPool
      await mockToken1.connect(user1).approve(await stablecoinPool.getAddress(), LIQUIDITY_AMOUNT);
      await mockToken2.connect(user1).approve(await stablecoinPool.getAddress(), LIQUIDITY_AMOUNT);
    });

    it("Should add initial liquidity correctly", async function () {
      // Add initial liquidity
      await stablecoinPool.connect(user1).addLiquidity(
        [LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT],
        0 // Min mint amount (0 for testing)
      );

      // Check balances
      expect(await stablecoinPool.balances(0)).to.equal(LIQUIDITY_AMOUNT);
      expect(await stablecoinPool.balances(1)).to.equal(LIQUIDITY_AMOUNT);
      
      // Check LP token balance
      const expectedLPTokens = LIQUIDITY_AMOUNT * 2n; // Sum of deposits
      expect(await unifiedStablecoin.balanceOf(user1Address)).to.equal(expectedLPTokens);
    });

    it("Should remove liquidity correctly", async function () {
      // Add initial liquidity
      await stablecoinPool.connect(user1).addLiquidity(
        [LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT],
        0 // Min mint amount (0 for testing)
      );

      // Get LP token balance
      const lpBalance = await unifiedStablecoin.balanceOf(user1Address);
      
      // Approve LP tokens for burning
      await unifiedStablecoin.connect(user1).approve(await stablecoinPool.getAddress(), lpBalance);
      
      // Remove all liquidity
      await stablecoinPool.connect(user1).removeLiquidity(
        lpBalance,
        [0, 0] // Min amounts (0 for testing)
      );
      
      // Check token balances returned to user
      expect(await mockToken1.balanceOf(user1Address)).to.equal(INITIAL_AMOUNT);
      expect(await mockToken2.balanceOf(user1Address)).to.equal(INITIAL_AMOUNT);
      
      // Check LP token balance is 0
      expect(await unifiedStablecoin.balanceOf(user1Address)).to.equal(0);
    });
  });

  describe("Swapping", function () {
    const LIQUIDITY_AMOUNT = ethers.parseEther("1000");
    const SWAP_AMOUNT = ethers.parseEther("10");

    beforeEach(async function () {
      // Add initial liquidity
      await mockToken1.connect(user1).approve(await stablecoinPool.getAddress(), LIQUIDITY_AMOUNT);
      await mockToken2.connect(user1).approve(await stablecoinPool.getAddress(), LIQUIDITY_AMOUNT);
      
      await stablecoinPool.connect(user1).addLiquidity(
        [LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT],
        0 // Min mint amount (0 for testing)
      );
      
      // Approve tokens for swapping
      await mockToken1.connect(user2).approve(await stablecoinPool.getAddress(), SWAP_AMOUNT);
    });

    it("Should swap tokens correctly", async function () {
      // Get initial balances
      const initialToken1Balance = await mockToken1.balanceOf(user2Address);
      const initialToken2Balance = await mockToken2.balanceOf(user2Address);
      
      // Get expected output amount
      const expectedOutput = await stablecoinPool.getSwapAmount(
        await mockToken1.getAddress(),
        await mockToken2.getAddress(),
        SWAP_AMOUNT
      );
      
      // Perform swap
      await stablecoinPool.connect(user2).swap(
        await mockToken1.getAddress(),
        await mockToken2.getAddress(),
        SWAP_AMOUNT,
        0 // Min output amount (0 for testing)
      );
      
      // Check balances after swap
      expect(await mockToken1.balanceOf(user2Address)).to.equal(initialToken1Balance - SWAP_AMOUNT);
      expect(await mockToken2.balanceOf(user2Address)).to.equal(initialToken2Balance + expectedOutput);
    });
  });
}); 