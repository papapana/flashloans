// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {TriangularArbUniswapBorrower} from "../src/contracts/borrowers/TriangularArbUniswapBorrower.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";

contract DeployTriangularArbUniswapBorrower is Script {
    function run() external returns (TriangularArbUniswapBorrower, NetworkConfig memory) {
        HelperConfig helper = new HelperConfig();
        NetworkConfig memory networkConfig = helper.getConfigByChainId(block.chainid);
        vm.startBroadcast();
        // Here we spend gas
        TriangularArbUniswapBorrower borrower =
            new TriangularArbUniswapBorrower(networkConfig.uniswapFactory, networkConfig.uniswapRouter);
        vm.stopBroadcast();
        return (borrower, networkConfig);
    }
}
