// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zeta.sol";
import "./OmniUSDT.sol";

// Structs from ZetaChain Gateway documentation
struct RevertOptions {
    address revertAddress;
    bool callOnRevert;
    address abortAddress;
    bytes revertMessage;
    uint256 onRevertGasLimit;
}

struct CallOptions { // Defined but not used in this simplified version
    uint256 gasLimit;
    bool isArbitraryCall;
}

/**
 * @title ZetaGatewayStablecoinPool
 * @dev A Curve-like pool for swapping between different stablecoins on ZetaChain using Zeta Gateway.
 * This pool uses the StableSwap invariant (x^3*y + y^3*x >= k) for efficient
 * stablecoin swaps with low slippage.
 */
contract ZetaGatewayStablecoinPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants for calculations
    uint256 private constant A_PRECISION = 100;
    uint256 private constant FEE_DENOMINATOR = 10000;
    
    // Pool parameters
    uint256 public amplificationParameter; // Amplification parameter (A) * A_PRECISION
    uint256 public swapFee; // Fee taken on swaps (in basis points)
    uint256 public adminFee; // Percentage of swap fee taken as admin fee (in basis points)
    
    // Tokens in the pool
    address[] public tokens;
    mapping(address => bool) public isToken;
    mapping(address => uint256) public tokenIndexes;
    
    // Balances of tokens in the pool
    uint256[] public balances;
    
    // LP token (represents pool share)
    OmniUSDT public lpToken;
    
    // ZetaChain Gateway for cross-chain messaging
    address public zetaToken;
    
    // Events
    event TokenSwap(
        address indexed buyer,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event SwapAndWithdraw(
        address indexed user,
        bytes indexed destinationAddress, // Address on destination chain
        address indexed tokenIn,  // Token swapped from
        address indexed tokenOut, // ZRC-20 token withdrawn
        uint256 amountIn,
        uint256 amountOut, // Amount of tokenOut withdrawn
        uint256 destinationChainId // Origin chain of tokenOut
    );
    
    event AddLiquidity(
        address indexed provider,
        uint256[] amounts,
        uint256 mintAmount
    );
    
    event RemoveLiquidity(
        address indexed provider,
        uint256[] amounts,
        uint256 burnAmount
    );
    
    event ParametersUpdated(
        uint256 amplificationParameter,
        uint256 swapFee,
        uint256 adminFee
    );

    event PoolInitialized(address factory);

    bool public initialized;
    address public factory;

    /**
     * @dev Constructor to create a new ZetaGatewayStablecoinPool
     * @param _tokens Array of token addresses in the pool
     * @param _amplificationParameter Amplification parameter (A) * A_PRECISION
     * @param _swapFee Fee taken on swaps (in basis points)
     * @param _adminFee Percentage of swap fee taken as admin fee (in basis points)
     * @param _lpToken Address of the LP token (OmniUSDT)
     * @param _zetaToken Address of the Zeta Token
     */
    constructor(
        address[] memory _tokens,
        uint256 _amplificationParameter,
        uint256 _swapFee,
        uint256 _adminFee,
        address _lpToken,
        address _zetaToken
    ) Ownable(msg.sender) {
        require(_tokens.length >= 2, "At least 2 tokens required");
        require(_amplificationParameter >= A_PRECISION, "A too low");
        require(_swapFee <= 100, "Fee too high"); // Max 1%
        require(_adminFee <= FEE_DENOMINATOR, "Admin fee too high");
        require(_lpToken != address(0), "Invalid LP token");
        
        amplificationParameter = _amplificationParameter;
        swapFee = _swapFee;
        adminFee = _adminFee;
        lpToken = OmniUSDT(_lpToken);
        zetaToken = _zetaToken;
        
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "Invalid token");
            require(!isToken[_tokens[i]], "Duplicate token");
            
            tokens.push(_tokens[i]);
            isToken[_tokens[i]] = true;
            tokenIndexes[_tokens[i]] = i;
            balances.push(0);
        }
    }
    
    /**
     * @dev Initialize the pool with the Zeta Gateway
     * @param _factory Address of the factory contract
     */
    function initialize(address _factory) external {
        require(!initialized, "Pool already initialized");
        require(_factory != address(0), "Invalid factory address");
        
        factory = _factory;
        
        // Set up Zeta Gateway permissions
        zeta(zetaToken).approve(address(zeta(zetaToken)), type(uint256).max);
        
        // Set up token approvals for the pool
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(zeta(zetaToken)), type(uint256).max);
        }
        
        initialized = true;
        
        emit PoolInitialized(_factory);
    }
    
    /**
     * @dev Add liquidity to the pool
     * @param _amounts Array of token amounts to add
     * @param _minMintAmount Minimum LP tokens to mint
     * @return mintAmount Amount of LP tokens minted
     */
    function addLiquidity(
        uint256[] memory _amounts,
        uint256 _minMintAmount
    ) external nonReentrant returns (uint256 mintAmount) {
        require(_amounts.length == tokens.length, "Invalid amounts length");
        
        uint256[] memory fees = new uint256[](tokens.length);
        uint256 _fee = swapFee * tokens.length / (4 * (tokens.length - 1));
        uint256 _adminFee = adminFee;
        uint256 totalSupply = lpToken.totalSupply();
        
        // Initial liquidity provision
        if (totalSupply == 0) {
            uint256 d = 0;
            for (uint256 i = 0; i < tokens.length; i++) {
                require(_amounts[i] > 0, "Initial liquidity must be non-zero");
                IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
                balances[i] = _amounts[i];
                d += _amounts[i];
            }
            
            // Mint LP tokens proportional to the value of tokens provided
            mintAmount = d;
            require(mintAmount >= _minMintAmount, "Slippage limit reached");
            lpToken.mint(msg.sender, mintAmount);
        } else {
            // Calculate current invariant
            uint256 d0 = getD(balances);
            
            // Transfer tokens to the pool
            uint256[] memory newBalances = new uint256[](tokens.length);
            for (uint256 i = 0; i < tokens.length; i++) {
                newBalances[i] = balances[i];
                if (_amounts[i] > 0) {
                    IERC20(tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
                    newBalances[i] += _amounts[i];
                }
            }
            
            // Calculate new invariant
            uint256 d1 = getD(newBalances);
            require(d1 > d0, "D must increase");
            
            // Calculate mint amount and fees
            uint256 idealBalance = 0;
            for (uint256 i = 0; i < tokens.length; i++) {
                idealBalance = d1 * balances[i] / d0;
                uint256 diff = 0;
                if (newBalances[i] > idealBalance) {
                    diff = newBalances[i] - idealBalance;
                } else {
                    diff = idealBalance - newBalances[i];
                }
                fees[i] = _fee * diff / FEE_DENOMINATOR;
                balances[i] = newBalances[i] - (fees[i] * _adminFee / FEE_DENOMINATOR);
                newBalances[i] -= fees[i];
            }
            
            // Calculate mint amount based on the ratio of new to old invariant
            uint256 d2 = getD(newBalances);
            mintAmount = totalSupply * (d2 - d0) / d0;
            require(mintAmount >= _minMintAmount, "Slippage limit reached");
            
            // Mint LP tokens
            lpToken.mint(msg.sender, mintAmount);
        }
        
        emit AddLiquidity(msg.sender, _amounts, mintAmount);
        return mintAmount;
    }
    
    /**
     * @dev Remove liquidity from the pool
     * @param _burnAmount Amount of LP tokens to burn
     * @param _minAmounts Minimum token amounts to receive
     * @return amounts Array of token amounts received
     */
    function removeLiquidity(
        uint256 _burnAmount,
        uint256[] memory _minAmounts
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(_minAmounts.length == tokens.length, "Invalid minAmounts length");
        
        uint256 totalSupply = lpToken.totalSupply();
        require(_burnAmount <= lpToken.balanceOf(msg.sender), "Insufficient LP tokens");
        
        // Calculate token amounts to return
        amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = balances[i] * _burnAmount / totalSupply;
            require(amounts[i] >= _minAmounts[i], "Slippage limit reached");
            balances[i] -= amounts[i];
            IERC20(tokens[i]).safeTransfer(msg.sender, amounts[i]);
        }
        
        // Burn LP tokens
        lpToken.burnFrom(msg.sender, _burnAmount);
        
        emit RemoveLiquidity(msg.sender, amounts, _burnAmount);
        return amounts;
    }
    
    /**
     * @dev Swap tokens locally within the pool on ZetaChain.
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input token
     * @param _minAmountOut Minimum amount of output token
     * @return amountOut Amount of output token received by the pool (before transfer to user)
     */
    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    ) public nonReentrant returns (uint256 amountOut) {
        require(isToken[_tokenIn] && isToken[_tokenOut], "Invalid tokens");
        require(_tokenIn != _tokenOut, "Same tokens");
        require(_amountIn > 0, "Invalid amount");
        
        uint256 indexIn = tokenIndexes[_tokenIn];
        uint256 indexOut = tokenIndexes[_tokenOut];
        
        // Transfer input token to the pool
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        
        // Calculate output amount based on current balances
        uint256[] memory currentBalances = balances; // Use current balances for calculation
        uint256 newBalanceIn = currentBalances[indexIn] + _amountIn;
        uint256 newBalanceOut = getY(indexIn, indexOut, newBalanceIn, currentBalances);
        
        // Calculate fee
        uint256 fee = swapFee * (currentBalances[indexOut] - newBalanceOut) / FEE_DENOMINATOR;
        amountOut = currentBalances[indexOut] - newBalanceOut - fee;
        
        // Update pool balances *after* calculation
        balances[indexIn] = newBalanceIn;
        // Admin fee accrues by *not* reducing the balance as much as the full fee
        balances[indexOut] = currentBalances[indexOut] - amountOut - (fee * (FEE_DENOMINATOR - adminFee) / FEE_DENOMINATOR);
        // balances[indexOut] = newBalanceOut + fee * adminFee / FEE_DENOMINATOR; // Alternative fee accounting
        
        require(amountOut >= _minAmountOut, "Slippage limit reached");
        
        // Transfer output token to the user *on ZetaChain*
        IERC20(_tokenOut).safeTransfer(msg.sender, amountOut);
        
        emit TokenSwap(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
        return amountOut;
    }
    
    /**
     * @dev Perform a local swap and then withdraw the output ZRC-20 token to its originating chain using Zeta Gateway.
     * Note: The _destinationChainId MUST be the origin chain of _tokenOut.
     * @param _tokenIn Address of the input token (on ZetaChain)
     * @param _tokenOut Address of the output ZRC-20 token (on ZetaChain) to be withdrawn
     * @param _amountIn Amount of input tokens
     * @param _minAmountOut Minimum amount of output tokens expected from the swap
     * @param _destinationChainId The originating chain ID of _tokenOut.
     * @param _destinationAddress Address (bytes format) on the destination chain to receive _tokenOut.
     */
    function swapAndWithdraw(
        address _tokenIn,
        address _tokenOut, // The ZRC-20 to be withdrawn
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _destinationChainId, // Must be origin chain of _tokenOut
        bytes calldata _destinationAddress // Ensure this is properly formatted bytes
    ) external whenNotPaused nonReentrant {
        require(initialized, "Pool not initialized");
        require(isToken[_tokenIn], "Invalid input token");
        require(isToken[_tokenOut], "Invalid output token");
        require(_amountIn > 0, "Invalid amount");
        // require(zeta(_tokenOut).originChainId() == _destinationChainId, "Destination chain must be the ZRC-20's origin chain"); // Example check - requires ZRC20 interface update or storing origin info
        require(supportedChains[_destinationChainId], "Destination chain not supported for withdrawal"); // Check if factory supports it

        uint256 indexIn = tokenIndexes[_tokenIn];
        uint256 indexOut = tokenIndexes[_tokenOut];

        // Transfer input tokens from sender to pool
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);

        // --- Perform Swap Calculation --- 
        uint256[] memory currentBalances = balances; // Use current balances for calculation
        uint256 newBalanceIn = currentBalances[indexIn] + _amountIn;
        uint256 newBalanceOut = getY(indexIn, indexOut, newBalanceIn, currentBalances);
        uint256 fee = swapFee * (currentBalances[indexOut] - newBalanceOut) / FEE_DENOMINATOR;
        uint256 amountOut = currentBalances[indexOut] - newBalanceOut - fee;
        require(amountOut >= _minAmountOut, "Insufficient output amount from swap");

        // --- Update Pool Balances --- 
        balances[indexIn] = newBalanceIn;
        balances[indexOut] = currentBalances[indexOut] - amountOut - (fee * (FEE_DENOMINATOR - adminFee) / FEE_DENOMINATOR);
        // Note: The output amount (`amountOut`) is *not* sent to the user on ZetaChain here.
        // Instead, it is made available for withdrawal via the gateway.

        // --- Initiate Withdrawal via Gateway --- 
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: msg.sender, // On revert, ZRC-20 _tokenOut goes back to sender on ZetaChain
            callOnRevert: false,
            abortAddress: address(0), // Or a designated abort handler
            revertMessage: "",
            onRevertGasLimit: 0 // Gas is free for reverts on ZetaChain originating CCTX
        });

        // Withdraw the calculated `amountOut` of `_tokenOut` using Zeta Gateway
        // The gateway handles fees.
        zeta(zetaToken).withdraw(
            _destinationAddress,
            amountOut,     // The amount calculated from the swap
            _tokenOut,     // The ZRC-20 being withdrawn
            revertOptions
        );

        emit SwapAndWithdraw(
            msg.sender,
            _destinationAddress,
            _tokenIn,
            _tokenOut,
            _amountIn,
            amountOut,
            _destinationChainId
        );
    }
    
    /**
     * @dev Get the amount of output token for a given input amount
     * @param _tokenIn Address of the input token
     * @param _tokenOut Address of the output token
     * @param _amountIn Amount of input token
     * @return Amount of output token
     */
    function getSwapAmount(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256) {
        require(isToken[_tokenIn] && isToken[_tokenOut], "Invalid tokens");
        require(_tokenIn != _tokenOut, "Same tokens");
        
        uint256 indexIn = tokenIndexes[_tokenIn];
        uint256 indexOut = tokenIndexes[_tokenOut];
        
        uint256 newBalanceIn = balances[indexIn] + _amountIn;
        uint256 newBalanceOut = getY(indexIn, indexOut, newBalanceIn, balances);
        
        uint256 fee = swapFee * (balances[indexOut] - newBalanceOut) / FEE_DENOMINATOR;
        return balances[indexOut] - newBalanceOut - fee;
    }
    
    /**
     * @dev Update pool parameters
     * @param _amplificationParameter New amplification parameter
     * @param _swapFee New swap fee
     * @param _adminFee New admin fee
     */
    function updateParameters(
        uint256 _amplificationParameter,
        uint256 _swapFee,
        uint256 _adminFee
    ) external onlyOwner {
        require(_amplificationParameter >= A_PRECISION, "A too low");
        require(_swapFee <= 100, "Fee too high"); // Max 1%
        require(_adminFee <= FEE_DENOMINATOR, "Admin fee too high");
        
        amplificationParameter = _amplificationParameter;
        swapFee = _swapFee;
        adminFee = _adminFee;
        
        emit ParametersUpdated(_amplificationParameter, _swapFee, _adminFee);
    }
    
    /**
     * @dev Calculate the StableSwap invariant (D)
     * @param _balances Array of token balances
     * @return D value
     */
    function getD(uint256[] memory _balances) public view returns (uint256) {
        uint256 sum = 0;
        uint256 n = _balances.length;
        for (uint256 i = 0; i < n; i++) {
            sum += _balances[i];
        }
        if (sum == 0) {
            return 0;
        }
        
        uint256 d = sum;
        uint256 ann = amplificationParameter * n;
        
        for (uint256 i = 0; i < 255; i++) {
            uint256 dPrev = d;
            uint256 dP = d;
            
            for (uint256 j = 0; j < n; j++) {
                dP = dP * d / (_balances[j] * n);
            }
            
            d = (ann * sum + dP * n) * d / ((ann - 1) * d + (n + 1) * dP);
            
            if (d > dPrev) {
                if (d - dPrev <= 1) {
                    break;
                }
            } else {
                if (dPrev - d <= 1) {
                    break;
                }
            }
        }
        
        return d;
    }
    
    /**
     * @dev Calculate the new balance of token j given the new balance of token i
     * @param i Index of token i
     * @param j Index of token j
     * @param x New balance of token i
     * @param _balances Current balances
     * @return New balance of token j
     */
    function getY(
        uint256 i,
        uint256 j,
        uint256 x,
        uint256[] memory _balances
    ) internal view returns (uint256) {
        require(i != j, "Same tokens");
        require(i < tokens.length && j < tokens.length, "Invalid token index");
        
        uint256 n = _balances.length;
        uint256 d = getD(_balances);
        uint256 ann = amplificationParameter * n;
        uint256 c = d;
        uint256 s = 0;
        
        for (uint256 k = 0; k < n; k++) {
            if (k == j) {
                continue;
            }
            
            uint256 _x = k == i ? x : _balances[k];
            s += _x;
            c = c * d / (_x * n);
        }
        
        c = c * d / (ann * n);
        uint256 b = s + d / ann;
        
        uint256 y = d;
        for (uint256 k = 0; k < 255; k++) {
            uint256 yPrev = y;
            y = (y * y + c) / (2 * y + b - d);
            
            if (y > yPrev) {
                if (y - yPrev <= 1) {
                    break;
                }
            } else {
                if (yPrev - y <= 1) {
                    break;
                }
            }
        }
        
        return y;
    }
    
    /**
     * @dev Get the gas limit for a specific chain (Informational)
     * @param _chainId Chain ID to get gas limit for
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