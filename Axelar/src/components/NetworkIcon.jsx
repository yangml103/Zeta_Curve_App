import React from "react";

const NetworkIcon = ({ network }) => {
  // Define colors for different networks
  const networkColors = {
    Ethereum: "bg-blue-500",
    Polygon: "bg-purple-600",
    Avalanche: "bg-red-500",
    Fantom: "bg-blue-400",
    Arbitrum: "bg-blue-700",
    Optimism: "bg-red-600",
    Base: "bg-blue-900",
    Moonbeam: "bg-indigo-600",
    ZetaChain: "bg-purple-800",
    Unknown: "bg-gray-500",
  };

  // Get the background color based on the network
  const bgColor = networkColors[network] || networkColors.Unknown;

  // Get the first letter of the network name
  const letter = network.charAt(0);

  return (
    <div
      className={`flex items-center justify-center w-8 h-8 rounded-full text-white font-bold ${bgColor}`}
      title={network}
    >
      {letter}
    </div>
  );
};

export default NetworkIcon; 