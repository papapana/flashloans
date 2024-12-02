// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC3156FlashLender} from "./IERC3156FlashLender.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IFLashLender is IERC3156FlashLender {
    function addSupportedTokens(address[] memory tokens) external;
    function removeToken(address token) external;
    function addCustomFee(address token, uint256 fee) external;
    function withdraw(IERC20 token, uint256 amount) external;
    function getTokensSupported() external view returns (address[] memory);
    function isTokenSupported(address token) external view returns (bool);
    function getOwner() external view returns (address);
}
