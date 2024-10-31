// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
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

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can do that");
        _;
    }

    modifier onlySupportedToken(address token) {
        require(tokenSupported[token], "token is not supported");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedTokens(address[] memory tokens) onlyOwner external {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!tokenSupported[tokens[i]]) {
                require(tokens[i].code.length > 0, "address should be a smart contract");
                tokenSupported[tokens[i]] = true;
                tokensSupported.push(tokens[i]);
                feePercentage[tokens[i]] = DEFAULT_FEE;
            }
        }
    }

    function _deleteToken(address token) private {
        for(uint256 i = 0; i < tokensSupported.length; i++) {
            if(tokensSupported[i] == token) {
                delete tokensSupported[i];
            }
        }
    }

    function removeToken(address token) onlyOwner onlySupportedToken(token) external {
        delete tokenSupported[token];
        _deleteToken(token);
    }

    function addCustomFee(address token, uint256 fee) onlyOwner onlySupportedToken(token) external {
        feePercentage[token] = fee;
    }

    function maxFlashLoan(
        address token
    ) onlySupportedToken(token) external view override returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _flashFee(address token, uint256 amount) private view returns(uint256) {
        uint256 percentage = feePercentage[token];
    }

    function flashFee(
        address token,
        uint256 amount
    ) onlySupportedToken(token) external view override returns (uint256) {
        return _flashFee(token, amount);
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
