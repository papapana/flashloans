// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {ArbUniswapBorrower} from "../src/contracts/borrowers/ArbUniswapBorrower.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";

contract DeployArbUniswapBorrower is Script {
    function run() external returns (ArbUniswapBorrower, NetworkConfig memory) {
        HelperConfig helper = new HelperConfig();
        NetworkConfig memory networkConfig = helper.getConfigByChainId(block.chainid);
        vm.startBroadcast();
        // Here we spend gas
        ArbUniswapBorrower borrower = new ArbUniswapBorrower(networkConfig.uniswapFactory, networkConfig.uniswapRouter);
        vm.stopBroadcast();
        return (borrower, networkConfig);
    }
}
