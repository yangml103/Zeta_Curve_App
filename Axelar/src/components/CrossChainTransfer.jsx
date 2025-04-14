import React, { useState } from "react";
import { useWallet } from "../context/WalletContext";
import { useCrossChainTransfer } from "../hooks/useCrossChainTransfer";
import { CHAIN_NAMES } from "../constants/addresses";

const CrossChainTransfer = () => {
  const { account, signer, chainId, chainName } = useWallet();
  const { transferToken, loading, error, txHash, success } = useCrossChainTransfer(signer, chainId);

  const [amount, setAmount] = useState("");
  const [recipient, setRecipient] = useState("");
  const [destinationChain, setDestinationChain] = useState("");
  const [includeGas, setIncludeGas] = useState(true);

  const handleAmountChange = (e) => {
    const value = e.target.value;
    if (value === "" || /^\d*\.?\d*$/.test(value)) {
      setAmount(value);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!amount || !destinationChain || !recipient) {
      alert("Please fill in all fields");
      return;
    }

    await transferToken({
      sourceChainId: chainId,
      destinationChainName: destinationChain,
      destinationAddress: recipient,
      amount,
      tokenSymbol: "USDC",
      estimateGas: includeGas,
    });
  };

  const availableDestinationChains = Object.entries(CHAIN_NAMES)
    .filter(([id]) => parseInt(id) !== chainId)
    .map(([id, name]) => ({ id: parseInt(id), name }));

  if (!account) {
    return (
      <div className="bg-white shadow-md rounded-lg p-6 mb-6">
        <h2 className="text-xl font-bold mb-4">Cross-Chain Transfer</h2>
        <div className="text-center py-8">
          <p className="text-gray-500">Connect your wallet to make cross-chain transfers</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white shadow-md rounded-lg p-6 mb-6">
      <h2 className="text-xl font-bold mb-4">Cross-Chain Transfer</h2>
      
      {success ? (
        <div className="bg-green-50 p-4 rounded-md mb-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <p className="text-sm font-medium text-green-800">
                Transfer successful!
              </p>
              {txHash && (
                <p className="mt-2 text-sm text-green-700">
                  Transaction hash: {txHash.substring(0, 10)}...
                </p>
              )}
              <button 
                onClick={() => {
                  setAmount("");
                  setRecipient("");
                  setDestinationChain("");
                }} 
                className="mt-2 text-sm font-medium text-green-600 hover:text-green-500"
              >
                Make another transfer
              </button>
            </div>
          </div>
        </div>
      ) : (
        <form onSubmit={handleSubmit}>
          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2">
              Source Chain
            </label>
            <div className="px-3 py-2 bg-gray-100 rounded-md">
              {chainName || "Unknown Chain"}
            </div>
            <p className="mt-1 text-xs text-gray-500">
              Your current connected blockchain network
            </p>
          </div>

          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="destinationChain">
              Destination Chain
            </label>
            <select
              id="destinationChain"
              value={destinationChain}
              onChange={(e) => setDestinationChain(e.target.value)}
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              required
            >
              <option value="">Select destination chain</option>
              {availableDestinationChains.map((chain) => (
                <option key={chain.id} value={chain.name}>
                  {chain.name}
                </option>
              ))}
            </select>
          </div>

          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="amount">
              Amount (USDC)
            </label>
            <input
              id="amount"
              type="text"
              value={amount}
              onChange={handleAmountChange}
              placeholder="0.00"
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              required
            />
          </div>

          <div className="mb-4">
            <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="recipient">
              Recipient Address
            </label>
            <input
              id="recipient"
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="0x..."
              className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
              required
            />
          </div>

          <div className="mb-4">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={includeGas}
                onChange={(e) => setIncludeGas(e.target.checked)}
                className="mr-2"
              />
              <span className="text-sm text-gray-700">
                Include gas payment for faster processing
              </span>
            </label>
          </div>

          {error && (
            <div className="mb-4 text-red-500 text-sm p-2 bg-red-50 rounded">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading || !destinationChain}
            className={`w-full py-2 px-4 rounded-md text-white font-medium ${
              loading || !destinationChain
                ? "bg-gray-400 cursor-not-allowed"
                : "bg-blue-600 hover:bg-blue-700"
            }`}
          >
            {loading ? "Processing..." : "Transfer USDC"}
          </button>
        </form>
      )}

      <div className="mt-4 text-xs text-gray-500">
        <p>
          Note: Cross-chain transfers typically take 3-15 minutes to complete
          depending on the source and destination chains.
        </p>
      </div>
    </div>
  );
};

export default CrossChainTransfer; 