// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interface for Curve StableSwap-NG Pools
 * @dev Minimal interface based on expected interactions.
 * Assumes a pool size N=4 based on the proposal
 */
interface ICurveStableSwapNG {
    /**
     * @notice Add liquidity to the pool.
     * @param amounts Array of amounts of underlying coins to deposit.
     * @param min_mint_amount Minimum LP tokens to mint.
     * @param receiver Address to receive the LP tokens.
     * @return Amount of LP tokens minted.
     */
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount, address receiver) external returns (uint256);

    /**
     * @notice Remove liquidity for a single coin.
     * @param _token_amount Amount of LP tokens to burn.
     * @param i Index of the coin to withdraw.
     * @param min_amount Minimum amount of the coin to receive.
     * @param receiver Address to receive the coin.
     * @return Amount of the coin received.
     */
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount, address receiver) external returns (uint256);
} 