// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title UnifiedStablecoin
 * @dev A unified stablecoin that represents cross-chain stablecoins on ZetaChain.
 * This contract allows users to deposit stablecoins from any connected chain and
 * receive a unified representation on ZetaChain.
 */
contract UnifiedStablecoin is ERC20, Ownable {
    // Mapping of supported tokens (cross-chain assets on ZetaChain)
    mapping(address => bool) public supportedTokens;
    
    // Events
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event StablecoinDeposited(address indexed token, address indexed from, uint256 amount);
    event StablecoinWithdrawn(address indexed token, address indexed to, uint256 amount);
    event Initialized(string name, string symbol);

    // Flag to track if the token has been initialized
    bool private _initialized;

    /**
     * @dev Constructor that initializes the unified stablecoin with default values
     * This allows the token to be initialized later with custom name and symbol
     */
    constructor() ERC20("Unified Stablecoin", "UUSDC") Ownable(msg.sender) {
        _initialized = false;
    }
    
    /**
     * @dev Initialize the token with a name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function initialize(string memory name, string memory symbol) external onlyOwner {
        require(!_initialized, "Already initialized");
        
        _initialized = true;
        emit Initialized(name, symbol);
    }

    /**
     * @dev Add a token as a supported stablecoin
     * @param token The address of the token
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(!supportedTokens[token], "Token already supported");
        
        supportedTokens[token] = true;
        emit TokenAdded(token);
    }

    /**
     * @dev Remove a token from supported stablecoins
     * @param token The address of the token
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }

    /**
     * @dev Deposit a supported token and mint unified stablecoins
     * @param token The address of the token
     * @param amount The amount to deposit
     */
    function deposit(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer tokens from the user to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Mint unified stablecoins to the user (1:1 ratio)
        _mint(msg.sender, amount);
        
        emit StablecoinDeposited(token, msg.sender, amount);
    }

    /**
     * @dev Withdraw a supported token by burning unified stablecoins
     * @param token The address of the token to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Burn unified stablecoins from the user
        _burn(msg.sender, amount);
        
        // Transfer tokens to the user
        IERC20(token).transfer(msg.sender, amount);
        
        emit StablecoinWithdrawn(token, msg.sender, amount);
    }
    
    /**
     * @dev Mint new tokens (only callable by owner, which will be the pool)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens from an account (only callable by owner, which will be the pool)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
} 