// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockZetaToken
 * @dev A mock implementation of the Zeta token for testing purposes
 */
contract MockZetaToken is ERC20, Ownable {
    uint256 public gasPriceMultiplier;
    
    /**
     * @dev Constructor to initialize the token
     * @param _gasPriceMultiplier Multiplier to use for calculating gas prices
     */
    constructor(uint256 _gasPriceMultiplier) ERC20("Zeta", "ZETA") Ownable(msg.sender) {
        gasPriceMultiplier = _gasPriceMultiplier;
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
     * @dev Get price in Wei for a given gas amount
     * @param gasAmount Amount of gas
     * @return weiPrice Price in Wei
     */
    function getWeiPrice(uint256 gasAmount) external view returns (uint256 weiPrice) {
        return gasAmount * gasPriceMultiplier;
    }
    
    /**
     * @dev Set the gas price multiplier
     * @param _gasPriceMultiplier New gas price multiplier
     */
    function setGasPriceMultiplier(uint256 _gasPriceMultiplier) external onlyOwner {
        gasPriceMultiplier = _gasPriceMultiplier;
    }
} 