// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {IUniswapV2Pair} from "../src/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "../src/interfaces/IUniswapV2Router01.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";
import {console} from "forge-std/Test.sol";
import {AddArbitrageLiquidity} from "../script/AddArbitrageLiquidity.s.sol";
import {DeployTriangularArbUniswapBorrower} from "../script/DeployTriangularArbUniswapBorrower.s.sol";
import {TriangularArbUniswapBorrower} from "../src/contracts/borrowers/TriangularArbUniswapBorrower.sol";
import {IFLashLender} from "../src/interfaces/IFlashLender.sol";

contract RunTriArb is Script {
    // Create a triangular arbitrage opportunity
    address internal immutable FACTORY;
    address internal immutable ROUTER;
    address internal immutable WETH;
    address internal immutable USDC;
    address internal immutable WBTC;
    address internal immutable FLASHLENDER;
    address internal immutable BENE;
    TriangularArbUniswapBorrower triArbFlashBorrower;
    NetworkConfig networkConfig;
    uint256 constant LENDER_CONTRACT_AMOUNT = 100000;

    // errors
    error WrongChain();
    //

    constructor() {
        console.log("Starting constructor");
        if (block.chainid != 702) {
            revert WrongChain();
        }
        console.log("Chain ID check passed");

        HelperConfig helper = new HelperConfig();
        networkConfig = helper.getConfigByChainId(block.chainid);
        console.log("Network config loaded");

        FACTORY = networkConfig.uniswapFactory;
        ROUTER = networkConfig.uniswapRouter;
        WETH = networkConfig.wethContract;
        USDC = networkConfig.usdContract;
        WBTC = networkConfig.wbtcContract;
        FLASHLENDER = 0xdDcbE46C653F6Bf9d2Ede5897CeEF9D178029D5B;
        BENE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    }

    function run() external {
        address[] memory newTokens = new address[](3);
        newTokens[0] = networkConfig.usdContract;
        newTokens[1] = networkConfig.wethContract;
        newTokens[2] = networkConfig.wbtcContract;
        // Set up the TriArbBorrower
        DeployTriangularArbUniswapBorrower deployTriangularArbUniswapBorrower = new DeployTriangularArbUniswapBorrower();
        (triArbFlashBorrower, networkConfig) = deployTriangularArbUniswapBorrower.run();

        // TODO: Deploy own FlashLender contract and fund it
        vm.startBroadcast();
        console.log("before adding tokens");
        console.log("sender:", msg.sender);
        console.log("FlashLender owner:", IFLashLender(FLASHLENDER).getOwner());
        IFLashLender(FLASHLENDER).addSupportedTokens(newTokens);
        console.log("added tokens");

        console.log("balance weth", IERC20(WETH).balanceOf(msg.sender));
        console.log("balance wbtc", IERC20(WBTC).balanceOf(msg.sender));
        console.log("balance usdc", IERC20(USDC).balanceOf(msg.sender));

        bool sent = IERC20(USDC).transfer(FLASHLENDER, LENDER_CONTRACT_AMOUNT);
        require(sent, "FlashLender not funded");

        console.log("FlashLender balance weth", IERC20(WETH).balanceOf(FLASHLENDER));
        console.log("FlashLender balance wbtc", IERC20(WBTC).balanceOf(FLASHLENDER));
        console.log("FlashLender balance usdc", IERC20(USDC).balanceOf(FLASHLENDER));
        console.log("FlashBorrower balance usdc", IERC20(USDC).balanceOf(address(triArbFlashBorrower)));

        console.log("address", msg.sender);
        console.log("address(this) here", address(this));

        address pair1 = IUniswapV2Factory(FACTORY).getPair(WETH, WBTC);
        address pair2 = IUniswapV2Factory(FACTORY).getPair(WBTC, USDC);
        address pair3 = IUniswapV2Factory(FACTORY).getPair(USDC, WETH);
        console.log("pair1:", pair1);
        console.log("pair2:", pair2);
        console.log("pair3:", pair3);

        console.log("Pair 1 msg.sender balance:", IERC20(pair1).balanceOf(msg.sender));
        console.log("Pair 1 triarb balance:", IERC20(pair1).balanceOf(address(triArbFlashBorrower)));
        console.log("Pair 1 Router balance:", IERC20(pair1).balanceOf(ROUTER));
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair1).getReserves();
        console.log("token 0 amount:", reserve0);
        console.log("token 1 amount:", reserve1);
        address[] memory path = new address[](2);
        path[0] = newTokens[0];
        path[1] = newTokens[1];
        uint256 amountRequired = IUniswapV2Router01(ROUTER).getAmountsOut(10000, path)[1];
        console.log("amount required:", amountRequired);

        // Add liquidity and token to FlashLender

        address[] memory lenderTokens = IFLashLender(FLASHLENDER).getTokensSupported();
        console.log("num lender tokens: ", lenderTokens.length);
        address lendedToken = lenderTokens[0];
        console.log("bene:", BENE);
        uint256 balanceBene = IERC20(lendedToken).balanceOf(BENE);
        console.log("BENE balance before:", balanceBene);

        address[3] memory tokenArray = [lenderTokens[0], lenderTokens[1], lenderTokens[2]];
        bytes memory data = abi.encode(BENE, tokenArray);
        // Give fee to Borrower
        uint256 fee = IFLashLender(FLASHLENDER).flashFee(lendedToken, LENDER_CONTRACT_AMOUNT);
        IERC20(lendedToken).transfer(address(triArbFlashBorrower), fee);

        // Execute the arbitrage
        triArbFlashBorrower.borrow(IFLashLender(FLASHLENDER), lendedToken, 10000, data);
        console.log("successfully borrowed flashloan");
        vm.stopBroadcast();
        // BENE balance now
        balanceBene = IERC20(lendedToken).balanceOf(BENE);
        console.log("balance after tri arb:", balanceBene);
    }
}

// Successful run:
// https://uzhethw.ifi.uzh.ch/tx/0xafa2fa7279d3d1c78527db99b243f2a8c85a94b4f60fe73213a697116ba47649
