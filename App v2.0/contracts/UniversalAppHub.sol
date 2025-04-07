// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/zeta.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Added for potential use in withdrawals


// Struct from ZetaChain Gateway documentation (needed for zeta.withdraw later)
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
 *      Uses an internal mapping (`hubTokenBalances`) as a simple intermediary token representation.
 */
contract UniversalAppHub is UniversalContract, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable zetaToken; // Address of the ZETA token on ZetaChain

    // --- Intermediary Token Representation ---
    mapping(address => uint256) public hubTokenBalances; // Internal balance tracking

    // --- ZRC-20 Origin Chain Mapping ---
    mapping(address => uint256) public zrc20OriginChain; // ZRC-20 address => Origin Chain ID

    // --- Events ---
    event IncomingDeposit(
        uint256 indexed sourceChainId,
        bytes senderAddress, // Address on the source chain
        address indexed recipientOnZetaChain, // Decoded recipient address
        address indexed receivedZRC20, // The ZRC-20 token address received on ZetaChain
        uint256 amount,
        bytes message // Original payload sent with depositAndCall
    );

    event WithdrawalInitiated(
        address indexed user,
        address indexed tokenWithdrawn, // ZRC-20 address withdrawn from ZetaChain
        uint256 amount,
        uint256 indexed destinationChainId, // Origin chain of the tokenWithdrawn
        bytes destinationAddress // Address on the destination chain
    );

    // Event for internal balance changes
    event HubTokenTransfer(address indexed from, address indexed to, uint256 amount);

    event Zrc20OriginSet(address indexed zrc20, uint256 indexed chainId);

    // --- Constructor ---
    /**
     * @param _zetaToken Address of the ZETA token contract on ZetaChain.
     * @param _initialOwner Owner of the contract.
     */
    constructor(address _zetaToken, address _initialOwner) Ownable(_initialOwner) {
        require(_zetaToken != address(0), "Invalid Zeta Token address");
        zetaToken = _zetaToken;
    }

    // --- Configuration Functions ---
    /**
     * @dev Sets the origin chain ID for a given ZRC-20 token address.
     *      Needed for the `withdraw` function constraint.
     * @param _zrc20 The address of the ZRC-20 token on ZetaChain.
     * @param _chainId The origin chain ID of the ZRC-20 token.
     */
    function setZrc20Origin(address _zrc20, uint256 _chainId) external onlyOwner {
        require(_zrc20 != address(0), "Invalid ZRC-20 address");
        require(_chainId > 0, "Invalid chain ID"); // Basic check
        zrc20OriginChain[_zrc20] = _chainId;
        emit Zrc20OriginSet(_zrc20, _chainId);
    }

    // --- UniversalContract Interface ---

    /**
     * @inheritdoc UniversalContract
     * @dev Handles incoming calls from connected chain gateways (EVM, Solana) via `depositAndCall`.
     *      Decodes the recipient ZetaChain address from the message payload.
     *      Mints internal HubTokens to the recipient.
     * @param context Contextual information about the cross-chain call.
     * @param zrc20 Address of the ZRC-20 token received (e.g., ZRC-20 ETH, ZRC-20 SOL).
     * @param amount Amount of the zrc20 token received.
     * @param message Payload from the gateway call, expected to be abi.encode(address recipientOnZetaChain).
     */
    function onCall(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override {
        // Decode the intended recipient address on ZetaChain from the message payload
        address recipient = decodeRecipient(message);
        require(recipient != address(0), "Invalid recipient address in message");

        // --- TODO: Add validation for caller if necessary ---
        // require(msg.sender == address(zeta(zetaToken)), "Caller must be Zeta system"); // Review if this is correct/needed

        // Log the details of the incoming deposit
        emit IncomingDeposit(
            context.chainID, // ID of the chain the deposit came from
            context.sender,  // Sender address on the source chain (bytes format)
            recipient,       // Decoded recipient address on ZetaChain
            zrc20,           // The ZRC-20 representation received on ZetaChain
            amount,
            message
        );

        // --- Intermediary Token Logic ---
        // For simplicity, we assume 1:1 value between deposited ZRC-20 and HubToken.
        // A real app might have exchange rates or require specific ZRC-20s.
        _mintHubToken(recipient, amount);

        // Optional: Hold the received ZRC-20 tokens in this contract
        // If not held, they need to be managed/swapped elsewhere.
        // Example: IERC20(zrc20).safeTransferFrom(address(zeta(zetaToken)), address(this), amount); // Might require approvals
    }

    // --- Withdrawal Functions (Placeholders) ---

    /**
     * @dev Initiates withdrawal of a ZRC-20 token back to its EVM origin chain.
     *      Burns the user's internal HubToken balance.
     *      Calls the ZetaChain Gateway `withdraw` function.
     * @param _tokenToWithdraw The ZRC-20 address on ZetaChain to withdraw.
     * @param _amount Amount to withdraw (in terms of _tokenToWithdraw).
     * @param _destinationAddress The recipient address (bytes format) on the origin chain.
     */
    function redeemForEVM(
        address _tokenToWithdraw,
        uint256 _amount,
        bytes calldata _destinationAddress
    ) external nonReentrant {
        _redeem(_tokenToWithdraw, _amount, _destinationAddress);
    }

     /**
     * @dev Initiates withdrawal of a ZRC-20 token back to its Solana origin chain.
     *      Burns the user's internal HubToken balance.
     *      Calls the ZetaChain Gateway `withdraw` function.
     * @param _tokenToWithdraw The ZRC-20 address on ZetaChain to withdraw.
     * @param _amount Amount to withdraw (in terms of _tokenToWithdraw).
     * @param _destinationAddress The recipient address (bytes format) on the origin chain.
     */
    function redeemForSolana(
        address _tokenToWithdraw,
        uint256 _amount,
        bytes calldata _destinationAddress
    ) external nonReentrant {
         _redeem(_tokenToWithdraw, _amount, _destinationAddress);
    }

    /**
     * @dev Internal function to handle the common withdrawal logic.
     */
    function _redeem(
        address _tokenToWithdraw,
        uint256 _amount,
        bytes calldata _destinationAddress
    ) internal {
        require(_amount > 0, "Withdraw amount must be positive");
        require(_destinationAddress.length > 0, "Destination address required");

        // 1. Burn HubToken from msg.sender (assuming 1:1 value)
        _burnHubToken(msg.sender, _amount);

        // 2. Determine the correct `destinationChainId` (origin of `_tokenToWithdraw`)
        uint256 destinationChainId = zrc20OriginChain[_tokenToWithdraw];
        require(destinationChainId > 0, "Origin chain not set for token");

        // 3. Ensure this contract holds sufficient `_tokenToWithdraw`.
        // This check assumes the ZRC-20s were transferred to this contract upon deposit.
        require(IERC20(_tokenToWithdraw).balanceOf(address(this)) >= _amount, "Insufficient ZRC-20 balance in contract");

        // 4. Prepare RevertOptions.
        // Reverts the ZRC-20 back to the user's ZetaChain address if the CCTX fails.
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: msg.sender,
            callOnRevert: false,
            abortAddress: owner(), // Send to owner if revert fails (configurable)
            revertMessage: "",
            onRevertGasLimit: 0 // Gas is free for reverts on ZetaChain originating CCTX
        });

        // 5. Approve the gateway to spend the ZRC-20 (only needs to be done once ideally, or check allowance)
        // For simplicity, approving max amount here. Consider security implications.
        IERC20(_tokenToWithdraw).approve(address(zeta(zetaToken)), type(uint256).max);
        // A better approach might check current allowance and only approve if needed,
        // or approve the exact amount: IERC20(_tokenToWithdraw).approve(address(zeta(zetaToken)), _amount);

        // 6. Call `zeta(zetaToken).withdraw(...)`.
        zeta(zetaToken).withdraw(
            _destinationAddress,
            _amount,
            _tokenToWithdraw,
            revertOptions
        );

        // 7. Emit WithdrawalInitiated event.
        emit WithdrawalInitiated(
            msg.sender,
            _tokenToWithdraw,
            _amount,
            destinationChainId,
            _destinationAddress
        );
    }

    // --- View Functions ---
    /**
    * @dev Gets the HubToken balance for a given user.
    */
    function getBalance(address user) external view returns (uint256) {
        return hubTokenBalances[user];
    }

    // --- Internal Helper Functions ---

    /**
     * @dev Mints internal HubTokens to a recipient.
     */
    function _mintHubToken(address recipient, uint256 amount) internal {
        require(recipient != address(0), "Mint to the zero address");
        hubTokenBalances[recipient] += amount;
        emit HubTokenTransfer(address(0), recipient, amount); // Simulate ERC20 mint event
    }

    /**
     * @dev Burns internal HubTokens from a user.
     */
    function _burnHubToken(address user, uint256 amount) internal {
        require(user != address(0), "Burn from the zero address");
        uint256 currentBalance = hubTokenBalances[user];
        require(currentBalance >= amount, "Burn amount exceeds balance");
        hubTokenBalances[user] = currentBalance - amount;
        emit HubTokenTransfer(user, address(0), amount); // Simulate ERC20 burn event
    }

    /**
     * @dev Decodes the recipient address from the message payload.
     *      Assumes message is abi.encode(address).
     */
    function decodeRecipient(bytes calldata message) internal pure returns (address) {
        if (message.length == 32) { // Standard ABI encoding for address pads to 32 bytes
           return abi.decode(message, (address));
        } else if (message.length == 20) { // Raw address bytes might be passed
            address recipient;
            // solhint-disable-next-line no-inline-assembly
            assembly {
                recipient := mload(add(message, 20))
            }
            return recipient;
        }
        return address(0); // Indicate invalid format
    }

    // function getOriginChainId(address zrc20) internal view returns (uint256) { ... } // Needs mechanism to get origin

} 