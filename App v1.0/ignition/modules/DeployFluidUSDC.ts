import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ZETA_GATEWAY_ADDRESS_ATHENS3 = "0x5FCEdF1b07443bE58c039144872e32679733DE7E";

const FluidUSDCUniversalModule = buildModule("FluidUSDCUniversalModule", (m) => {
  const gatewayAddressParam = m.getParameter("gateway", ZETA_GATEWAY_ADDRESS_ATHENS3);

  const fluidUSDC = m.contract("FluidUSDCUniversal", [gatewayAddressParam]);

  return { fluidUSDC };
});

export default FluidUSDCUniversalModule;