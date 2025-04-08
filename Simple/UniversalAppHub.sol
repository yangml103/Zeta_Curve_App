// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Struct from ZetaChain Gateway documentation
struct RevertOptions {
    address revertAddress;
    bool callOnRevert;
    address abortAddress;
    bytes revertMessage;
    uint256 onRevertGasLimit;
}

/**
 * @title UniversalAppHub
 * @dev A central contract on ZetaChain to receive deposits from EVM and Solana chains
 *      via their respective Gateways and manage withdrawals back to origin chains.
 *      Implements the UniversalContract interface to handle `onCall`.
 */
contract UniversalAppHub is UniversalContract, Ownable {
    using SafeERC20 for IERC20;

    address public immutable zetaToken; // Address of the ZETA token on ZetaChain

    // --- Events ---
    event IncomingDeposit(
        uint256 indexed sourceChainId,
        bytes senderAddress, // Address on the source chain
        address indexed receivedZRC20, // The ZRC-20 token address received on ZetaChain
        uint256 amount,
        bytes message // The payload sent with depositAndCall
    );

    event WithdrawalInitiated(
        address indexed user,
        address indexed tokenWithdrawn, // ZRC-20 address withdrawn from ZetaChain
        uint256 amount,
        uint256 indexed destinationChainId, // Origin chain of the tokenWithdrawn
        bytes destinationAddress // Address on the destination chain
    );

    // --- Constructor ---
    /**
     * @param _zetaToken Address of the ZETA token contract on ZetaChain.
     * @param _initialOwner Owner of the contract.
     */
    constructor(address _zetaToken, address _initialOwner) Ownable(_initialOwner) {
        require(_zetaToken != address(0), "Invalid Zeta Token address");
        zetaToken = _zetaToken;
    }

    // --- UniversalContract Interface ---

    /**
     * @inheritdoc UniversalContract
     * @dev Handles incoming calls from connected chain gateways (EVM, Solana) via `depositAndCall`.
     *      For this version, it just logs the incoming deposit.
     *      
     */
    function onCall(
        MessageContext calldata context,
        address zrc20, // Address of the ZRC-20 token received (e.g., ZRC-20 ETH, ZRC-20 SOL)
        uint256 amount,
        bytes calldata message // Payload from the gateway call
    ) external virtual override onlyGateway{
        // Basic validation: Ensure the caller is the ZetaChain system contract (or expected gateway interface)

        // Log the details of the incoming deposit
        emit IncomingDeposit(
            context.chainID, // ID of the chain the deposit came from
            context.sender,  // Sender address on the source chain (bytes format)
            zrc20,           // The ZRC-20 representation received on ZetaChain
            amount,
            message
        );

        // --- TODO: Implement Intermediary Token Logic ---
        // 1. Identify the ZRC-20 token received (zrc20).
        // 2. Determine the 'actual' recipient address on ZetaChain (might be encoded in 'message').
        // 3. Mint/Swap `zrc20` for an internal representation token (like OmniUSDT) and credit the recipient.
        // Example: _mintIntermediaryToken(decodeRecipient(message), amount);
    }

    // --- Withdrawal Functions (NOT IMPLEMENTED) ---

    /**
     * @dev Initiates withdrawal of a ZRC-20 token back to its EVM origin chain.
     *      (Placeholder - requires implementation)
     * @param _tokenToWithdraw The ZRC-20 address on ZetaChain to withdraw.
     * @param _amount Amount to withdraw.
     * @param _destinationAddress The recipient address (bytes format) on the EVM origin chain.
     */
    function redeemForEVM(
        address _tokenToWithdraw,
        uint256 _amount,
        bytes calldata _destinationAddress
        // uint256 _destinationChainId //  the origin chain of _tokenToWithdraw
    ) external {

         revert("redeemForEVM: Not implemented");
    }

     /**
     * @dev Initiates withdrawal of a ZRC-20 token back to its Solana origin chain.
     *      (Placeholder - requires implementation)
     * @param _tokenToWithdraw The ZRC-20 address on ZetaChain to withdraw.
     * @param _amount Amount to withdraw.
     * @param _destinationAddress The recipient address (bytes format) on the Solana origin chain.
     */
    function redeemForSolana(
        address _tokenToWithdraw,
        uint256 _amount,
        bytes calldata _destinationAddress
        // uint256 _destinationChainId // Implicitly the origin chain of _tokenToWithdraw
    ) external /* payable - if requires user fee */ {
        // --- TODO: Implement Withdrawal Logic ---
         revert("redeemForSolana: Not implemented");
    }

} 