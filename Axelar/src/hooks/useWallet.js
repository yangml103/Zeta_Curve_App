import { useState, useEffect } from "react";
import { ethers } from "ethers";
import { CHAIN_IDS, CHAIN_NAMES } from "../constants/addresses";

export function useWallet() {
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [connecting, setConnecting] = useState(false);
  const [error, setError] = useState(null);
  const [chainName, setChainName] = useState(null);

  const connectWallet = async () => {
    if (!window.ethereum) {
      setError(
        "No Ethereum wallet found. Please install MetaMask or another wallet."
      );
      return;
    }

    try {
      setConnecting(true);
      await window.ethereum.request({ method: "eth_requestAccounts" });
      const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
      const web3Signer = web3Provider.getSigner();
      const address = await web3Signer.getAddress();
      const network = await web3Provider.getNetwork();

      setProvider(web3Provider);
      setSigner(web3Signer);
      setAccount(address);
      setChainId(network.chainId);
      setChainName(CHAIN_NAMES[network.chainId] || "Unknown Chain");
      setError(null);
    } catch (err) {
      console.error("Error connecting wallet:", err);
      setError(err.message);
    } finally {
      setConnecting(false);
    }
  };

  const switchToChain = async (targetChainId) => {
    if (!window.ethereum) return;

    try {
      await window.ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: `0x${targetChainId.toString(16)}` }],
      });
    } catch (error) {
      console.error("Error switching chain:", error);
      
      // If chain is not added, add it
      if (error.code === 4902) {
        await addChain(targetChainId);
      } else {
        setError(`Error switching chain: ${error.message}`);
      }
    }
  };

  const addChain = async (targetChainId) => {
    // This is a simplified version. You would need to add complete chain details for each chain.
    const chainDetails = {
      [CHAIN_IDS.ETHEREUM]: {
        chainId: `0x${CHAIN_IDS.ETHEREUM.toString(16)}`,
        chainName: "Ethereum Mainnet",
        nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
        rpcUrls: ["https://ethereum.publicnode.com"],
        blockExplorerUrls: ["https://etherscan.io/"],
      },
      [CHAIN_IDS.POLYGON]: {
        chainId: `0x${CHAIN_IDS.POLYGON.toString(16)}`,
        chainName: "Polygon Mainnet",
        nativeCurrency: { name: "MATIC", symbol: "MATIC", decimals: 18 },
        rpcUrls: ["https://polygon-rpc.com/"],
        blockExplorerUrls: ["https://polygonscan.com/"],
      },
      [CHAIN_IDS.AVALANCHE]: {
        chainId: `0x${CHAIN_IDS.AVALANCHE.toString(16)}`,
        chainName: "Avalanche C-Chain",
        nativeCurrency: { name: "AVAX", symbol: "AVAX", decimals: 18 },
        rpcUrls: ["https://api.avax.network/ext/bc/C/rpc"],
        blockExplorerUrls: ["https://snowtrace.io/"],
      },
    };

    if (!chainDetails[targetChainId]) {
      setError(`Chain ${targetChainId} configuration not available`);
      return;
    }

    try {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [chainDetails[targetChainId]],
      });
    } catch (error) {
      console.error("Error adding chain:", error);
      setError(`Error adding chain: ${error.message}`);
    }
  };

  // Listen for account and chain changes
  useEffect(() => {
    if (!window.ethereum) return;

    const handleAccountsChanged = (accounts) => {
      if (accounts.length > 0) {
        setAccount(accounts[0]);
      } else {
        setAccount(null);
        setSigner(null);
      }
    };

    const handleChainChanged = (chainIdHex) => {
      const newChainId = parseInt(chainIdHex, 16);
      setChainId(newChainId);
      setChainName(CHAIN_NAMES[newChainId] || "Unknown Chain");
    };

    window.ethereum.on("accountsChanged", handleAccountsChanged);
    window.ethereum.on("chainChanged", handleChainChanged);

    return () => {
      window.ethereum.removeListener("accountsChanged", handleAccountsChanged);
      window.ethereum.removeListener("chainChanged", handleChainChanged);
    };
  }, []);

  return {
    account,
    provider,
    signer,
    chainId,
    chainName,
    connecting,
    error,
    connectWallet,
    switchToChain,
    isConnected: !!account,
  };
} 