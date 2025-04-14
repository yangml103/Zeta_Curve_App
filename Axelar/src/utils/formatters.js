import { ethers } from "ethers";

export const formatUnits = (value, decimals = 18) => {
  return parseFloat(ethers.utils.formatUnits(value, decimals));
};

export const parseUnits = (value, decimals = 18) => {
  return ethers.utils.parseUnits(value.toString(), decimals);
};

export const shortenAddress = (address, chars = 4) => {
  if (!address) return "";
  return `${address.substring(0, chars + 2)}...${address.substring(
    address.length - chars
  )}`;
}; 