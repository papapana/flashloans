// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

// ... rest of your contract code
import {FlashBorrower} from "./FlashBorrower.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC3156FlashLender} from "../../interfaces/IERC3156FlashLender.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "../../interfaces/IUniswapV2Router01.sol";
import "./UniswapUtilities.sol";

import {console} from "../../../lib/forge-std/src/Test.sol";

contract ArbUniswapBorrower is FlashBorrower {
    IUniswapV2Factory immutable UNISWAP_FACTORY;
    IUniswapV2Router02 immutable UNISWAP_ROUTER;

    // errors
    error PairDoesNotExist();
    error TradeFailed();
    error TradeNotProfitable();
    error GainsTransferFailed();
    error AtLeastOnePairNeeded();
    //

    uint256 private constant MAX_INT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    constructor(address _uniswapFactory, address _uniswapRouter) FlashBorrower() {
        UNISWAP_FACTORY = IUniswapV2Factory(_uniswapFactory);
        UNISWAP_ROUTER = IUniswapV2Router02(_uniswapRouter);
    }

    function trade(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) internal returns (uint256) {
        return UniswapUtilities.placeTrade(
            UNISWAP_FACTORY,
            UNISWAP_ROUTER,
            fromToken,
            toToken,
            amountIn,
            msg.sender
        );
    }


    function act(address, /*initiator*/ address, /*token*/ uint256 amount, uint256 fee, bytes calldata data)
        internal
        override
        returns (bool)
    {
        // Data should contain the beneficial owner, and 3 tokens for the triangular arbitrage
        (address bene, address[] memory tokens) = abi.decode(data, (address, address[]));
        if (tokens.length < 2) revert AtLeastOnePairNeeded();

        for (uint8 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(UNISWAP_ROUTER), MAX_INT);
        }

        uint256 amountFirst = trade(tokens[0], tokens[1], amount);
        uint256 amount_ = amountFirst;

        // Do the arbitrage
        for (uint8 i = 1; i < tokens.length; i++) {
            amount_ = trade(tokens[i], tokens[(i + 1) % tokens.length], amount_);
        }
      
        if (amount_ <= amountFirst) revert TradeNotProfitable();
        // Now transfer the money to the beneficial owner --> the profits in tokens[0]
        // First get the amount to repay to subtract from the gains
        uint256 amountToRepay = fee + amount;
        uint256 gains = amount_ - amountToRepay;
        bool sent = IERC20(tokens[0]).transfer(bene, gains);
        if (!sent) revert GainsTransferFailed();
        return true;
    }
}
