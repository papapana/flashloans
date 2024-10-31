// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

contract FlashLender is IERC3156FlashLender {
    uint256 constant DEFAULT_FEE = 1; // 0.01%
    mapping(address => bool) tokenSupported;
    mapping(address => uint256) feePercentage;
    mapping(address => uint256) feesAccrued;
    uint256 feesBalance;
    address[] tokensSupported;
    address owner;

    constructor(address[] memory tokens) {
        owner = msg.sender;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!tokenSupported[tokens[i]]) {
                tokenSupported[tokens[i]] = true;
                tokensSupported.push(tokens[i]);
                feePercentage[tokens[i]] = DEFAULT_FEE;
            }
        }
    }

    function maxFlashLoan(
        address token
    ) external view override returns (uint256) {
        return 1000000;
    }

    function flashFee(
        address token,
        uint256 amount
    ) external view override returns (uint256) {
        return 200000;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        return true;
    }
}
