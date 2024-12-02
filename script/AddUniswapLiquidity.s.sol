// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {console} from "forge-std/Test.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract AddUniswapLiquidity is Script {
    address internal immutable FACTORY;
    address internal immutable ROUTER;
    address internal immutable WETH;
    address internal immutable USDC;
    address internal immutable WBTC;
    uint256 internal constant LIQUIDITY_AMOUNT = 2 ether;

    constructor() {
        HelperConfig helper = new HelperConfig();
        NetworkConfig memory networkConfig = helper.getConfigByChainId(block.chainid);
        FACTORY = networkConfig.uniswapFactory;
        ROUTER = networkConfig.uniswapRouter;
        WETH = networkConfig.wethContract;
        USDC = networkConfig.usdContract;
        WBTC = networkConfig.wbtcContract;
    }

    event Log(string message, uint256 val);

    function addLiquidity(address _tokenA, address _tokenB, uint256 _amountA, uint256 _amountB)
        public
        returns (uint256, uint256, uint256)
    {
        console.log("WETH address:", address(WETH));
        console.log("USDC address:", address(USDC));
        console.log("WBTC address:", address(WBTC));
        console.log("Router address:", address(ROUTER));
        console.log("Factory address:", address(FACTORY));

        console.log("sender in liquidity:", msg.sender);
        console.log("address(this) in liquidity", address(this));

        IERC20(_tokenA).approve(ROUTER, _amountA);
        IERC20(_tokenB).approve(ROUTER, _amountB);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = IUniswapV2Router02(ROUTER).addLiquidity(
            _tokenA, _tokenB, _amountA, _amountB, 1, 1, address(this), block.timestamp + 10 minutes
        );
        emit Log("amountA", amountA);
        emit Log("amountB", amountB);
        emit Log("liquidity", liquidity);
        return (amountA, amountB, liquidity);
    }

    function run() external virtual {
        console.log("balance weth", IERC20(WETH).balanceOf(msg.sender));
        console.log("balance wbtc", IERC20(WBTC).balanceOf(msg.sender));
        console.log("address", msg.sender);
        console.log("address(this) here", address(this));

        vm.startBroadcast();
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            addLiquidity(WETH, WBTC, LIQUIDITY_AMOUNT, LIQUIDITY_AMOUNT);

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
