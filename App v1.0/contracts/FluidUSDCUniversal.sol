// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// import { Universal, MessageContext, RevertOptions, CallOptions } from "./Universal.sol"; // Removed import
import "./interface/ICurveStableSwapNG.sol"; // Adjusted path
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IZRC20 } from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import { GatewayZEVM } from "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import { RevertOptions } from "@zetachain/protocol-contracts/contracts/Revert.sol"; // Added import

// --- Structs (from ZetaChain Universal example) ---
/// @dev Struct to store context information about the cross-chain message.
struct MessageContext {
    bytes sender; // The address of the sender on the source chain.
    uint256 sourceChainId; // The chain ID of the source chain.
    address destination; // The destination address of the message (this contract).
    address gateway; // The address of the gateway contract.
    address zrc20; // The address of the ZRC-20 token involved in the call.
    uint256 gasLimit; // The gas limit for the call.
}

/// @dev Struct to store options for making calls.
struct CallOptions {
    uint8 callType; // The type of call to make.
    bytes to; // The recipient address for the call.
    uint256 value; // The value to send with the call.
    bytes data; // The data to send with the call.
    uint256 gasLimit; // The gas limit for the call.
}

// --- Contract ---
contract FluidUSDCUniversal { // Removed inheritance from Universal
    using SafeERC20 for IERC20;

    // --- ZetaChain Gateway ---
    GatewayZEVM public immutable gateway;

    // --- Constants ---
    // Curve Pool
    address public immutable POOL = 0xCA4b0396064F40640F1d9014257a99aB3336C724;
    // ZRC-20 Tokens 
    address public immutable USDC_ARB = 0x0327f0660525b15Cdb8f1f5FBF0dD7Cd5Ba182aD; 
    address public immutable USDC_SOL = 0x8344d6f84d26f998fa070BbEA6D2E15E359e2641;
    address public immutable USDC_BASE = 0x96152E6180E085FA57c7708e18AF8F05e37B479D;
    address public immutable USDC_AVAX = 0xa52Ad01A1d62b408fFe06C2467439251da61E4a9;
    // Curve Pool Token Indices (Based on github repo README - https://github.com/brewmaster012/FluidUSDC?tab=readme-ov-file)
    int128 private constant IDX_ARB = 0;
    int128 private constant IDX_SOL = 1;
    int128 private constant IDX_BASE = 2;
    int128 private constant IDX_AVAX = 3;
    // LP Token (USDC.4) - the token deployed at POOL address
    address public immutable LP_TOKEN = POOL;

    // Command identifier for deposit message
    uint8 public constant CMD_DEPOSIT_ADD_LIQUIDITY = 0;

    // --- Events ---
    event LiquidityAdded(address indexed zrc20In, uint256 amountIn, address indexed lpReceiver, uint256 lpAmountMinted);
    event LiquidityRemoved(address indexed lpTokenBurner, uint256 lpAmountBurned, address indexed zrc20Out, uint256 amountOut);


    // --- Errors ---
    error UnsupportedZRC20(address token);
    error InvalidCommand(uint8 command);
    error MintFailed();
    error RemoveLiquidityFailed();
    error InvalidLPAmount();

    // --- Modifier ---
    modifier onlyGateway() {
        require(msg.sender == address(gateway), "caller is not the gateway");
        _;
    }

    // --- Constructor ---
    constructor(address payable gateway_) {
        gateway = GatewayZEVM(gateway_);
       // POOL, USDC addresses are immutable and set via constants above
    }

    // --- External Functions: Overrides ---

    /**
     * @notice Handles incoming ZRC-20 deposits via ZetaChain Gateway.
     * @dev Decodes the message to determine action (e.g., add liquidity).
     *      Currently supports adding liquidity (cmd=0).
     * @param context Message context from the gateway.
     * @param zrc20In The address of the ZRC-20 token deposited (USDC.ARB, .SOL, .BASE, .AVAX).
     * @param amount The amount of ZRC-20 token deposited.
     * @param message Arbitrary message bytes containing command and parameters.
     *                Expected format for deposit: abi.encode(uint8 cmd, uint256 minMint)
     */
    function onCall(
        MessageContext calldata context,
        address zrc20In,
        uint256 amount,
        bytes calldata message
    ) external /* override removed */ onlyGateway { // Removed override keyword
        (uint8 cmd, uint256 minMintOrAmount) = abi.decode(message, (uint8, uint256)); // Reuse variable name

        if (cmd == CMD_DEPOSIT_ADD_LIQUIDITY) {
            _addLiquidity(zrc20In, amount, minMintOrAmount, address(uint160(bytes20(context.sender)))); // Converted context.sender
        } else {
            revert InvalidCommand(cmd);
        }
        // Note: Original HelloEvent emission removed
    }

    // --- External Functions: Withdrawals ---

     /**
      * @notice Withdraws liquidity from the Curve pool and sends native USDC back to a destination chain.
      * @dev Burns LP tokens (USDC.4), removes liquidity for one ZRC-20 (USDC.ARB, .SOL, .BASE, .AVAX),
      *      and calls gateway.withdraw to send native USDC.
      * @param receiver The recipient address on the destination chain (bytes format).
      * @param lpAmount The amount of LP tokens (USDC.4) to burn.
      * @param targetZrc20 The desired ZRC-20 output (USDC.ARB, .SOL, .BASE, .AVAX).
      * @param minAmountOut Minimum amount of targetZrc20 to receive.
      * @param revertOptions Options for handling potential reverts on the destination chain.
      */
     function withdrawLiquidityAndBridge(
         bytes memory receiver,
         uint256 lpAmount,
         address targetZrc20,
         uint256 minAmountOut,
         RevertOptions memory revertOptions // RevertOptions struct is now defined locally
     ) external {
         if (lpAmount == 0) revert InvalidLPAmount();

         // 1. Burn LP tokens from the user
         IERC20(LP_TOKEN).safeTransferFrom(msg.sender, address(this), lpAmount);

         // 2. Approve pool to spend LP tokens held by this contract
         IERC20(LP_TOKEN).safeIncreaseAllowance(POOL, lpAmount); 

         // 3. Determine index for remove_liquidity_one_coin
         int128 coinIndex;
         if (targetZrc20 == USDC_ARB) {       
             coinIndex = IDX_ARB;
         } else if (targetZrc20 == USDC_SOL) {
             coinIndex = IDX_SOL;
         } else if (targetZrc20 == USDC_BASE) {
             coinIndex = IDX_BASE;
         } else if (targetZrc20 == USDC_AVAX) { 
             coinIndex = IDX_AVAX;
         } else {
             revert UnsupportedZRC20(targetZrc20);
         }

         // 4. Remove liquidity for the target ZRC-20
         uint256 amountOut = ICurveStableSwapNG(POOL).remove_liquidity_one_coin(
             lpAmount,
             coinIndex,
             minAmountOut,
             address(this) // Receive the ZRC-20 in this contract
         );
         if (amountOut < minAmountOut) revert RemoveLiquidityFailed(); // Check slippage protection


         emit LiquidityRemoved(msg.sender, lpAmount, targetZrc20, amountOut);

         // 5. Prepare for gateway withdrawal (gas calculation + approvals)
         (address gasZRC20, uint256 gasFee) = IZRC20(targetZrc20).withdrawGasFee();
         uint256 totalAmountForApproval = targetZrc20 == gasZRC20 ? amountOut + gasFee : amountOut;

         // Approve the gateway to spend the received ZRC-20 for withdrawal amount
         IERC20(targetZrc20).safeIncreaseAllowance(address(gateway), totalAmountForApproval);

         // Handle separate gas token if necessary (mirroring Universal.sol withdraw)
         if (targetZrc20 != gasZRC20) {
             // This contract must hold gasZRC20 to pay the fee.

             IERC20(gasZRC20).safeIncreaseAllowance(address(gateway), gasFee);
             // Ensure this contract has sufficient gasZRC20 balance before calling withdraw.
         }

         // 6. Call gateway to withdraw ZRC-20 and send native USDC
         // The gateway handles burning the ZRC20 from this contract.
         gateway.withdraw(receiver, amountOut, targetZrc20, revertOptions);
     }

    // --- Internal Functions ---

    /**
     * @dev Internal function to add liquidity to the Curve pool.
     * @param zrc20In The ZRC-20 token being deposited (USDC.ARB, .SOL, .BASE, .AVAX).
     * @param amount The amount of ZRC-20 token.
     * @param minMint Minimum amount of LP tokens expected.
     * @param lpReceiver The address to receive the minted LP tokens.
     */
    function _addLiquidity(
        address zrc20In,
        uint256 amount,
        uint256 minMint,
        address lpReceiver
    ) internal {
        // Approve the pool to spend the ZRC-20 token held by this contract
        IERC20(zrc20In).safeIncreaseAllowance(POOL, amount); 

        uint256[4] memory amounts; // N=4 for the pool
        if (zrc20In == USDC_ARB) {        // Added ARB check
             amounts[uint256(int256(IDX_ARB))] = amount;
        } else if (zrc20In == USDC_SOL) {
            amounts[uint256(int256(IDX_SOL))] = amount;
        } else if (zrc20In == USDC_BASE) {
             amounts[uint256(int256(IDX_BASE))] = amount;
        } else if (zrc20In == USDC_AVAX) { // Added AVAX check
             amounts[uint256(int256(IDX_AVAX))] = amount;
        } else {
            revert UnsupportedZRC20(zrc20In);
        }

        // Call add_liquidity on the Curve pool
        uint256 lpOut = ICurveStableSwapNG(POOL).add_liquidity(
            amounts,
            minMint,
            lpReceiver // Send LP tokens directly to the original sender's address on ZetaChain
        );

        if (lpOut == 0 || lpOut < minMint) revert MintFailed(); // Check mint amount

        emit LiquidityAdded(zrc20In, amount, lpReceiver, lpOut);
    }

} 