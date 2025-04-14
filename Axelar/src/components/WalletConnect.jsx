import React from "react";
import { useWallet } from "../context/WalletContext";
import { shortenAddress } from "../utils/formatters";

const WalletConnect = () => {
  const { 
    account, 
    chainId, 
    chainName,
    connecting, 
    error, 
    connectWallet, 
    isConnected 
  } = useWallet();

  return (
    <div className="flex items-center">
      {chainId && chainName && (
        <span className="mr-4 px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm hidden md:inline-block">
          {chainName}
        </span>
      )}

      {isConnected ? (
        <div className="flex items-center">
          <span className="px-4 py-2 bg-green-50 text-green-700 rounded-md font-medium">
            {shortenAddress(account)}
          </span>
        </div>
      ) : (
        <button
          onClick={connectWallet}
          disabled={connecting}
          className={`px-4 py-2 rounded-md text-white font-medium ${
            connecting
              ? "bg-gray-400 cursor-not-allowed"
              : "bg-blue-600 hover:bg-blue-700"
          }`}
        >
          {connecting ? "Connecting..." : "Connect Wallet"}
        </button>
      )}

      {error && (
        <div className="mt-2 text-red-500 text-sm">
          {error}
        </div>
      )}
    </div>
  );
};

export default WalletConnect; 