export const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function approve(address, uint256) returns (bool)",
  "function transfer(address, uint256) returns (bool)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
  "function name() view returns (string)",
];

export const AXELAR_GATEWAY_ABI = [
  "function sendToken(string calldata destinationChain, string calldata destinationAddress, string calldata symbol, uint256 amount) external",
  "function callContract(string calldata destinationChain, string calldata contractAddress, bytes calldata payload) external",
  "function callContractWithToken(string calldata destinationChain, string calldata contractAddress, bytes calldata payload, string calldata symbol, uint256 amount) external",
  "function validateContractCall(bytes32 commandId, string calldata sourceChain, string calldata sourceAddress, bytes32 payloadHash) external returns (bool)",
  "function validateContractCallAndMint(bytes32 commandId, string calldata sourceChain, string calldata sourceAddress, bytes32 payloadHash, string calldata symbol, uint256 amount) external returns (bool)",
];

export const AXELAR_GAS_SERVICE_ABI = [
  "function payNativeGasForContractCall(address sender, string calldata destinationChain, string calldata destinationAddress, bytes calldata payload, address refundAddress) external payable",
  "function payNativeGasForContractCallWithToken(address sender, string calldata destinationChain, string calldata destinationAddress, bytes calldata payload, string calldata symbol, uint256 amount, address refundAddress) external payable",
]; 