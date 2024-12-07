// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../../interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library UniswapUtilities {
    error PairDoesNotExist();
    error TradeFailed();

    /// @notice Places a trade on Uniswap
    /// @param factory Address of Uniswap V2 Factory
    /// @param router Address of Uniswap V2 Router
    /// @param fromToken Address of the token to sell
    /// @param toToken Address of the token to buy
    /// @param amountIn Amount of `fromToken` to trade
    /// @param recipient Address that will receive the `toToken`
    /// @return amountReceived The amount of `toToken` received
    function placeTrade(
        IUniswapV2Factory factory,
        IUniswapV2Router02 router,
        address fromToken,
        address toToken,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountReceived) {
        require(amountIn > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");

        address pair = factory.getPair(fromToken, toToken);
        if (pair == address(0)) revert PairDoesNotExist();

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        uint256[] memory amountsOut = router.getAmountsOut(amountIn, path);
        uint256 amountRequired = amountsOut[1];
        uint256 deadline = block.timestamp + 1 days;

        // Approve tokens for trade
        IERC20(fromToken).approve(address(router), amountIn);

        uint256[] memory amounts = router.swapExactTokensForTokens(amountIn, amountRequired, path, recipient, deadline);

        amountReceived = amounts[1];
        if (amountReceived == 0) revert TradeFailed();
    }
}
