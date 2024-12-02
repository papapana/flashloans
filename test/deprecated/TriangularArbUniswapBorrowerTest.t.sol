// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TriangularArbUniswapBorrower} from "../../src/contracts/borrowers/TriangularArbUniswapBorrower.sol";
import {FlashLender} from "../../src/contracts/FlashLender.sol";
import {DeployFlashLender} from "../../script/DeployFlashLender.s.sol";
import {DeployTriangularArbUniswapBorrower} from "../../script/DeployTriangularArbUniswapBorrower.s.sol";
import {AddArbitrageLiquidity} from "../../script/AddArbitrageLiquidity.s.sol";
import {HelperConfig, NetworkConfig} from "../../script/HelperConfig.s.sol";

contract TriangularFlashBorrowerTest is Test {
    TriangularArbUniswapBorrower triArbFlashBorrower;
    FlashLender flashLender;
    NetworkConfig networkConfig;
    uint256 constant LENDER_CONTRACT_AMOUNT = 100000;

    function setUp() external {
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

        // Set up the TriArbBorrower
        DeployTriangularArbUniswapBorrower deployTriangularArbUniswapBorrower = new DeployTriangularArbUniswapBorrower();
        (triArbFlashBorrower, networkConfig) = deployTriangularArbUniswapBorrower.run();

        // Add Arbitrage Liquidity to deployed Uniswap
        AddArbitrageLiquidity addArbLiquidity = new AddArbitrageLiquidity();
        addArbLiquidity.run();
    }

    function testTriangularArbitrage() external {
        address[] memory lenderTokens = flashLender.getTokensSupported();
        address lendedToken = lenderTokens[0];

        address bene = address(0x456);
        console.log("bene: ", bene);
        uint256 balanceBene = IERC20(lendedToken).balanceOf(bene);
        console.log("balance before:", balanceBene);
        assertEq(balanceBene, 0);
        bytes memory data = abi.encode(bene, lenderTokens);
        // Fund the Borrower
        // Get the amount that needs to be repaid
        uint256 fee = flashLender.flashFee(lendedToken, LENDER_CONTRACT_AMOUNT);
        vm.prank(flashLender.getOwner());
        IERC20(lendedToken).transfer(address(triArbFlashBorrower), fee);
        triArbFlashBorrower.borrow(flashLender, lendedToken, LENDER_CONTRACT_AMOUNT, data);
        balanceBene = IERC20(lendedToken).balanceOf(bene);
        console.log("balance after tri arb:", balanceBene);
        assertGt(balanceBene, 0);
    }
}
