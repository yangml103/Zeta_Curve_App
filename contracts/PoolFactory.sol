// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StablecoinPool.sol";
import "./UnifiedStablecoin.sol";

/**
 * @title PoolFactory
 * @dev Factory contract for creating new StablecoinPool instances.
 * This allows users to create pools with different tokens and parameters.
 */
contract PoolFactory is Ownable {
    // Default parameters
    uint256 public defaultAmplificationParameter = 2000; // A = 20
    uint256 public defaultSwapFee = 4; // 0.04%
    uint256 public defaultAdminFee = 5000; // 50% of swap fees
    
    // Mapping of created pools
    mapping(address => bool) public isPool;
    address[] public allPools;
    
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

    /**
     * @dev Constructor to initialize the factory
     */
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Create a new StablecoinPool with default parameters
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
     * @dev Create a new StablecoinPool with custom parameters
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
        
        // Create LP token (UnifiedStablecoin)
        UnifiedStablecoin _lpToken = new UnifiedStablecoin();
        _lpToken.initialize(_lpTokenName, _lpTokenSymbol);
        
        // Create pool
        StablecoinPool _pool = new StablecoinPool(
            _tokens,
            _amplificationParameter,
            _swapFee,
            _adminFee,
            address(_lpToken)
        );
        
        // Transfer ownership of LP token to the pool
        _lpToken.transferOwnership(address(_pool));
        
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