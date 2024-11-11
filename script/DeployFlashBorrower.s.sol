// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {FlashBorrower} from "../src/contracts/FlashBorrower.sol";

contract DeployFlashBorrower is Script {
    function run() external returns (FlashBorrower) {
        vm.startBroadcast();
        // Here we spend gas
        FlashBorrower borrower = new FlashBorrower();
        vm.stopBroadcast();
        return borrower;
    }
}
