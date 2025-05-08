import { getAddress } from "ethers";

const addressesToTest = [
  {
    description: "ZetaChain Gateway (Problematic)",
    address: "0x5FCEdF1b07443bE58c039144872e32679733DE7E"
  },
  {
    description: "Vitalik's Address (Checksummed)",
    address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  },
  {
    description: "Vitalik's Address (Lowercase)",
    address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
  }
];

addressesToTest.forEach(test => {
  console.log(`\nTesting: ${test.description}`);
  console.log(`Input address: ${test.address}`);
  try {
    const checksummedAddress = getAddress(test.address);
    console.log(`Output from getAddress: ${checksummedAddress}`);
    if (test.address.toLowerCase() === checksummedAddress.toLowerCase() && test.address !== checksummedAddress && test.address === test.address.toLowerCase()) {
      console.log("Successfully checksummed by getAddress.");
    } else if (test.address === checksummedAddress) {
      console.log("Address was already correctly checksummed.");
    } else {
      console.log("getAddress produced a different address or an unexpected result.");
    }
  } catch (error) {
    console.error("Error calling ethers.getAddress():", error);
  }
}); 