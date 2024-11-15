// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {WETH} from "../test/mock/WETH.sol";
import {WBTC} from "../test/mock/WBTC.sol";
import {USDC} from "../test/mock/USDC.sol";

struct NetworkConfig {
    address usdContract;
    address wethContract;
    address wbtcContract;
    address uniswapRouter;
    address uniswapFactory;
}

contract HelperConfig is Script {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETHEREUM_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant UZH_CHAIN_ID = 702;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;

    // errors
    error HelperConfig__InvalidChainId();
    //

    NetworkConfig localNetworkConfig;

    mapping(uint256 => NetworkConfig) networkConfig;

    constructor() {
        networkConfig[UZH_CHAIN_ID] = getUZHETHConfig();
        networkConfig[ETHEREUM_CHAIN_ID] = getEthereumConfig();
        networkConfig[ARBITRUM_CHAIN_ID] = getArbitrumConfig();
        networkConfig[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfig[chainId].usdContract != address(0)) {
            // exists in dictionary
            return networkConfig[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getUZHETHConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdContract: 0x3e26546fa8922543291B038d5aC4b0dC2e01BcD1,
            wethContract: 0xA50C799d60e79A5f8A5590B6093A8887389DB062,
            wbtcContract: 0xe6E6177De0563b6aac20233F894D5138F06d7867,
            uniswapRouter: 0x27930412f44fe0183595b9A0dD6AF9C04ed103e6,
            uniswapFactory: 0x6C2Df876b79843645bba1c1D6d978cC6feEcd04B
        });
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdContract: 0xc19DA43172DEd37478732056eC6be03b65F1378C,
            wethContract: 0xaFb2cDA81b4De2Ff94F5E82792bab517079291bB,
            wbtcContract: 0x8318dB085c569ec57d46561F30d877249C42e6Bc,
            uniswapRouter: 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3,
            uniswapFactory: 0xF62c03E08ada871A0bEb309762E260a7a6a880E6
        });
    }

    function getEthereumConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdContract: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            wethContract: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            wbtcContract: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            uniswapRouter: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
            uniswapFactory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
        });
    }

    function getArbitrumConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            usdContract: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            wethContract: 0x8b194bEae1d3e0788A1a35173978001ACDFba668,
            wbtcContract: 0x3f770Ac673856F105b586bb393d122721265aD46,
            uniswapRouter: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
            uniswapFactory: 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.usdContract != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        USDC mockUSD = new USDC(1_000_000_000 * 10 ** 18);
        WETH mockWETH = new WETH(1_000_000_000 * 10 ** 18);
        WBTC mockWBTC = new WBTC(1_000_000_000 * 10 ** 18);
        vm.stopBroadcast();
        localNetworkConfig = NetworkConfig({
            usdContract: address(mockUSD),
            // wethContract: 0x610178dA211FEF7D417bC0e6FeD39F05609AD788,
            wethContract: address(mockWETH),
            wbtcContract: address(mockWBTC),
            uniswapFactory: 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e,
            uniswapRouter: 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82
        });
        return localNetworkConfig;
    }
}
