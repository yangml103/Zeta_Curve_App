// This is a simplified deployment script for illustration purposes
// In a real-world scenario, you would use Hardhat, Truffle, or Foundry

const { ethers } = require('ethers');
const fs = require('fs');

// Load contract ABIs
const AxelarUSDCSenderABI = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCSender.json')).abi;
const AxelarUSDCReceiverABI = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCReceiver.json')).abi;
const AxelarUSDCPoolABI = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCPool.json')).abi;

// Load contract bytecode
const AxelarUSDCSenderBytecode = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCSender.json')).bytecode;
const AxelarUSDCReceiverBytecode = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCReceiver.json')).bytecode;
const AxelarUSDCPoolBytecode = JSON.parse(fs.readFileSync('./artifacts/AxelarUSDCPool.json')).bytecode;

// Chain configuration
const chainConfig = {
  ethereum: {
    rpc: 'https://ethereum.publicnode.com',
    chainId: 1,
    axelarGateway: '0x4F4495243837681061C4743b74B3eEdf548D56A5',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  },
  polygon: {
    rpc: 'https://polygon-rpc.com',
    chainId: 137,
    axelarGateway: '0x6f015F16De9fC8791b234eF68D486d2bF203FBA8',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
  },
  avalanche: {
    rpc: 'https://api.avax.network/ext/bc/C/rpc',
    chainId: 43114,
    axelarGateway: '0x5029C0EFf6C34351a0CEc334542cDb22c7928f78',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
  },
  arbitrum: {
    rpc: 'https://arb1.arbitrum.io/rpc',
    chainId: 42161,
    axelarGateway: '0xe432150cce91c13a887f7D836923d5597adD8E31',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
  },
  optimism: {
    rpc: 'https://mainnet.optimism.io',
    chainId: 10,
    axelarGateway: '0xe432150cce91c13a887f7D836923d5597adD8E31',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0x7F5c764cBc14f9669B88837ca1490cCa17c31607',
  },
  base: {
    rpc: 'https://mainnet.base.org',
    chainId: 8453,
    axelarGateway: '0xe432150cce91c13a887f7D836923d5597adD8E31',
    axelarGasService: '0x2d5d7d31F671F86C782533cc367F14109a082712',
    usdc: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  }
};

// Deploy contracts
async function deployContracts(network, privateKey) {
  try {
    console.log(`Deploying contracts to ${network}...`);
    
    const config = chainConfig[network];
    if (!config) {
      throw new Error(`Network ${network} not supported`);
    }
    
    // Setup provider and wallet
    const provider = new ethers.providers.JsonRpcProvider(config.rpc);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`Deploying from address: ${wallet.address}`);
    
    // Deploy AxelarUSDCSender
    console.log('Deploying AxelarUSDCSender...');
    const senderFactory = new ethers.ContractFactory(
      AxelarUSDCSenderABI,
      AxelarUSDCSenderBytecode,
      wallet
    );
    const senderContract = await senderFactory.deploy(
      config.axelarGateway,
      config.axelarGasService,
      config.usdc
    );
    await senderContract.deployed();
    console.log(`AxelarUSDCSender deployed to: ${senderContract.address}`);
    
    // Deploy AxelarUSDCReceiver
    console.log('Deploying AxelarUSDCReceiver...');
    const receiverFactory = new ethers.ContractFactory(
      AxelarUSDCReceiverABI,
      AxelarUSDCReceiverBytecode,
      wallet
    );
    const receiverContract = await receiverFactory.deploy(
      config.axelarGateway,
      config.axelarGasService,
      config.usdc
    );
    await receiverContract.deployed();
    console.log(`AxelarUSDCReceiver deployed to: ${receiverContract.address}`);
    
    // Deploy AxelarUSDCPool
    console.log('Deploying AxelarUSDCPool...');
    const poolFactory = new ethers.ContractFactory(
      AxelarUSDCPoolABI,
      AxelarUSDCPoolBytecode,
      wallet
    );
    const poolContract = await poolFactory.deploy(
      config.axelarGateway,
      config.axelarGasService,
      config.usdc
    );
    await poolContract.deployed();
    console.log(`AxelarUSDCPool deployed to: ${poolContract.address}`);
    
    // Get FluidUSDC address from pool
    const fluidUSDCAddress = await poolContract.fluidUSDC();
    console.log(`FluidUSDC deployed to: ${fluidUSDCAddress}`);
    
    // Save deployment addresses
    saveDeployment(network, {
      sender: senderContract.address,
      receiver: receiverContract.address,
      pool: poolContract.address,
      fluidUSDC: fluidUSDCAddress,
    });
    
    return {
      sender: senderContract,
      receiver: receiverContract,
      pool: poolContract,
      fluidUSDC: fluidUSDCAddress,
    };
  } catch (error) {
    console.error(`Error deploying contracts to ${network}:`, error);
    throw error;
  }
}

// Configure contracts post-deployment
async function configureContracts(network, contracts, otherDeployments) {
  try {
    console.log(`Configuring contracts on ${network}...`);
    const { sender, receiver, pool } = contracts;
    
    // Set trusted source chains and senders on the receiver
    // Example: Trust Ethereum sender if we're on Polygon
    if (network !== 'ethereum') {
      await receiver.setTrustedSourceChain('ethereum', true);
      await receiver.setTrustedSender('ethereum', otherDeployments.ethereum.sender, true);
    }
    
    // Set trusted source chains and senders on the pool
    if (network !== 'ethereum') {
      await pool.setSupportedChain('ethereum', true);
      await pool.setTrustedSender('ethereum', otherDeployments.ethereum.pool, true);
    }
    
    // Add more configurations as needed for other chains
    
    console.log(`Contracts on ${network} configured successfully`);
  } catch (error) {
    console.error(`Error configuring contracts on ${network}:`, error);
    throw error;
  }
}

// Save deployment addresses to a file
function saveDeployment(network, addresses) {
  let deployments = {};
  
  // Try to read existing deployments
  try {
    const data = fs.readFileSync('./deployments.json', 'utf8');
    deployments = JSON.parse(data);
  } catch (error) {
    // File doesn't exist or is invalid, start with empty object
  }
  
  // Add new deployment
  deployments[network] = {
    ...addresses,
    timestamp: new Date().toISOString(),
  };
  
  // Write to file
  fs.writeFileSync('./deployments.json', JSON.stringify(deployments, null, 2));
  console.log(`Deployment addresses saved to deployments.json`);
}

// Main function to deploy to all networks
async function main() {
  // Read private key from environment variable or command line
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('PRIVATE_KEY environment variable is required');
  }
  
  // Deploy to all networks or specific ones
  const networksToDeploy = process.argv[2] ? [process.argv[2]] : ['ethereum', 'polygon', 'avalanche'];
  
  const deployments = {};
  
  // First pass: deploy contracts to all networks
  for (const network of networksToDeploy) {
    deployments[network] = await deployContracts(network, privateKey);
  }
  
  // Second pass: configure contracts with addresses from other networks
  for (const network of networksToDeploy) {
    await configureContracts(network, deployments[network], deployments);
  }
  
  console.log('Deployment completed successfully!');
}

// Run the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 