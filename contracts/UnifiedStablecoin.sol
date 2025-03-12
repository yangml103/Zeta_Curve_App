// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zContract.sol";

/**
 * @title UnifiedStablecoin
 * @dev A unified stablecoin that represents cross-chain stablecoins on ZetaChain.
 * This contract allows users to deposit stablecoins from any connected chain and
 * receive a unified representation on ZetaChain.
 */
contract UnifiedStablecoin is ERC20, Ownable, zContract {
    // Mapping of supported ZRC20 tokens (cross-chain assets on ZetaChain)
    mapping(address => bool) public supportedZRC20s;
    
    // Events
    event ZRC20Added(address indexed zrc20);
    event ZRC20Removed(address indexed zrc20);
    event StablecoinDeposited(address indexed zrc20, address indexed from, uint256 amount);
    event StablecoinWithdrawn(address indexed zrc20, address indexed to, uint256 amount);
    event Initialized(string name, string symbol);

    /**
     * @dev Constructor that initializes the unified stablecoin with default values
     * This allows the token to be initialized later with custom name and symbol
     */
    constructor() ERC20("", "") Ownable(msg.sender) {}
    
    /**
     * @dev Initialize the token with a name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function initialize(string memory name, string memory symbol) external onlyOwner {
        require(bytes(name()).length == 0, "Already initialized");
        require(bytes(symbol()).length == 0, "Already initialized");
        
        _initializeERC20(name, symbol);
        emit Initialized(name, symbol);
    }
    
    /**
     * @dev Internal function to initialize ERC20 name and symbol
     * @param name The name of the token
     * @param symbol The symbol of the token
     */
    function _initializeERC20(string memory name, string memory symbol) internal virtual {
        // This is a workaround since ERC20 doesn't provide a way to change name/symbol after construction
        // In a production environment, you might want to use a more sophisticated approach
        assembly {
            // Store the name and symbol in storage slots used by ERC20
            sstore(0, name)
            sstore(1, symbol)
        }
    }

    /**
     * @dev Add a ZRC20 token as a supported stablecoin
     * @param zrc20 The address of the ZRC20 token
     */
    function addSupportedZRC20(address zrc20) external onlyOwner {
        require(zrc20 != address(0), "Invalid ZRC20 address");
        require(!supportedZRC20s[zrc20], "ZRC20 already supported");
        
        supportedZRC20s[zrc20] = true;
        emit ZRC20Added(zrc20);
    }

    /**
     * @dev Remove a ZRC20 token from supported stablecoins
     * @param zrc20 The address of the ZRC20 token
     */
    function removeSupportedZRC20(address zrc20) external onlyOwner {
        require(supportedZRC20s[zrc20], "ZRC20 not supported");
        
        supportedZRC20s[zrc20] = false;
        emit ZRC20Removed(zrc20);
    }

    /**
     * @dev Deposit a supported ZRC20 token and mint unified stablecoins
     * @param zrc20 The address of the ZRC20 token
     * @param amount The amount to deposit
     */
    function deposit(address zrc20, uint256 amount) external {
        require(supportedZRC20s[zrc20], "ZRC20 not supported");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer ZRC20 tokens from the user to this contract
        IZRC20(zrc20).transferFrom(msg.sender, address(this), amount);
        
        // Mint unified stablecoins to the user (1:1 ratio)
        _mint(msg.sender, amount);
        
        emit StablecoinDeposited(zrc20, msg.sender, amount);
    }

    /**
     * @dev Withdraw a supported ZRC20 token by burning unified stablecoins
     * @param zrc20 The address of the ZRC20 token to withdraw
     * @param amount The amount to withdraw
     */
    function withdraw(address zrc20, uint256 amount) external {
        require(supportedZRC20s[zrc20], "ZRC20 not supported");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Burn unified stablecoins from the user
        _burn(msg.sender, amount);
        
        // Transfer ZRC20 tokens to the user
        IZRC20(zrc20).transfer(msg.sender, amount);
        
        emit StablecoinWithdrawn(zrc20, msg.sender, amount);
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

    /**
     * @dev Implementation of the ZetaChain zContract interface
     * This function is called when a cross-chain message is received
     */
    function onCrossChainCall(
        zContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external override {
        // Only allow calls from the ZetaChain messaging system
        require(msg.sender == address(0x00), "Unauthorized caller");
        
        // Check if the ZRC20 token is supported
        require(supportedZRC20s[zrc20], "ZRC20 not supported");
        
        // Mint unified stablecoins to the specified recipient
        address recipient = abi.decode(message, (address));
        _mint(recipient, amount);
        
        emit StablecoinDeposited(zrc20, recipient, amount);
    }
} 