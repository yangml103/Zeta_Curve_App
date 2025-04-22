// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { RevertContext, RevertOptions } from "@zetachain/protocol-contracts/contracts/Revert.sol";
import { UniversalContract, MessageContext, CallOptions } from "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";
import { IGatewayZEVM } from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import { GatewayZEVM } from "@zetachain/protocol-contracts/contracts/zevm/GatewayZEVM.sol";
import { IZRC20 } from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IZRC20.sol";


contract Universal is UniversalContract {
    GatewayZEVM public immutable gateway;

    event HelloEvent(string, string);
    event RevertEvent(string, RevertContext);

    error TransferFailed();
    error Unauthorized();

    modifier onlyGateway() {
        if (msg.sender != address(gateway)) revert Unauthorized();
        _;
    }

    constructor(address payable gatewayAddress) {
        gateway = GatewayZEVM(gatewayAddress);
    }

    function call(
        bytes memory receiver,
        address zrc20,
        bytes calldata message,
        CallOptions memory callOptions,
        RevertOptions memory revertOptions
    ) external {
        (, uint256 gasFee) = IZRC20(zrc20).withdrawGasFeeWithGasLimit(
            callOptions.gasLimit
        );
        if (!IZRC20(zrc20).transferFrom(msg.sender, address(this), gasFee)) {
            revert TransferFailed();
        }
        IZRC20(zrc20).approve(address(gateway), gasFee);
        gateway.call(receiver, zrc20, message, callOptions, revertOptions);
    }

    function callMulti(
        bytes[] memory receiverArray,
        address[] memory zrc20Array,
        bytes calldata messages, // Note: PDF says messages, should likely be message per call or array
        CallOptions memory callOptions,
        RevertOptions memory revertOptions
    ) external {
        for (uint256 i = 0; i < zrc20Array.length; i++) {
            (, uint256 gasFee) = IZRC20(zrc20Array[i])
                .withdrawGasFeeWithGasLimit(callOptions.gasLimit);
            if (
                !IZRC20(zrc20Array[i]).transferFrom(
                    msg.sender,
                    address(this),
                    gasFee
                )
            ) {
                revert TransferFailed();
            }
            IZRC20(zrc20Array[i]).approve(address(gateway), gasFee);
            // Assuming 'messages' contains concatenated or structured data for each call
            // This might need adjustment based on actual usage pattern
            gateway.call(
                receiverArray[i],
                zrc20Array[i],
                messages, // Passing the same 'messages' to each call? Review needed.
                callOptions,
                revertOptions
            );
        }
    }

    function withdraw(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        RevertOptions memory revertOptions
    ) external {
        (address gasZRC20, uint256 gasFee) = IZRC20(zrc20).withdrawGasFee();
        uint256 target = zrc20 == gasZRC20 ? amount + gasFee : amount;
        if (!IZRC20(zrc20).transferFrom(msg.sender, address(this), target)) {
            revert TransferFailed();
        }
        IZRC20(zrc20).approve(address(gateway), target);
        if (zrc20 != gasZRC20) {
            if (
                !IZRC20(gasZRC20).transferFrom(
                    msg.sender,
                    address(this),
                    gasFee
                )
            ) {
                revert TransferFailed();
            }
            IZRC20(gasZRC20).approve(address(gateway), gasFee);
        }
        gateway.withdraw(receiver, amount, zrc20, revertOptions);
    }

    function withdrawAndCall(
        bytes memory receiver,
        uint256 amount,
        address zrc20,
        bytes calldata message,
        CallOptions memory callOptions,
        RevertOptions memory revertOptions
    ) public virtual { // Made public virtual for inheritance
        (address gasZRC20, uint256 gasFee) = IZRC20(zrc20)
            .withdrawGasFeeWithGasLimit(callOptions.gasLimit);
        uint256 target = zrc20 == gasZRC20 ? amount + gasFee : amount;
        if (!IZRC20(zrc20).transferFrom(msg.sender, address(this), target))
            revert TransferFailed();
        IZRC20(zrc20).approve(address(gateway), target);
        if (zrc20 != gasZRC20) {
            if (
                !IZRC20(gasZRC20).transferFrom(
                    msg.sender,
                    address(this),
                    gasFee
                )
            ) {
                revert TransferFailed();
            }
            IZRC20(gasZRC20).approve(address(gateway), gasFee);
        }
        gateway.withdrawAndCall(
            receiver,
            amount,
            zrc20,
            message,
            callOptions,
            revertOptions
        );
    }

    /**
     * @notice Default onCall implementation. Needs override in child contracts for specific logic.
     */
    function onCall(
        MessageContext calldata context,
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external virtual override onlyGateway { // Added virtual
        // Default implementation emits an event. Override in child contract.
        string memory name = abi.decode(message, (string)); // Assumes message is string
        emit HelloEvent("Hello on ZetaChain (Base Universal)", name);
    }

     /**
      * @notice Default onRevert implementation. Needs override in child contracts for specific logic.
      */
    function onRevert(
        RevertContext calldata revertContext
    ) external virtual onlyGateway { // Added virtual
        // Default implementation emits an event. Override in child contract.
        emit RevertEvent("Revert on ZetaChain (Base Universal)", revertContext);
    }
} 