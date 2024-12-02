// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AddUniswapLiquidity} from "./AddUniswapLiquidity.s.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {console} from "forge-std/Test.sol";

contract AddArbitrageLiquidity is AddUniswapLiquidity {
    // Create a triangular arbitrage opportunity
    uint256 private constant WETH1_AMOUNT = 10000;
    uint256 private constant WBTC1_AMOUNT = 350;
    uint256 private constant WBTC2_AMOUNT = 350;
    uint256 private constant USDC1_AMOUNT = 31850000;
    uint256 private constant USDC2_AMOUNT = 31850000;
    uint256 private constant WETH2_AMOUNT = 9953;

    function run() external override {
        console.log("balance weth", IERC20(WETH).balanceOf(msg.sender));
        console.log("balance wbtc", IERC20(WBTC).balanceOf(msg.sender));
        console.log("balance usdc", IERC20(WBTC).balanceOf(msg.sender));

        console.log("address", msg.sender);
        console.log("address(this) here", address(this));

        vm.startBroadcast();
        (uint256 amountA, uint256 amountB, uint256 liquidity) = addLiquidity(WETH, WBTC, WETH1_AMOUNT, WBTC1_AMOUNT);
        addLiquidity(WBTC, USDC, WBTC2_AMOUNT, USDC1_AMOUNT);
        addLiquidity(USDC, WETH, USDC2_AMOUNT, WETH2_AMOUNT);

        console.log("AmountA added:", amountA);
        console.log("AmountB added:", amountB);
        console.log("Liquidity tokens received:", liquidity);

        // Check LP token balance
        address pair = IUniswapV2Factory(FACTORY).getPair(WETH, WBTC);
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        console.log("LP token balance:", lpBalance);

        // Check pool reserves
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        console.log("Pool reserve of token0:", reserve0);
        console.log("Pool reserve of token1:", reserve1);

        // Check final token balances
        console.log("Final WETH balance:", IERC20(WETH).balanceOf(msg.sender));
        console.log("Final WBTC balance:", IERC20(WBTC).balanceOf(msg.sender));
        vm.stopBroadcast();
    }
}
