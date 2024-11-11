// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {FlashLender} from "../src/contracts/FlashLender.sol";
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol";

contract DeployFlashLender is Script {
    function run() external returns (FlashLender, NetworkConfig memory) {
        HelperConfig helper = new HelperConfig();
        NetworkConfig memory networkConfig = helper.getConfigByChainId(block.chainid);
        vm.startBroadcast();
        // Here we spend gas
        FlashLender lender = new FlashLender();
        vm.stopBroadcast();
        return (lender, networkConfig);
    }
}

