# FluidUSDCUniversal

This document explains the deposit and withdrawal flows for interacting with the `FluidUSDCUniversal` contract on ZetaChain, focusing on moving USDC between chains (e.g., Base and Solana) via ZRC-20 tokens and Curve liquidity pools.

---

## 🚀 Deposit Flow  
**Example**: Deposit native USDC from Base → Receive USDC.4 LP tokens on ZetaChain

### 1. User Action (on Base)
- Calls the `depositAndCall` function on the Base Gateway contract.
- **Parameters:**
  - `receiver`: Address of your deployed `FluidUSDCUniversal` contract on ZetaChain.
  - `amount`: Amount of native USDC to deposit.
  - `asset`: Address of native USDC token contract on Base.
  - `payload`: ABI-encoded as `abi.encode(uint8(0), uint256 minMintAmount)`:
    - `cmd`: `CMD_DEPOSIT_ADD_LIQUIDITY` = 0
    - `minMint`: Minimum acceptable USDC.4 LP tokens (slippage protection).
  - `revertOptions`: Standard ZetaChain revert-handling configuration.

### 2. ZetaChain Actions
- Base Gateway **locks** native USDC.
- ZetaChain validators observe and trigger the ZetaChain Gateway.
- ZetaChain Gateway **mints** USDC.BASE (ZRC-20) and sends it to your `FluidUSDCUniversal` contract.
- It then calls the `onCall` function on your contract.

### 3. `FluidUSDCUniversal.onCall` Execution
- Verifies Gateway origin (`onlyGateway` modifier).
- Decodes `payload` to extract `cmd` and `minMint`.
- If `cmd == 0`, invokes `_addLiquidity` with:
  - `token`: USDC.BASE (ZRC-20 address)
  - `amount`: Amount of received USDC.BASE
  - `minMint`: Minimum LP tokens expected
  - `lpReceiver`: Context sender (user's ZetaChain address)

### 4. `_addLiquidity` Function
- Approves Curve Pool (`POOL`) to spend USDC.BASE.
- Determines pool index: `IDX_BASE = 2`
- Constructs amounts array: `[0, 0, amount, 0]`
- Calls `add_liquidity` on the Curve Pool with `amounts`, `minMint`, and sends LP tokens to the user.
- Emits `LiquidityAdded` event.

### ✅ Result:
User receives USDC.4 LP tokens in their ZetaChain wallet.

---

## 🔁 Withdrawal Flow  
**Example**: Redeem USDC.4 on ZetaChain → Receive native USDC on Solana

### 1. User Action (on ZetaChain)
- Approves `FluidUSDCUniversal` contract to spend USDC.4.
- Calls `withdrawLiquidityAndBridge` with:
  - `receiver`: User’s Solana address (in bytes).
  - `lpAmount`: Amount of USDC.4 to redeem.
  - `targetZrc20`: ZRC-20 token to bridge to (e.g., USDC.SOL).
  - `minAmountOut`: Minimum USDC.SOL expected (slippage protection).
  - `revertOptions`: ZetaChain revert handling options.

### 2. `withdrawLiquidityAndBridge` Execution
- Validates `lpAmount`.
- Transfers USDC.4 from user to contract.
- Approves Curve Pool to spend USDC.4.
- Determines pool index: `IDX_SOL = 1`
- Calls `remove_liquidity_one_coin`, converting LP to USDC.SOL.
- Verifies `amountOut ≥ minAmountOut`.
- Emits `LiquidityRemoved` event.
- Calculates withdrawal gas fee via `IZRC20(targetZrc20).withdrawGasFee()`.
- Approves ZetaChain Gateway to spend USDC.SOL (+ fee).
- Calls `gateway.withdraw` to send USDC.SOL to Solana address.

### 3. ZetaChain Actions
- Gateway burns USDC.SOL from contract’s balance.
- Initiates cross-chain transfer.
- Native USDC is released to user’s Solana wallet.

### ✅ Result:
User successfully redeems USDC.4 on ZetaChain and receives native USDC on Solana.


### Notes:

- Universal.sol is the template contract found on ZetaChain's Documentation
- ICurveStableSwapNG.sol is the Interface for the FluidUSDC pool
- FluidUSDCUniversal.sol is the universal contract to interact with the FluidUSDC pool