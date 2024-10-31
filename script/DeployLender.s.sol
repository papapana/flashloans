// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {FlashLender} from "../src/contracts/FlashLender.sol";

contract DeployLender is Script {
    function run() external returns (FlashLender) {
        
        vm.startBroadcast();
        // Here we spend gas
        FlashLender lender = new FlashLender();
        vm.stopBroadcast();
        return lender;
    }
}
