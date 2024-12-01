// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


// ... rest of your contract code
import {FlashBorrower} from "./FlashBorrower.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC3156FlashLender} from "../../interfaces/IERC3156FlashLender.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router01} from "../../interfaces/IUniswapV2Router01.sol";

import {console} from "../../../lib/forge-std/src/Test.sol";

contract TriangularArbUniswapBorrower is FlashBorrower {
    IUniswapV2Factory immutable UNISWAP_FACTORY;
    IUniswapV2Router01 immutable UNISWAP_ROUTER;

    // errors
    error PairDoesNotExist();
    error TradeFailed();
    error TradeNotProfitable();
    error GainsTransferFailed();
    //

    event Debug(string message, address addr);
    event Debug(string message, uint256);

    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;



    constructor(address _uniswapFactory, address _uniswapRouter) FlashBorrower() {
        UNISWAP_FACTORY = IUniswapV2Factory(_uniswapFactory);
        UNISWAP_ROUTER = IUniswapV2Router01(_uniswapRouter);
    }

    function placeTrade(address _fromToken, address _toToken, uint256 _amountIn) private returns (uint256) {
        // console.log("uniswap factory: ", UNISWAP_FACTORY);
        // console.log("_fromToken:", _fromToken, " _toToken:", _toToken);
        emit Debug("uniswap factory: ", address(UNISWAP_FACTORY));
        emit Debug("_fromToken", _fromToken);
        emit Debug("_toToken", _toToken);
        emit Debug("_amountIn", _amountIn);
        address pair = UNISWAP_FACTORY.getPair(_fromToken, _toToken);
        if (pair == address(0)) revert PairDoesNotExist();
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        uint256 amountRequired = UNISWAP_ROUTER.getAmountsOut(_amountIn, path)[1];
        emit Debug("amount required:", amountRequired);

        uint256 deadline = block.timestamp + 1 days;
        uint256 amountReceived =
            UNISWAP_ROUTER.swapExactTokensForTokens(_amountIn, amountRequired, path, address(this), deadline)[1];
        if (amountReceived == 0) revert TradeFailed();
        return amountReceived;
    }

    function act(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        internal
        override
        returns (bool)
    {
        // Data should contain the beneficial owner, and 3 tokens for the triangular arbitrage
        (address bene, address[3] memory tokens) = abi.decode(data, (address, address[3]));
        for(uint8 i = 0; i < 3; i++){
            IERC20(tokens[i]).approve(address(UNISWAP_ROUTER), MAX_INT);
        }
        // Do the triangular arbitrage
        uint256 amountFirst = placeTrade(tokens[0], tokens[1], amount);
        uint256 amountSecond = placeTrade(tokens[1], tokens[2], amountFirst);
        uint256 finalReceived = placeTrade(tokens[2], tokens[0], amountSecond);
        if (finalReceived <= amountFirst) revert TradeNotProfitable();
        // Now transfer the money to the beneficial owner --> the profits in tokens[0]
        // First get the amount to repay to subtract from the gains
        uint256 amountToRepay = fee + amount;
        uint256 gains = finalReceived - amountToRepay;
        bool sent = IERC20(tokens[0]).transfer(bene, gains);
        if (!sent) revert GainsTransferFailed();
        return true;
    }
}
