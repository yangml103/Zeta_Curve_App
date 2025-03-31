// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zeta.sol";

/**
 * @title OmniUSDT
 * @dev A cross-chain unified USDT token that represents a share in the Curve-like pool.
 * This token can be used to redeem USDT on any chain through ZetaChain's Gateway.
 */
contract OmniUSDT is ERC20, Ownable {
    using SafeERC20 for IERC20;
    
    // ZetaChain Token for handling cross-chain fees
    address public zetaToken;
    
    // Mapping of supported ZRC20 tokens
    mapping(address => bool) public supportedZRC20s;
    
    // Mapping of supported chain IDs
    mapping(uint256 => bool) public supportedChains;
    
    // Events
    event ZRC20Added(address indexed token);
    event ZRC20Removed(address indexed token);
    event ChainSupported(uint256 chainId, bool supported);
    event CrossChainTransfer(
        address indexed from,
        bytes indexed destinationAddress,
        uint256 amount,
        uint256 destinationChainId
    );
    event CrossChainReceived(
        address indexed to,
        uint256 amount,
        uint256 sourceChainId
    );
    
    /**
     * @dev Constructor to initialize the token
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     * @param _zetaToken Address of the Zeta Token
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _zetaToken
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_zetaToken != address(0), "Invalid Zeta Token address");
        zetaToken = _zetaToken;
    }
    
    /**
     * @dev Set a supported chain
     * @param chainId Chain ID to set support for
     * @param supported Whether the chain is supported
     */
    function setSupportedChain(uint256 chainId, bool supported) external onlyOwner {
        supportedChains[chainId] = supported;
        emit ChainSupported(chainId, supported);
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
     * @dev Transfer tokens across chains using ZetaChain Gateway
     * @param _amount Amount of tokens to transfer
     * @param _destinationChainId Chain ID to send tokens to
     * @param _destinationAddress Address to receive tokens on destination chain
     */
    function transferCrossChain(
        uint256 _amount,
        uint256 _destinationChainId,
        bytes calldata _destinationAddress
    ) external {
        require(supportedChains[_destinationChainId], "Chain not supported");
        require(_amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // Burn tokens from sender
        _burn(msg.sender, _amount);
        
        // Calculate gas fees for cross-chain transfer
        uint256 gasFee = getGasFee(_destinationChainId);
        
        // Prepare message data for the cross-chain transaction
        bytes memory message = abi.encode(
            abi.decode(_destinationAddress, (address)),
            _amount
        );
        
        // Emit an event for tracking purposes
        emit CrossChainTransfer(
            msg.sender,
            _destinationAddress,
            _amount,
            _destinationChainId
        );
        
        // In a real implementation, here we would call Zeta Gateway's API to
        // facilitate the cross-chain transfer using CCIP
        // For this MVP, we simply emit the event and burn the tokens
    }
    
    /**
     * @dev Receive tokens from another chain (called by ZetaChain Gateway)
     * @param _to Address to receive tokens
     * @param _amount Amount of tokens to receive
     * @param _sourceChainId Chain ID the tokens came from
     */
    function receiveCrossChain(
        address _to,
        uint256 _amount,
        uint256 _sourceChainId
    ) external onlyOwner {
        require(_to != address(0), "Invalid recipient");
        require(_amount > 0, "Invalid amount");
        
        // Mint tokens to the recipient
        _mint(_to, _amount);
        
        emit CrossChainReceived(_to, _amount, _sourceChainId);
    }
    
    /**
     * @dev Redeem OmniUSDT for actual USDT on a specific chain
     * @param _amount Amount of OmniUSDT to redeem
     * @param _token Address of the ZRC20 token (USDT) to redeem for
     * @param _destinationChainId Chain ID to redeem on
     * @param _destinationAddress Address to receive USDT on destination chain
     */
    function redeem(
        uint256 _amount,
        address _token,
        uint256 _destinationChainId,
        bytes calldata _destinationAddress
    ) external {
        require(supportedZRC20s[_token], "Token not supported");
        require(supportedChains[_destinationChainId], "Chain not supported");
        require(_amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // Burn OmniUSDT from sender
        _burn(msg.sender, _amount);
        
        // For simplicity in this example, we assume the ZRC20 token withdrawal
        // will handle sending the equivalent USDT to the destination chain
        // In a real implementation, we would need to handle the token conversion
        IZRC20(_token).withdraw(_destinationAddress, _amount);
        
        emit CrossChainTransfer(
            msg.sender,
            _destinationAddress,
            _amount,
            _destinationChainId
        );
    }
    
    /**
     * @dev Calculate gas fee for cross-chain transfer
     * @param _chainId Destination chain ID
     * @return Gas fee amount
     */
    function getGasFee(uint256 _chainId) public view returns (uint256) {
        // Get the appropriate gas limit for the chain
        uint256 gasLimit = getGasLimitForChain(_chainId);
        
        // Calculate fee using Zeta's price oracle
        return zeta(zetaToken).getWeiPrice(gasLimit);
    }
    
    /**
     * @dev Get gas limit for a specific chain
     * @param _chainId Chain ID
     * @return Gas limit for the chain
     */
    function getGasLimitForChain(uint256 _chainId) internal pure returns (uint256) {
        // Default gas limits for common chains
        if (_chainId == 1 || _chainId == 5) {
            return 300000; // Ethereum
        } else if (_chainId == 56 || _chainId == 97) {
            return 250000; // BSC
        } else if (_chainId == 137 || _chainId == 80001) {
            return 350000; // Polygon
        } else {
            return 300000; // Default
        }
    }
} 