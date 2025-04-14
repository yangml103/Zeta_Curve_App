import { useState } from "react";
import { ethers } from "ethers";
import { ADDRESSES } from "../constants/addresses";
import { ERC20_ABI, AXELAR_GATEWAY_ABI, AXELAR_GAS_SERVICE_ABI } from "../constants/abis";
import { parseUnits } from "../utils/formatters";

// Axelar Gas Service address
const AXELAR_GAS_SERVICE = "0x2d5d7d31F671F86C782533cc367F14109a082712";

export function useCrossChainTransfer(signer, chainId) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [txHash, setTxHash] = useState(null);
  const [success, setSuccess] = useState(false);

  const transferToken = async ({
    sourceChainId,
    destinationChainName,
    destinationAddress,
    amount,
    tokenSymbol = "USDC",
    estimateGas = true,
  }) => {
    try {
      setLoading(true);
      setError(null);
      setTxHash(null);
      setSuccess(false);

      if (!signer) {
        throw new Error("Wallet not connected");
      }

      // Get the correct Chain key for Axelar
      let sourceChainKey;
      let destinationChainKey;
      switch (chainId) {
        case 1:
          sourceChainKey = "ethereum";
          break;
        case 137:
          sourceChainKey = "polygon";
          break;
        case 43114:
          sourceChainKey = "avalanche";
          break;
        case 42161:
          sourceChainKey = "arbitrum";
          break;
        case 10:
          sourceChainKey = "optimism";
          break;
        case 8453:
          sourceChainKey = "base";
          break;
        default:
          throw new Error("Source chain not supported");
      }

      switch (destinationChainName.toLowerCase()) {
        case "ethereum":
          destinationChainKey = "ethereum";
          break;
        case "polygon":
          destinationChainKey = "polygon";
          break;
        case "avalanche":
          destinationChainKey = "avalanche";
          break;
        case "arbitrum":
          destinationChainKey = "arbitrum";
          break;
        case "optimism":
          destinationChainKey = "optimism";
          break;
        case "base":
          destinationChainKey = "base";
          break;
        default:
          throw new Error("Destination chain not supported");
      }

      // Get the current chain's configuration
      let sourceChainConfig;
      switch (chainId) {
        case 1:
          sourceChainConfig = ADDRESSES.ETHEREUM;
          break;
        case 137:
          sourceChainConfig = ADDRESSES.POLYGON;
          break;
        case 43114:
          sourceChainConfig = ADDRESSES.AVALANCHE;
          break;
        case 42161:
          sourceChainConfig = ADDRESSES.ARBITRUM;
          break;
        case 10:
          sourceChainConfig = ADDRESSES.OPTIMISM;
          break;
        case 8453:
          sourceChainConfig = ADDRESSES.BASE;
          break;
        default:
          throw new Error("Current chain not supported");
      }

      // Get the token contract
      const tokenContract = new ethers.Contract(
        sourceChainConfig.USDC,
        ERC20_ABI,
        signer
      );

      // Get token decimals
      const decimals = await tokenContract.decimals();
      const amountInWei = parseUnits(amount, decimals);

      // Check user balance
      const userAddress = await signer.getAddress();
      const balance = await tokenContract.balanceOf(userAddress);
      if (balance.lt(amountInWei)) {
        throw new Error(`Insufficient ${tokenSymbol} balance`);
      }

      // Approve Gateway to spend tokens
      const gatewayContract = new ethers.Contract(
        sourceChainConfig.GATEWAY,
        AXELAR_GATEWAY_ABI,
        signer
      );

      console.log(`Approving gateway (${sourceChainConfig.GATEWAY}) to spend ${amount} ${tokenSymbol}`);
      const approveTx = await tokenContract.approve(
        sourceChainConfig.GATEWAY,
        amountInWei
      );
      await approveTx.wait();
      console.log("Approval confirmed");

      // Estimate gas fee (optional in a real implementation)
      const gasAmount = estimateGas ? ethers.utils.parseEther("0.0025") : 0; // This is a simplified estimate

      // Create gas service contract if estimating gas
      let gasServiceContract;
      if (estimateGas) {
        gasServiceContract = new ethers.Contract(
          AXELAR_GAS_SERVICE,
          AXELAR_GAS_SERVICE_ABI,
          signer
        );
      }

      // Send token cross-chain
      console.log(
        `Sending ${amount} ${tokenSymbol} from ${sourceChainKey} to ${destinationChainKey} at address ${destinationAddress}`
      );

      let tx;
      if (estimateGas) {
        // Pay for gas and send token in one transaction
        tx = await gatewayContract.sendToken(
          destinationChainKey,
          destinationAddress,
          tokenSymbol,
          amountInWei,
          { value: gasAmount }
        );
      } else {
        // Send token without paying for gas
        tx = await gatewayContract.sendToken(
          destinationChainKey,
          destinationAddress,
          tokenSymbol,
          amountInWei
        );
      }

      console.log("Transaction sent:", tx.hash);
      setTxHash(tx.hash);

      // Wait for transaction to be confirmed
      await tx.wait();
      console.log("Transaction confirmed!");
      setSuccess(true);

      return {
        success: true,
        txHash: tx.hash,
      };
    } catch (err) {
      console.error("Error in cross-chain transfer:", err);
      setError(err.message || "Failed to complete transfer");
      return {
        success: false,
        error: err.message || "Failed to complete transfer",
      };
    } finally {
      setLoading(false);
    }
  };

  return {
    transferToken,
    loading,
    error,
    txHash,
    success,
  };
} 