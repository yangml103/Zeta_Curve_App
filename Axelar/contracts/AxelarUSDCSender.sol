// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

/**
 * @title AxelarUSDCSender
 * @dev Facilitates sending USDC across different chains using Axelar's cross-chain communication
 */
contract AxelarUSDCSender is Ownable {
    IAxelarGateway public gateway;
    IAxelarGasService public gasService;
    
    // USDC token address on this chain
    address public usdcAddress;
    
    // Fee percentage for transfers (in basis points, e.g., 25 = 0.25%)
    uint16 public feePercentage = 0; // Can be set by owner
    
    // Maximum fee percentage (to prevent abuse by owner)
    uint16 public constant MAX_FEE_PERCENTAGE = 100; // 1%
    
    // Fixed token symbol for USDC when sending via Axelar
    string public constant TOKEN_SYMBOL = "USDC";
    
    // Events
    event USDCSent(
        address indexed sender, 
        string destinationChain, 
        string destinationAddress, 
        uint256 amount,
        uint256 fee
    );
    
    event FeePercentageUpdated(uint16 newFeePercentage);
    
    /**
     * @dev Constructor
     * @param _gateway Axelar Gateway contract address
     * @param _gasService Axelar Gas Service contract address
     * @param _usdcAddress USDC token address on this chain
     */
    constructor(address _gateway, address _gasService, address _usdcAddress) {
        gateway = IAxelarGateway(_gateway);
        gasService = IAxelarGasService(_gasService);
        usdcAddress = _usdcAddress;
    }
    
    /**
     * @dev Send USDC to another chain
     * @param destinationChain The destination chain name (e.g., "Ethereum", "Avalanche")
     * @param destinationAddress The recipient address on the destination chain
     * @param amount The amount of USDC to send
     */
    function sendUSDC(
        string calldata destinationChain,
        string calldata destinationAddress,
        uint256 amount
    ) external payable {
        // Calculate fee
        uint256 fee = (amount * feePercentage) / 10000;
        uint256 amountAfterFee = amount - fee;
        
        // Transfer USDC from user to this contract
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        
        // Approve Gateway to spend USDC
        usdc.approve(address(gateway), amountAfterFee);
        
        // Pay for gas if needed
        if (msg.value > 0) {
            gasService.payNativeGasForTokenTransfer{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                TOKEN_SYMBOL,
                amountAfterFee,
                msg.sender // refund address
            );
        }
        
        // Send tokens via Axelar Gateway
        gateway.sendToken(
            destinationChain, 
            destinationAddress, 
            TOKEN_SYMBOL, 
            amountAfterFee
        );
        
        emit USDCSent(
            msg.sender, 
            destinationChain, 
            destinationAddress, 
            amountAfterFee,
            fee
        );
    }
    
    /**
     * @dev Set the fee percentage
     * @param _feePercentage New fee percentage in basis points
     */
    function setFeePercentage(uint16 _feePercentage) external onlyOwner {
        require(_feePercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        feePercentage = _feePercentage;
        emit FeePercentageUpdated(_feePercentage);
    }
    
    /**
     * @dev Withdraw collected fees
     * @param to Address to send the fees to
     */
    function withdrawFees(address to) external onlyOwner {
        IERC20 usdc = IERC20(usdcAddress);
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No fees to withdraw");
        require(usdc.transfer(to, balance), "Fee withdrawal failed");
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