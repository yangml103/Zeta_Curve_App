// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarExecutable.sol";

/**
 * @title FluidUSDC
 * @dev ERC20 token that represents a share in the cross-chain USDC liquidity pool
 */
contract FluidUSDC is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("Fluid USDC", "flUSDC") ERC20Permit("Fluid USDC") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyRole(BURNER_ROLE) {
        _burn(account, amount);
    }
}

/**
 * @title AxelarUSDCPool
 * @dev Cross-chain liquidity pool for USDC using Axelar for interoperability
 */
contract AxelarUSDCPool is IAxelarExecutable, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    
    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // State variables
    FluidUSDC public fluidUSDC;
    IAxelarGateway public immutable gateway;
    IAxelarGasService public immutable gasService;
    address public usdcAddress;
    
    // Fee variables
    uint256 public depositFee = 5; // 0.05%
    uint256 public withdrawFee = 5; // 0.05%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 100; // 1%
    
    // Chain tracking
    mapping(string => bool) public supportedChains;
    mapping(string => mapping(string => bool)) public trustedSenders;
    
    // Slippage protection
    uint256 public maxSlippage = 100; // 1%
    
    // Events
    event Deposit(address indexed user, uint256 usdcAmount, uint256 sharesReceived, uint256 fee);
    event Withdrawal(address indexed user, uint256 sharesAmount, uint256 usdcReceived, uint256 fee);
    event CrossChainDeposit(string sourceChain, string sourceAddress, address indexed user, uint256 amount);
    event CrossChainWithdrawal(string destinationChain, string destinationAddress, address indexed user, uint256 amount);
    event FeeUpdated(uint256 newDepositFee, uint256 newWithdrawFee);
    event ChainSupportUpdated(string chainName, bool isSupported);
    event TrustedSenderUpdated(string chainName, string senderAddress, bool isTrusted);
    
    /**
     * @dev Constructor
     * @param _gateway Axelar Gateway contract address
     * @param _gasService Axelar Gas Service contract address
     * @param _usdcAddress USDC token address on this chain
     */
    constructor(address _gateway, address _gasService, address _usdcAddress) IAxelarExecutable(_gateway) {
        gateway = IAxelarGateway(_gateway);
        gasService = IAxelarGasService(_gasService);
        usdcAddress = _usdcAddress;
        
        fluidUSDC = new FluidUSDC();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Calculate the number of shares to mint for a deposit
     * @param usdcAmount The amount of USDC being deposited
     * @return The number of shares to mint
     */
    function calculateSharesToMint(uint256 usdcAmount) public view returns (uint256) {
        uint256 totalShares = fluidUSDC.totalSupply();
        uint256 poolUSDC = IERC20(usdcAddress).balanceOf(address(this));
        
        if (totalShares == 0 || poolUSDC == 0) {
            return usdcAmount;
        } else {
            return usdcAmount.mul(totalShares).div(poolUSDC);
        }
    }
    
    /**
     * @dev Calculate the amount of USDC to return for a withdrawal
     * @param sharesAmount The number of shares being redeemed
     * @return The amount of USDC to return
     */
    function calculateUSDCToReturn(uint256 sharesAmount) public view returns (uint256) {
        uint256 totalShares = fluidUSDC.totalSupply();
        uint256 poolUSDC = IERC20(usdcAddress).balanceOf(address(this));
        
        if (totalShares == 0) {
            return 0;
        } else {
            return sharesAmount.mul(poolUSDC).div(totalShares);
        }
    }
    
    /**
     * @dev Deposit USDC and receive pool shares
     * @param usdcAmount The amount of USDC to deposit
     * @param minSharesAmount Minimum shares to receive (slippage protection)
     */
    function deposit(uint256 usdcAmount, uint256 minSharesAmount) external nonReentrant {
        require(usdcAmount > 0, "Deposit amount must be greater than 0");
        
        // Calculate fee
        uint256 fee = usdcAmount.mul(depositFee).div(FEE_DENOMINATOR);
        uint256 usdcAmountAfterFee = usdcAmount.sub(fee);
        
        // Calculate shares to mint
        uint256 sharesToMint = calculateSharesToMint(usdcAmountAfterFee);
        require(sharesToMint >= minSharesAmount, "Slippage too high");
        
        // Transfer USDC from user to this contract
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        // Mint FluidUSDC shares to user
        fluidUSDC.mint(msg.sender, sharesToMint);
        
        emit Deposit(msg.sender, usdcAmount, sharesToMint, fee);
    }
    
    /**
     * @dev Withdraw USDC by redeeming pool shares
     * @param sharesAmount The amount of shares to redeem
     * @param minUSDCAmount Minimum USDC to receive (slippage protection)
     */
    function withdraw(uint256 sharesAmount, uint256 minUSDCAmount) external nonReentrant {
        require(sharesAmount > 0, "Withdraw amount must be greater than 0");
        
        // Calculate USDC to return
        uint256 usdcToReturn = calculateUSDCToReturn(sharesAmount);
        
        // Calculate fee
        uint256 fee = usdcToReturn.mul(withdrawFee).div(FEE_DENOMINATOR);
        uint256 usdcAmountAfterFee = usdcToReturn.sub(fee);
        
        require(usdcAmountAfterFee >= minUSDCAmount, "Slippage too high");
        
        // Burn FluidUSDC shares from user
        fluidUSDC.burnFrom(msg.sender, sharesAmount);
        
        // Transfer USDC to user
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transfer(msg.sender, usdcAmountAfterFee), "USDC transfer failed");
        
        emit Withdrawal(msg.sender, sharesAmount, usdcAmountAfterFee, fee);
    }
    
    /**
     * @dev Withdraw USDC to another chain
     * @param sharesAmount The amount of shares to redeem
     * @param destinationChain The destination chain name
     * @param destinationAddress The recipient address on the destination chain
     * @param minUSDCAmount Minimum USDC to receive (slippage protection)
     */
    function withdrawToChain(
        uint256 sharesAmount,
        string calldata destinationChain,
        string calldata destinationAddress,
        uint256 minUSDCAmount
    ) external payable nonReentrant {
        require(sharesAmount > 0, "Withdraw amount must be greater than 0");
        require(supportedChains[destinationChain], "Destination chain not supported");
        
        // Calculate USDC to return
        uint256 usdcToReturn = calculateUSDCToReturn(sharesAmount);
        
        // Calculate fee
        uint256 fee = usdcToReturn.mul(withdrawFee).div(FEE_DENOMINATOR);
        uint256 usdcAmountAfterFee = usdcToReturn.sub(fee);
        
        require(usdcAmountAfterFee >= minUSDCAmount, "Slippage too high");
        
        // Burn FluidUSDC shares from user
        fluidUSDC.burnFrom(msg.sender, sharesAmount);
        
        // Approve Gateway to spend USDC
        IERC20 usdc = IERC20(usdcAddress);
        usdc.approve(address(gateway), usdcAmountAfterFee);
        
        // Pay for gas if needed
        if (msg.value > 0) {
            gasService.payNativeGasForTokenTransfer{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                "USDC",
                usdcAmountAfterFee,
                msg.sender // refund address
            );
        }
        
        // Send tokens via Axelar Gateway
        gateway.sendToken(
            destinationChain,
            destinationAddress,
            "USDC",
            usdcAmountAfterFee
        );
        
        emit CrossChainWithdrawal(destinationChain, destinationAddress, msg.sender, usdcAmountAfterFee);
    }
    
    /**
     * @dev Execute function that's called by Axelar Gateway when tokens are received
     * @param sourceChain The source chain name
     * @param sourceAddress The sender address on the source chain
     * @param payload Additional payload data (may contain user address)
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        // This is called for non-token contract calls
        // Not used in this implementation
    }
    
    /**
     * @dev Called by the Axelar Gateway when tokens are sent to this contract
     * @param sourceChain The source chain name
     * @param sourceAddress The sender address on the source chain
     * @param payload Additional payload data (contains user address)
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
        
        // Verify that the source chain is supported
        require(supportedChains[sourceChain], "Source chain not supported");
        
        // Verify that the source address is trusted
        require(trustedSenders[sourceChain][sourceAddress], "Source address not trusted");
        
        // Calculate fee
        uint256 fee = amount.mul(depositFee).div(FEE_DENOMINATOR);
        uint256 amountAfterFee = amount.sub(fee);
        
        // Decode the payload to get the user address (recipient)
        address user = abi.decode(payload, (address));
        
        // Calculate shares to mint
        uint256 sharesToMint = calculateSharesToMint(amountAfterFee);
        
        // Mint FluidUSDC shares to user
        fluidUSDC.mint(user, sharesToMint);
        
        emit CrossChainDeposit(sourceChain, sourceAddress, user, amount);
    }
    
    /**
     * @dev Set fees for deposits and withdrawals
     * @param _depositFee New deposit fee in basis points
     * @param _withdrawFee New withdrawal fee in basis points
     */
    function setFees(uint256 _depositFee, uint256 _withdrawFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_depositFee <= MAX_FEE, "Deposit fee too high");
        require(_withdrawFee <= MAX_FEE, "Withdraw fee too high");
        
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
        
        emit FeeUpdated(_depositFee, _withdrawFee);
    }
    
    /**
     * @dev Set supported chain
     * @param chainName The chain name to set as supported or unsupported
     * @param isSupported Whether the chain should be supported
     */
    function setSupportedChain(string calldata chainName, bool isSupported) external onlyRole(OPERATOR_ROLE) {
        supportedChains[chainName] = isSupported;
        emit ChainSupportUpdated(chainName, isSupported);
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
    ) external onlyRole(OPERATOR_ROLE) {
        trustedSenders[chainName][senderAddress] = isTrusted;
        emit TrustedSenderUpdated(chainName, senderAddress, isTrusted);
    }
    
    /**
     * @dev Set maximum slippage
     * @param _maxSlippage New maximum slippage in basis points
     */
    function setMaxSlippage(uint256 _maxSlippage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxSlippage <= 1000, "Max slippage too high"); // Max 10%
        maxSlippage = _maxSlippage;
    }
    
    /**
     * @dev Withdraw collected fees
     * @param to Address to send the fees to
     */
    function withdrawFees(address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Calculate total fees
        uint256 totalUSDC = IERC20(usdcAddress).balanceOf(address(this));
        uint256 totalShareValue = fluidUSDC.totalSupply() == 0 ? 0 : 
            fluidUSDC.totalSupply().mul(totalUSDC).div(fluidUSDC.totalSupply());
        
        uint256 feesAmount = totalUSDC > totalShareValue ? totalUSDC.sub(totalShareValue) : 0;
        
        require(feesAmount > 0, "No fees to withdraw");
        
        // Transfer fees
        IERC20 usdc = IERC20(usdcAddress);
        require(usdc.transfer(to, feesAmount), "Fee withdrawal failed");
    }
    
    /**
     * @dev Recover any accidentally sent ERC20 tokens
     * @param tokenAddress The token address to recover
     * @param to Recipient address
     */
    function recoverTokens(address tokenAddress, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(tokenAddress != usdcAddress, "Cannot recover pool token");
        require(tokenAddress != address(fluidUSDC), "Cannot recover share token");
        
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to recover");
        require(token.transfer(to, balance), "Token recovery failed");
    }
    
    /**
     * @dev Recover any accidentally sent ETH
     * @param to Recipient address
     */
    function recoverEth(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to recover");
        to.transfer(balance);
    }
} 