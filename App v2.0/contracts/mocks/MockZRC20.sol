// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockZRC20
 * @dev A mock implementation of a ZRC20 token for testing purposes
 */
contract MockZRC20 is ERC20, Ownable {
    uint256 public chainId;
    
    /**
     * @dev Constructor to initialize the token
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param _chainId Chain ID that this token represents
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 _chainId
    ) ERC20(name, symbol) Ownable(msg.sender) {
        chainId = _chainId;
    }
    
    /**
     * @dev Mint new tokens (only callable by owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Withdraw tokens to another chain
     * This is a mock implementation and doesn't actually transfer tokens across chains
     * @param to Address to send tokens to on the destination chain
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(bytes calldata to, uint256 amount) external {
        // Burn tokens from the sender
        _burn(msg.sender, amount);
        
        // In a real implementation, this would trigger a cross-chain message
        // For this mock, we just emit an event
        emit Withdrawal(msg.sender, to, amount, chainId);
    }
    
    /**
     * @dev Mock cross-chain deposit to simulate receiving tokens from another chain
     * @param to Address to receive tokens
     * @param amount Amount of tokens to deposit
     * @param sourceChainId Chain ID where the tokens came from
     */
    function deposit(address to, uint256 amount, uint256 sourceChainId) external onlyOwner {
        _mint(to, amount);
        emit Deposit(to, amount, sourceChainId);
    }
    
    event Withdrawal(address indexed from, bytes indexed to, uint256 amount, uint256 destinationChainId);
    event Deposit(address indexed to, uint256 amount, uint256 sourceChainId);
} 