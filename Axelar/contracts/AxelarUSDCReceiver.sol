// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol";

/**
 * @title AxelarUSDCReceiver
 * @dev Contract that receives USDC from other chains via Axelar and manages a local USDC pool
 */
contract AxelarUSDCReceiver is IAxelarExecutable, Ownable, ReentrancyGuard {
    // USDC token address on this chain
    address public usdcAddress;
    
    // Axelar Gateway interface
    IAxelarGateway public immutable gateway;
    
    // Axelar Gas Service
    IAxelarGasService public immutable gasService;
    
    // Mapping to track which chains are trusted sources
    mapping(string => bool) public trustedSourceChains;
    
    // Mapping to track which addresses on source chains are trusted senders
    mapping(string => mapping(string => bool)) public trustedSenders;
    
    // Events
    event USDCReceived(
        string sourceChain,
        string sourceAddress,
        address indexed recipient,
        uint256 amount
    );
    
    event USDCSent(
        string destinationChain,
        string destinationAddress,
        uint256 amount
    );
    
    event TrustedSourceChainUpdated(string chainName, bool isTrusted);
    event TrustedSenderUpdated(string chainName, string senderAddress, bool isTrusted);
    
    /**
     * @dev Constructor
     * @param _gateway Axelar Gateway contract address
     * @param _gasService Axelar Gas Service contract address
     * @param _usdcAddress Local USDC token address
     */
    constructor(address _gateway, address _gasService, address _usdcAddress) IAxelarExecutable(_gateway) {
        gateway = IAxelarGateway(_gateway);
        gasService = IAxelarGasService(_gasService);
        usdcAddress = _usdcAddress;
    }
    
    /**
     * @dev Execute function that's called by Axelar Gateway when tokens are received
     * @param sourceChain The source chain name
     * @param sourceAddress The sender address on the source chain
     * @param payload Additional payload data (unused in this simple implementation)
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        // This is called automatically when tokens are sent via Axelar
        // For token transfers, we don't need to do anything here as the gateway handles the token transfer
        // For custom contract calls with tokens, we would handle the payload here
    }
    
    /**
     * @dev Called by the Axelar Gateway when tokens are sent to this contract
     * @param sourceChain The source chain name
     * @param sourceAddress The sender address on the source chain
     * @param symbol The token symbol
     * @param amount The token amount
     */
    function executeWithToken(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    ) external nonReentrant {
        // Verify that the sender is the Axelar Gateway
        require(msg.sender == address(gateway), "Only Axelar Gateway can call this function");
        
        // Verify that the token is USDC
        require(keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("USDC")), "Only USDC is supported");
        
        // Verify that the source chain is trusted
        require(trustedSourceChains[sourceChain], "Source chain not trusted");
        
        // Verify that the source address is trusted (if specified)
        require(trustedSenders[sourceChain][sourceAddress], "Source address not trusted");
        
        // Decode the payload to get the recipient address
        address recipient = abi.decode(payload, (address));
        
        // Transfer the received USDC to the recipient
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transfer(recipient, amount), "USDC transfer failed");
        
        emit USDCReceived(sourceChain, sourceAddress, recipient, amount);
    }
    
    /**
     * @dev Send USDC back to another chain
     * @param destinationChain The destination chain name
     * @param destinationAddress The recipient address on the destination chain
     * @param recipient The recipient address encoded in payload (useful for contracts)
     * @param amount The amount of USDC to send
     */
    function sendUSDC(
        string calldata destinationChain,
        string calldata destinationAddress,
        address recipient,
        uint256 amount
    ) external payable onlyOwner nonReentrant {
        // Transfer USDC from sender to this contract
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        
        // Approve the gateway to spend the USDC
        usdc.approve(address(gateway), amount);
        
        // Create payload with recipient address
        bytes memory payload = abi.encode(recipient);
        
        // Pay for gas if needed
        if (msg.value > 0) {
            gasService.payNativeGasForContractCallWithToken{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                "USDC",
                amount,
                msg.sender // refund address
            );
        }
        
        // Send tokens with contract call via Axelar Gateway
        gateway.callContractWithToken(
            destinationChain,
            destinationAddress,
            payload,
            "USDC",
            amount
        );
        
        emit USDCSent(destinationChain, destinationAddress, amount);
    }
    
    /**
     * @dev Set trusted source chain
     * @param chainName The chain name to set as trusted or untrusted
     * @param isTrusted Whether the chain should be trusted
     */
    function setTrustedSourceChain(string calldata chainName, bool isTrusted) external onlyOwner {
        trustedSourceChains[chainName] = isTrusted;
        emit TrustedSourceChainUpdated(chainName, isTrusted);
    }
    
    /**
     * @dev Set trusted sender on a source chain
     * @param chainName The source chain name
     * @param senderAddress The sender address on the source chain
     * @param isTrusted Whether the sender should be trusted
     */
    function setTrustedSender(
        string calldata chainName,
        string calldata senderAddress,
        bool isTrusted
    ) external onlyOwner {
        trustedSenders[chainName][senderAddress] = isTrusted;
        emit TrustedSenderUpdated(chainName, senderAddress, isTrusted);
    }
    
    /**
     * @dev Recover any accidentally sent ERC20 tokens
     * @param tokenAddress The token address to recover
     * @param to Recipient address
     */
    function recoverTokens(address tokenAddress, address to) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to recover");
        require(token.transfer(to, balance), "Token recovery failed");
    }
    
    /**
     * @dev Recover any accidentally sent ETH
     * @param to Recipient address
     */
    function recoverEth(address payable to) external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to recover");
        to.transfer(balance);
    }
} 