import React from "react";
import { WalletProvider } from "./context/WalletContext";
import WalletConnect from "./components/WalletConnect";
import CrossChainBalances from "./components/CrossChainBalances";
import CrossChainTransfer from "./components/CrossChainTransfer";

const App = () => {
  return (
    <WalletProvider>
      <div className="min-h-screen bg-gray-100">
        <header className="bg-white shadow-md">
          <div className="container mx-auto px-4 py-4">
            <div className="flex flex-col md:flex-row items-center justify-between">
              <h1 className="text-2xl font-bold text-blue-800 mb-4 md:mb-0">
                FluidUSDC Axelar
              </h1>
              <WalletConnect />
            </div>
          </div>
        </header>

        <main className="container mx-auto px-4 py-8">
          <div className="bg-white shadow-md rounded-lg p-6 mb-8">
            <h2 className="text-xl font-bold mb-4">
              Cross-Chain USDC Solution
            </h2>
            <p className="text-gray-700">
              FluidUSDC Axelar enables seamless transfer of USDC between Ethereum, Polygon, Avalanche, and other chains using Axelar's secure cross-chain communication protocol, with minimal fees.
            </p>
          </div>

          {/* Cross-Chain Balance Widget */}
          <CrossChainBalances />

          {/* Cross-Chain Transfer Widget */}
          <CrossChainTransfer />
        </main>

        <footer className="bg-gray-800 text-white py-6">
          <div className="container mx-auto px-4 text-center">
            <p>USE THIS AT YOUR OWN RISK!!</p>
            <p className="mt-2 text-gray-400">
              FluidUSDC Axelar is an experimental application built with Axelar Network.
            </p>
          </div>
        </footer>
      </div>
    </WalletProvider>
  );
};

export default App; 