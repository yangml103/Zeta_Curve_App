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
        address indexed lpToken,
        address[] tokens,
        uint256 amplificationParameter,
        uint256 swapFee,
        uint256 adminFee
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
     * @dev Create a new ZetaGatewayStablecoinPool with default parameters
     * @param _tokens Array of token addresses for the pool
     * @param _lpTokenName Name of the LP token
     * @param _lpTokenSymbol Symbol of the LP token
     * @return pool Address of the created pool
     * @return lpToken Address of the LP token
     */
    function createPool(
        address[] memory _tokens,
        string memory _lpTokenName,
        string memory _lpTokenSymbol
    ) external returns (address pool, address lpToken) {
        return createPoolWithParams(
            _tokens,
            _lpTokenName,
            _lpTokenSymbol,
            defaultAmplificationParameter,
            defaultSwapFee,
            defaultAdminFee
        );
    }
    
    /**
     * @dev Create a new ZetaGatewayStablecoinPool with custom parameters
     * @param _tokens Array of token addresses for the pool
     * @param _lpTokenName Name of the LP token
     * @param _lpTokenSymbol Symbol of the LP token
     * @param _amplificationParameter Amplification parameter (A) * A_PRECISION
     * @param _swapFee Fee taken on swaps (in basis points)
     * @param _adminFee Percentage of swap fee taken as admin fee (in basis points)
     * @return pool Address of the created pool
     * @return lpToken Address of the LP token
     */
    function createPoolWithParams(
        address[] memory _tokens,
        string memory _lpTokenName,
        string memory _lpTokenSymbol,
        uint256 _amplificationParameter,
        uint256 _swapFee,
        uint256 _adminFee
    ) public returns (address pool, address lpToken) {
        require(_tokens.length >= 2, "At least 2 tokens required");
        
        // Create LP token (OmniUSDT)
        OmniUSDT _lpToken = new OmniUSDT(
            _lpTokenName,
            _lpTokenSymbol,
            zetaToken
        );
        
        // Create pool
        ZetaGatewayStablecoinPool _pool = new ZetaGatewayStablecoinPool(
            _tokens,
            _amplificationParameter,
            _swapFee,
            _adminFee,
            address(_lpToken),
            zetaToken
        );
        
        // Transfer ownership of LP token to the pool
        _lpToken.transferOwnership(address(_pool));
        
        // Add supported ZRC20 tokens to the LP token
        for (uint256 i = 0; i < _tokens.length; i++) {
            _lpToken.addSupportedZRC20(_tokens[i]);
        }
        
        // Register pool
        isPool[address(_pool)] = true;
        allPools.push(address(_pool));
        
        emit PoolCreated(
            address(_pool),
            address(_lpToken),
            _tokens,
            _amplificationParameter,
            _swapFee,
            _adminFee
        );
        
        return (address(_pool), address(_lpToken));
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
} 