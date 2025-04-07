// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zeta.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// Struct from ZetaChain Gateway documentation
struct RevertOptions {
    address revertAddress;
    bool callOnRevert;
    address abortAddress;
    bytes revertMessage;
    uint256 onRevertGasLimit;
}

/**
 * @title OmniUSDT
 * @dev A cross-chain unified USDT token that represents a share in the Curve-like pool.
 * This token can be used to redeem USDT on any chain through ZetaChain's Gateway.
 */
contract OmniUSDT is ERC20, Ownable, Pausable {
    using SafeERC20 for IERC20;
    
    // ZetaChain Token for handling cross-chain fees
    address public zetaToken;
    
    // Mapping of supported ZRC20 tokens
    mapping(address => bool) public supportedZRC20s;
    
    // Mapping of supported chain IDs
    mapping(uint256 => bool) public supportedChains;
    
    // Mapping of authorized messengers
    mapping(address => bool) public authorizedMessengers;
    
    // Events
    event ZRC20Added(address indexed token);
    event ZRC20Removed(address indexed token);
    event ChainSupported(uint256 chainId, bool supported);
    event CrossChainTransfer(
        address indexed sender,
        bytes indexed destinationAddress,
        uint256 amount,
        uint256 destinationChainId
    );
    event CrossChainReceive(
        uint256 indexed sourceChainId,
        bytes indexed sourceAddress,
        address indexed recipient,
        uint256 amount,
        bytes32 messageId
    );
    
    // Add this to OmniUSDT.sol
    uint256 public maxTransferAmount;
    
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
     * @dev Transfer OmniUSDT tokens across chains using the Zeta Gateway `withdraw` function.
     * Note: This ZRC-20 token (OmniUSDT) can only be withdrawn to its originating chain (ZetaChain).
     * Cross-chain transfers typically involve swapping this for a native ZRC-20 and withdrawing that.
     * This function assumes OmniUSDT itself is being withdrawn to ZetaChain address format.
     * @param _amount Amount of tokens to transfer
     * @param _destinationChainId Chain ID to transfer to (Must be ZetaChain's ID for OmniUSDT withdrawal)
     * @param _destinationAddress Address (in bytes format) to receive tokens on destination chain
     */
    function transferCrossChain(
        uint256 _amount,
        uint256 _destinationChainId,
        bytes calldata _destinationAddress // Ensure this is properly formatted bytes
    ) external whenNotPaused {
        // Note: ZRC-20s can only be withdrawn to their originating chain.
        // This check might need adjustment depending on OmniUSDT's origin.
        require(supportedChains[_destinationChainId], "Chain not supported");
        require(_amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // Burn tokens from sender
        _burn(msg.sender, _amount);
        
        // Prepare revert options - revert to sender by default
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: msg.sender,
            callOnRevert: false,
            abortAddress: address(0), // Or a designated abort handler
            revertMessage: "",
            onRevertGasLimit: 0 // Gas is free for reverts on ZetaChain originating CCTX
        });

        // Withdraw OmniUSDT using Zeta Gateway
        // The gateway will handle fees.
        zeta(zetaToken).withdraw(
            _destinationAddress,
            _amount,
            address(this), // The ZRC-20 token being withdrawn (OmniUSDT)
            revertOptions
        );
        
        emit CrossChainTransfer(
            msg.sender,
            _destinationAddress,
            _amount,
            _destinationChainId
        );
    }
    
    /**
     * @dev Receive cross-chain message from Zeta Gateway (or authorized messenger)
     * This function handles incoming ZRC-20 transfers *or* messages resulting from `call` or `depositAndCall`.
     * The exact mechanism depends on how messages arrive at ZRC-20 contracts.
     * The check `msg.sender == address(zeta(zetaToken))` assumes direct calls from the gateway.
     * @param _sourceChainId Chain ID where the message originated
     * @param _sourceAddress Address (bytes) that sent the message
     * @param _messageId Unique identifier for the message (if provided by protocol)
     * @param _message Encoded message data
     */
    function receiveCrossChain(
        uint256 _sourceChainId,
        bytes calldata _sourceAddress,
        bytes32 _messageId, // May not be directly provided in all scenarios
        bytes calldata _message
    ) external /* override */ { // 'override' might depend on inherited interfaces not shown
        // Verification: Ensure caller is authorized (e.g., the Zeta Gateway)
        // This check might need adjustment based on ZetaChain's message handling for ZRC-20s.
        require(msg.sender == address(zeta(zetaToken)) || authorizedMessengers[msg.sender], "Unauthorized caller");
        
        // --- Message Decoding Logic ---
        // The decoding depends entirely on what system/contract called this function
        // and what data it encoded in _message.

        // Scenario 1: Simple ZRC-20 Transfer (e.g., from `withdraw` on another chain targeting this contract)
        // If this contract *is* the ZRC-20 being transferred TO, the gateway might handle minting internally,
        // or it might call a specific function like this one.
        // Let's assume for cross-chain *transfers* of OmniUSDT *to* ZetaChain, this is called.
        (address recipient, uint256 amount) = abi.decode(_message, (address, uint256));
        
        require(supportedChains[_sourceChainId], "Source chain not supported");
        
        // Mint tokens to the recipient
        _mint(recipient, amount);
        
        emit CrossChainReceive(
            _sourceChainId,
            _sourceAddress,
            recipient,
            amount,
            _messageId // Pass messageId if available/relevant
        );
        
        // Scenario 2: Handling results from `call` or `withdrawAndCall`
        // If this function is intended to be called via `call` or `withdrawAndCall` from another chain,
        // the _message format and handling would be different, likely involving specific function logic.
        // This example focuses on receiving transfers.
    }
    
    /**
     * @dev Redeem OmniUSDT for a specific ZRC-20 token on its originating chain using Zeta Gateway `withdraw`.
     * Note: This requires the pool associated with OmniUSDT to hold the target ZRC-20 (_token).
     * The specified _token can ONLY be withdrawn to its originating chain (_destinationChainId must match).
     * @param _amount Amount of OmniUSDT to redeem (implies equivalent value of _token)
     * @param _token Address of the ZRC-20 token (e.g., ZRC-20 USDT) to withdraw
     * @param _destinationChainId Chain ID to withdraw to (Must be the originating chain of _token)
     * @param _destinationAddress Address (in bytes format) to receive the token on destination chain
     */
    function redeem(
        uint256 _amount,
        address _token, // ZRC-20 to withdraw
        uint256 _destinationChainId, // Must be the originating chain of _token
        bytes calldata _destinationAddress // Ensure this is properly formatted bytes
    ) external whenNotPaused {
        require(supportedZRC20s[_token], "Target ZRC-20 token not supported by this OmniUSDT representation");
        // Critical Check: A ZRC-20 can only be withdrawn to its originating chain.
        // require(zeta(_token).originChainId() == _destinationChainId, "Destination chain must be the ZRC-20's origin chain"); // Example check - requires ZRC20 interface update
        require(supportedChains[_destinationChainId], "Destination chain not supported for withdrawal");
        require(_amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= _amount, "Insufficient OmniUSDT balance");
        
        // Burn OmniUSDT from sender - assumes 1:1 value or pool handles exchange
        _burn(msg.sender, _amount);
        
        // --- Important Assumption ---
        // This function assumes that burning _amount OmniUSDT entitles the user
        // to withdraw an equivalent _amount of the specified ZRC-20 _token.
        // In a real scenario, the OmniUSDT would likely be burned by the associated pool contract,
        // which would then release the underlying ZRC-20 (_token) to be withdrawn.
        // For this example, we proceed directly to withdrawal, assuming the pool logic
        // has implicitly made the ZRC-20 _token available for withdrawal.

        // Prepare revert options - revert ZRC-20 _token to sender on ZetaChain
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: msg.sender, // On revert, ZRC-20 _token goes back to sender on ZetaChain
            callOnRevert: false,
            abortAddress: address(0), // Or a designated abort handler
            revertMessage: "",
            onRevertGasLimit: 0 // Gas is free for reverts on ZetaChain originating CCTX
        });

        // Withdraw the specified ZRC-20 token using Zeta Gateway
        // The gateway will handle fees.
        zeta(zetaToken).withdraw(
            _destinationAddress,
            _amount, // Amount of the underlying ZRC-20 to withdraw
            _token,  // Address of the ZRC-20 token being withdrawn
            revertOptions
        );
        
        // Emit event reflecting the intent to transfer the underlying token
        emit CrossChainTransfer(
            msg.sender,
            _destinationAddress,
            _amount,
            _destinationChainId // Chain where _token is being sent
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
    
    /**
     * @dev Add an authorized messenger
     * @param _messenger Address of the authorized messenger
     */
    function addAuthorizedMessenger(address _messenger) external onlyOwner {
        authorizedMessengers[_messenger] = true;
    }
    
    /**
     * @dev Remove an authorized messenger
     * @param _messenger Address of the authorized messenger
     */
    function removeAuthorizedMessenger(address _messenger) external onlyOwner {
        authorizedMessengers[_messenger] = false;
    }

    // Add this interface to OmniUSDT.sol
    interface ZetaReceiver {
        function onZetaMessage(
            uint256 sourceChainId, 
            address sourceAddress, 
            bytes calldata message
        ) external;
    }

    // Implement the interface in OmniUSDT.sol
    function onZetaMessage(
        uint256 sourceChainId,
        address sourceAddress,
        bytes calldata message
    ) external {
        require(authorizedMessengers[msg.sender], "Unauthorized messenger");
        
        (address recipient, uint256 amount) = abi.decode(message, (address, uint256));
        
        // Create a unique messageId for tracking
        bytes32 messageId = keccak256(abi.encodePacked(
            sourceChainId,
            sourceAddress,
            recipient,
            amount,
            block.timestamp
        ));
        
        _mint(recipient, amount);
        
        emit CrossChainReceive(
            sourceChainId,
            sourceAddress,
            recipient,
            amount,
            messageId
        );
    }

    // Add this function to OmniUSDT.sol
    function setMaxTransferAmount(uint256 _amount) external onlyOwner {
        maxTransferAmount = _amount;
    }

    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
} 