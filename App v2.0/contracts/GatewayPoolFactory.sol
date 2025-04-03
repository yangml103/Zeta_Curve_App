// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zeta.sol";
import "./ZetaGatewayStablecoinPool.sol";
import "./OmniUSDT.sol";

/**
 * @title GatewayPoolFactory
 * @dev Factory contract for creating new ZetaGatewayStablecoinPool instances.
 * This allows users to create pools with different tokens using ZetaChain's Gateway.
 */
contract GatewayPoolFactory is Ownable {
    // Default parameters
    uint256 public defaultAmplificationParameter = 2000; // A = 20
    uint256 public defaultSwapFee = 4; // 0.04%
    uint256 public defaultAdminFee = 5000; // 50% of swap fees
    
    // ZetaChain token for cross-chain messaging
    address public zetaToken;
    
    // Mapping of created pools
    mapping(address => bool) public isPool;
    address[] public allPools;
    
    // Mapping of supported chains
    mapping(uint256 => bool) public supportedChains;
    
    // Events
    event PoolCreated(
        address indexed pool,
        address indexed zetaToken,
        address[] tokens,
        uint256 amplificationParameter,
        uint256 fee,
        uint256 adminFee
    );
    
    event PoolInitialized(
        address indexed pool,
        address indexed factory
    );
    
    event DefaultParametersUpdated(
        uint256 amplificationParameter,
        uint256 swapFee,
        uint256 adminFee
    );
    
    event ChainSupported(uint256 chainId, bool supported);

    /**
     * @dev Constructor to initialize the factory
     * @param _zetaToken Address of the Zeta Token
     */
    constructor(address _zetaToken) Ownable(msg.sender) {
        require(_zetaToken != address(0), "Invalid Zeta Token address");
        zetaToken = _zetaToken;
    }
    
    /**
     * @dev Set supported chains
     * @param chainId Chain ID to set support for
     * @param supported Whether the chain is supported
     */
    function setSupportedChain(uint256 chainId, bool supported) external onlyOwner {
        supportedChains[chainId] = supported;
        emit ChainSupported(chainId, supported);
    }
    
    /**
     * @dev Create a new stablecoin pool
     * @param _tokens Array of ZRC20 token addresses to include in the pool
     * @param _name Name of the pool
     * @param _symbol Symbol of the pool
     * @param _fee Fee in basis points (e.g., 4 = 0.04%)
     * @param _adminFee Admin fee in basis points (e.g., 50 = 0.5%)
     * @param _zetaToken Address of the ZETA token
     */
    function createPool(
        address[] calldata _tokens,
        string calldata _name,
        string calldata _symbol,
        uint256 _fee,
        uint256 _adminFee,
        address _zetaToken
    ) external returns (address) {
        require(_tokens.length >= 2, "Pool must have at least 2 tokens");
        require(_fee <= MAX_FEE, "Fee too high");
        require(_adminFee <= MAX_ADMIN_FEE, "Admin fee too high");
        require(_zetaToken != address(0), "Invalid ZETA token address");
        
        // Create new pool
        ZetaGatewayStablecoinPool pool = new ZetaGatewayStablecoinPool(
            _tokens,
            _name,
            _symbol,
            _fee,
            _adminFee,
            _zetaToken
        );
        
        // Initialize the pool with Zeta Gateway
        pool.initialize(address(this));
        
        // Add pool to registry
        allPools.push(address(pool));
        isPool[address(pool)] = true;
        
        emit PoolCreated(
            address(pool),
            _zetaToken,
            _tokens,
            defaultAmplificationParameter,
            _fee,
            _adminFee
        );
        
        emit PoolInitialized(address(pool), address(this));
        
        return address(pool);
    }
    
    /**
     * @dev Update default parameters for new pools
     * @param _amplificationParameter New default amplification parameter
     * @param _swapFee New default swap fee
     * @param _adminFee New default admin fee
     */
    function updateDefaultParameters(
        uint256 _amplificationParameter,
        uint256 _swapFee,
        uint256 _adminFee
    ) external onlyOwner {
        require(_amplificationParameter >= 100, "A too low");
        require(_swapFee <= 100, "Fee too high"); // Max 1%
        require(_adminFee <= 10000, "Admin fee too high");
        
        defaultAmplificationParameter = _amplificationParameter;
        defaultSwapFee = _swapFee;
        defaultAdminFee = _adminFee;
        
        emit DefaultParametersUpdated(_amplificationParameter, _swapFee, _adminFee);
    }
    
    /**
     * @dev Get the number of pools created
     * @return Number of pools
     */
    function getPoolCount() external view returns (uint256) {
        return allPools.length;
    }
    
    /**
     * @dev Get all pools
     * @return Array of pool addresses
     */
    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }
    
    /**
     * @dev Get pool by tokens
     * @param _tokens Array of token addresses
     * @return Pool address
     */
    function getPoolByTokens(address[] calldata _tokens) external view returns (address) {
        return isPool[_tokens[0]] ? _tokens[0] : address(0);
    }
    
    /**
     * @dev Check if address is a pool
     * @param _pool Address to check
     * @return True if address is a pool
     */
    function isPool(address _pool) external view returns (bool) {
        return isPool[_pool];
    }
} 