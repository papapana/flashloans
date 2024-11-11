// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {FlashLender} from "../src/contracts/FlashLender.sol";
import {MockFlashBorrower} from "./mock/MockFlashBorrower.sol";
import {DeployFlashLender} from "../script/DeployFlashLender.s.sol";
import {HelperConfig, NetworkConfig} from "../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract FlashLenderTest is Test {
    FlashLender flashLender;
    NetworkConfig networkConfig;
    uint256 constant WITHDRAWAL_AMOUNT = 13337;
    uint256 constant LENDER_CONTRACT_AMOUNT = 100000;
    address constant DUMMY_ADDRESS = 0xc0ffee254729296a45a3885639AC7E10F9d54979;

    function setUp() external {
        DeployFlashLender deployFlashLender = new DeployFlashLender();
        (flashLender, networkConfig) = deployFlashLender.run();
    }

    function _addTokensToLender() private returns (address[] memory) {
        address[] memory newTokens = new address[](3);
        newTokens[0] = networkConfig.usdContract;
        newTokens[1] = networkConfig.wethContract;
        newTokens[2] = networkConfig.wbtcContract;
        vm.prank(flashLender.getOwner());
        flashLender.addSupportedTokens(newTokens);
        return newTokens;
    }

    modifier contractFunded() {
        address[] memory lenderTokens = _addTokensToLender();
        vm.prank(flashLender.getOwner());
        IERC20(lenderTokens[0]).transfer(address(flashLender), LENDER_CONTRACT_AMOUNT);
        _;
    }

    function testAddSupportedTokens() external {
        assertEq(flashLender.getTokensSupported().length, 0);
        address[] memory newTokens = _addTokensToLender();
        address[] memory tokensSupported = flashLender.getTokensSupported();
        assertEq(newTokens, tokensSupported);
    }

    function testRemoveToken() external {
        // test removing non-existent token
        vm.expectRevert();
        flashLender.removeToken(networkConfig.usdContract);
        // now add tokens
        address[] memory lenderTokens = _addTokensToLender();
        assertTrue(flashLender.isTokenSupported(lenderTokens[1]));
        vm.prank(flashLender.getOwner());
        flashLender.removeToken(lenderTokens[1]);
        assertFalse(flashLender.isTokenSupported(lenderTokens[1]));
        address[] memory expectedTokens = new address[](2);
        expectedTokens[0] = lenderTokens[0];
        expectedTokens[1] = lenderTokens[2];
        assertEq(flashLender.getTokensSupported(), expectedTokens);
    }

    function testWithdraw() external contractFunded {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        // try to withdraw as not an owner
        vm.expectRevert();
        flashLender.withdraw(IERC20(lenderTokens[0]), WITHDRAWAL_AMOUNT);
        // withdraw more than what the contract has
        vm.prank(flashLender.getOwner());
        vm.expectRevert();
        flashLender.withdraw(IERC20(lenderTokens[0]), LENDER_CONTRACT_AMOUNT + 1);
        // withdraw 0
        vm.prank(flashLender.getOwner());
        vm.expectRevert();
        flashLender.withdraw(IERC20(lenderTokens[0]), 0);
        // normal withdrawal
        uint256 balanceBefore = IERC20(lenderTokens[0]).balanceOf(flashLender.getOwner());
        vm.prank(flashLender.getOwner());
        flashLender.withdraw(IERC20(lenderTokens[0]), WITHDRAWAL_AMOUNT);
        uint256 balanceAfter = IERC20(lenderTokens[0]).balanceOf(flashLender.getOwner());
        assertEq(balanceAfter, balanceBefore + WITHDRAWAL_AMOUNT);
        // withdraw all what is left
        vm.prank(flashLender.getOwner());
        flashLender.withdraw(IERC20(lenderTokens[0]), LENDER_CONTRACT_AMOUNT - WITHDRAWAL_AMOUNT);
        balanceAfter = IERC20(lenderTokens[0]).balanceOf(flashLender.getOwner());
        assertEq(balanceAfter, balanceBefore + LENDER_CONTRACT_AMOUNT);
        assertEq(IERC20(lenderTokens[0]).balanceOf(address(flashLender)), 0);
    }

    function testMaxFlashLoan() external contractFunded {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        // normal case
        assertEq(flashLender.maxFlashLoan(lenderTokens[0]), LENDER_CONTRACT_AMOUNT);
        // supported but 0
        assertEq(flashLender.maxFlashLoan(lenderTokens[1]), 0);
        // unsupported token
        vm.expectRevert();
        flashLender.maxFlashLoan(DUMMY_ADDRESS);
    }

    function testFlashFee() external contractFunded {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        // test normal case
        assertEq(flashLender.flashFee(lenderTokens[0], WITHDRAWAL_AMOUNT), 1);
        // test case noto supported
        vm.expectRevert();
        flashLender.flashFee(DUMMY_ADDRESS, WITHDRAWAL_AMOUNT);
        // Custom fee
        vm.prank(flashLender.getOwner());
        flashLender.addCustomFee(lenderTokens[0], 3);
        assertEq(flashLender.flashFee(lenderTokens[0], WITHDRAWAL_AMOUNT), 4);
    }

    function testFlashLoan() external contractFunded {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        MockFlashBorrower receiver = new MockFlashBorrower();
        MockFlashBorrower.Action action = MockFlashBorrower.Action.NORMAL;
        
        // get more than allowed
        vm.expectRevert();
        flashLender.flashLoan(receiver, lenderTokens[0], LENDER_CONTRACT_AMOUNT + 1, abi.encode(action));

        // get maximum but don't return the loan as it should be returned
        receiver.setLender(flashLender);
        vm.prank(address(receiver));
        vm.expectRevert();
        flashLender.flashLoan(receiver, lenderTokens[0], LENDER_CONTRACT_AMOUNT, abi.encode(action));
        
        // Now fund the borrrower
        vm.prank(flashLender.getOwner());
        IERC20(lenderTokens[0]).transfer(address(receiver), WITHDRAWAL_AMOUNT);
        address token = lenderTokens[0];
        uint256 amount = WITHDRAWAL_AMOUNT;
        // We have to take into account existing loans
        vm.prank(address(receiver));
        uint256 existingBalance = IERC20(token).allowance(address(this), address(flashLender));
        uint256 fee = flashLender.flashFee(token, amount);
        vm.prank(address(receiver));
        IERC20(token).approve(address(flashLender), existingBalance + amount + fee);
        // Initiate the flashloan
        vm.prank(address(receiver));
        bool borrowed = flashLender.flashLoan(receiver, token, amount, abi.encode(action));
        assertTrue(borrowed);
    }
}
