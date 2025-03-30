// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@zetachain/protocol-contracts/contracts/evm/legacy/ZetaInterfaces.sol";

/**
 * @title UnifiedStablecoin
 * @dev A cross-chain stablecoin that can be minted and burned by the StablecoinPool.
 * This token represents a share in the pool and can be used for cross-chain transfers.
 */
contract UnifiedStablecoin is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // ZetaChain connector for cross-chain messaging
    address public zetaConnector;
    
    // Mapping of supported ZRC20 tokens
    mapping(address => bool) public supportedZRC20s;
    
    // Events
    event ZRC20Added(address indexed token);
    event ZRC20Removed(address indexed token);
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 mintAmount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 burnAmount);
    
    /**
     * @dev Constructor to initialize the stablecoin
     * @param _zetaConnector Address of the ZetaChain connector
     */
    constructor(address _zetaConnector) ERC20("", "") Ownable(msg.sender) {
        zetaConnector = _zetaConnector;
    }
    
    /**
     * @dev Initialize the token with name and symbol
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     */
    function initialize(string memory _name, string memory _symbol) external onlyOwner {
        require(bytes(name()).length == 0, "Already initialized");
        _initializeERC20(_name, _symbol);
    }
    
    /**
     * @dev Internal function to initialize ERC20 details
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     */
    function _initializeERC20(string memory _name, string memory _symbol) internal {
        // This is a workaround since ERC20 doesn't have an initialize function
        // We're setting the name and symbol directly in storage
        // This is not ideal but works for our purpose
        assembly {
            sstore(0x3, _name)
            sstore(0x4, _symbol)
        }
    }
    
    /**
     * @dev Add a supported ZRC20 token
     * @param _token Address of the ZRC20 token
     */
    function addSupportedZRC20(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token");
        supportedZRC20s[_token] = true;
        emit ZRC20Added(_token);
    }
    
    /**
     * @dev Remove a supported ZRC20 token
     * @param _token Address of the ZRC20 token
     */
    function removeSupportedZRC20(address _token) external onlyOwner {
        require(supportedZRC20s[_token], "Token not supported");
        supportedZRC20s[_token] = false;
        emit ZRC20Removed(_token);
    }
    
    /**
     * @dev Mint new tokens
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
    
    /**
     * @dev Burn tokens from an address
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     */
    function burnFrom(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
    
    /**
     * @dev Deposit ZRC20 tokens and mint unified stablecoins
     * @param _token Address of the ZRC20 token
     * @param _amount Amount of tokens to deposit
     * @return mintAmount Amount of unified stablecoins minted
     */
    function deposit(address _token, uint256 _amount) external returns (uint256 mintAmount) {
        require(supportedZRC20s[_token], "Token not supported");
        require(_amount > 0, "Invalid amount");
        
        // Transfer tokens to this contract
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Mint unified stablecoins 1:1 with the deposited tokens
        // In a real implementation, you might want to use price oracles or other mechanisms
        mintAmount = _amount;
        _mint(msg.sender, mintAmount);
        
        emit Deposit(msg.sender, _token, _amount, mintAmount);
        return mintAmount;
    }
    
    /**
     * @dev Withdraw ZRC20 tokens by burning unified stablecoins
     * @param _token Address of the ZRC20 token
     * @param _amount Amount of tokens to withdraw
     * @return burnAmount Amount of unified stablecoins burned
     */
    function withdraw(address _token, uint256 _amount) external returns (uint256 burnAmount) {
        require(supportedZRC20s[_token], "Token not supported");
        require(_amount > 0, "Invalid amount");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient balance");
        
        // Burn unified stablecoins 1:1 with the withdrawn tokens
        burnAmount = _amount;
        _burn(msg.sender, burnAmount);
        
        // Transfer tokens to the user
        IERC20(_token).safeTransfer(msg.sender, _amount);
        
        emit Withdrawal(msg.sender, _token, _amount, burnAmount);
        return burnAmount;
    }
    
    /**
     * @dev Cross-chain withdrawal of tokens
     * @param _token Address of the ZRC20 token
     * @param _amount Amount of tokens to withdraw
     * @param _destinationChainId Chain ID to receive tokens on
     * @param _destinationAddress Address to receive tokens on destination chain
     * @return burnAmount Amount of unified stablecoins burned
     */
    function crossChainWithdraw(
        address _token,
        uint256 _amount,
        uint256 _destinationChainId,
        address _destinationAddress
    ) external returns (uint256 burnAmount) {
        require(supportedZRC20s[_token], "Token not supported");
        require(_amount > 0, "Invalid amount");
        
        // Burn unified stablecoins 1:1 with the withdrawn tokens
        burnAmount = _amount;
        _burn(msg.sender, burnAmount);
        
        // For ZRC20 tokens, use the withdraw function
        // Convert the address to bytes
        bytes memory destinationAddressBytes = abi.encodePacked(_destinationAddress);
        IZRC20(_token).withdraw(destinationAddressBytes, _amount);
        
        emit Withdrawal(msg.sender, _token, _amount, burnAmount);
        return burnAmount;
    }
} 