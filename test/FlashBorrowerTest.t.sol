// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {FlashBorrower} from "../src/contracts/borrowers/FlashBorrower.sol";
import {FlashLender} from "../src/contracts/FlashLender.sol";
import {DeployFlashLender} from "../script/DeployFlashLender.s.sol";
import {HelperConfig, NetworkConfig} from "../script/HelperConfig.s.sol";

contract DummyFlashBorrower is FlashBorrower {
    enum Action {
        NORMAL,
        OTHER
    }

    function act(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        internal
        override
        returns (bool)
    {
        return true;
    }
}

contract FlashBorrowerTest is Test {
    FlashBorrower flashBorrower;
    FlashLender flashLender;
    NetworkConfig networkConfig;
    uint256 constant LENDER_CONTRACT_AMOUNT = 100000;

    function setUp() external {
        flashBorrower = new DummyFlashBorrower();
        // Set up the Lender
        DeployFlashLender deployFlashLender = new DeployFlashLender();
        (flashLender, networkConfig) = deployFlashLender.run();
        address[] memory newTokens = new address[](3);
        newTokens[0] = networkConfig.usdContract;
        newTokens[1] = networkConfig.wethContract;
        newTokens[2] = networkConfig.wbtcContract;
        vm.prank(flashLender.getOwner());
        flashLender.addSupportedTokens(newTokens);
        // Fund the flashLender
        vm.prank(flashLender.getOwner());
        IERC20(newTokens[0]).transfer(address(flashLender), LENDER_CONTRACT_AMOUNT);
    }

    function testBorrow() external {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        DummyFlashBorrower.Action action = DummyFlashBorrower.Action.NORMAL;
        address lendedToken = lenderTokens[0];
        // Try to borrow more than the Lender has
        vm.expectRevert();
        flashBorrower.borrow(flashLender, lendedToken, LENDER_CONTRACT_AMOUNT + 1, abi.encode(action));

        // Borrow all what the Lender has but cannot repay the fee
        vm.expectRevert();
        flashBorrower.borrow(flashLender, lendedToken, LENDER_CONTRACT_AMOUNT, abi.encode(action));

        // Fund the Borrower
        // Get the amount that needs to be repaid
        uint256 fee = flashLender.flashFee(lendedToken, LENDER_CONTRACT_AMOUNT);
        vm.prank(flashLender.getOwner());
        IERC20(lendedToken).transfer(address(flashBorrower), fee);
        flashBorrower.borrow(flashLender, lendedToken, LENDER_CONTRACT_AMOUNT, abi.encode(action));
    }
}
