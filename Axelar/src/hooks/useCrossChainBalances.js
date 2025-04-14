import { useState, useEffect } from "react";
import { ethers } from "ethers";
import { ADDRESSES, CHAIN_IDS } from "../constants/addresses";
import { ERC20_ABI } from "../constants/abis";
import { AxelarQueryAPI } from "@axelar-network/axelarjs-sdk";

export function useCrossChainBalances(account, provider, chainId, refreshTrigger = 0) {
  const [balances, setBalances] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [supportedChains, setSupportedChains] = useState([]);
  const [axelarApi, setAxelarApi] = useState(null);

  // Initialize Axelar Query API
  useEffect(() => {
    const initAxelarApi = async () => {
      try {
        const api = new AxelarQueryAPI({
          environment: 'mainnet',
        });
        setAxelarApi(api);
        
        // Get supported chains
        const chains = await api.getSupportedChains();
        setSupportedChains(chains);
      } catch (err) {
        console.error("Error initializing Axelar API:", err);
        setError("Failed to initialize Axelar API");
      }
    };
    
    initAxelarApi();
  }, []);

  // Fetch balances when account, provider, or refresh trigger changes
  useEffect(() => {
    if (!account || !provider || !axelarApi) {
      setBalances([]);
      return;
    }

    const fetchBalances = async () => {
      try {
        setLoading(true);
        setError(null);

        // Define USDC tokens to check on different chains
        const tokens = [
          {
            address: ADDRESSES.ETHEREUM.USDC,
            symbol: "USDC",
            name: "USD Coin (Ethereum)",
            network: "Ethereum",
            chainId: CHAIN_IDS.ETHEREUM,
          },
          {
            address: ADDRESSES.POLYGON.USDC,
            symbol: "USDC",
            name: "USD Coin (Polygon)",
            network: "Polygon",
            chainId: CHAIN_IDS.POLYGON,
          },
          {
            address: ADDRESSES.AVALANCHE.USDC,
            symbol: "USDC",
            name: "USD Coin (Avalanche)",
            network: "Avalanche",
            chainId: CHAIN_IDS.AVALANCHE,
          },
          {
            address: ADDRESSES.ARBITRUM.USDC,
            symbol: "USDC",
            name: "USD Coin (Arbitrum)",
            network: "Arbitrum",
            chainId: CHAIN_IDS.ARBITRUM,
          },
          {
            address: ADDRESSES.OPTIMISM.USDC,
            symbol: "USDC",
            name: "USD Coin (Optimism)",
            network: "Optimism",
            chainId: CHAIN_IDS.OPTIMISM,
          },
          {
            address: ADDRESSES.BASE.USDC,
            symbol: "USDC",
            name: "USD Coin (Base)",
            network: "Base",
            chainId: CHAIN_IDS.BASE,
          },
        ];

        // If we're on one of the supported chains, get that balance directly
        const currentChainToken = tokens.find(t => t.chainId === chainId);
        let results = [];

        if (currentChainToken) {
          try {
            const contract = new ethers.Contract(
              currentChainToken.address,
              ERC20_ABI,
              provider
            );

            const balance = await contract.balanceOf(account);
            const decimals = await contract.decimals();

            results.push({
              ...currentChainToken,
              balance,
              formattedBalance: parseFloat(
                ethers.utils.formatUnits(balance, decimals)
              ),
              decimals,
              currentChain: true,
            });
          } catch (err) {
            console.error(`Error fetching balance for ${currentChainToken.network}:`, err);
            results.push({
              ...currentChainToken,
              balance: ethers.BigNumber.from(0),
              formattedBalance: 0,
              decimals: 6,
              error: err.message,
              currentChain: true,
            });
          }
        }

        // Add other chains (these would typically require Axelar's API or cross-chain queries)
        // For demo purposes, we're simulating these with empty balances
        // In a real app, you might use Axelar's API or network-specific RPC calls
        
        const otherChains = tokens.filter(t => t.chainId !== chainId);
        const otherResults = otherChains.map(token => ({
          ...token,
          balance: ethers.BigNumber.from(0),
          formattedBalance: 0,
          decimals: 6,
          currentChain: false,
        }));

        results = [...results, ...otherResults];

        // Sort balances: non-zero balances first, then alphabetically by network
        const sortedBalances = results.sort((a, b) => {
          // First sort by current chain
          if (a.currentChain && !b.currentChain) return -1;
          if (!a.currentChain && b.currentChain) return 1;
          
          // Then sort by whether balance is zero
          if (a.formattedBalance > 0 && b.formattedBalance === 0) return -1;
          if (a.formattedBalance === 0 && b.formattedBalance > 0) return 1;

          // Then sort alphabetically by network
          return a.network.localeCompare(b.network);
        });

        setBalances(sortedBalances);
      } catch (err) {
        console.error("Error fetching cross-chain balances:", err);
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchBalances();
  }, [account, provider, chainId, refreshTrigger, axelarApi]);

  return { 
    balances, 
    loading, 
    error, 
    supportedChains 
  };
} 