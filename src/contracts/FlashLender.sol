// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC3156FlashBorrower} from "../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

contract FlashLender is IERC3156FlashLender {
    uint256 private constant DEFAULT_FEE = 1; // 0.01%
    uint256 private constant DECIMALS = 10000;

    bytes32 private constant BORROW_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    mapping(address => bool) private tokenSupported;
    mapping(address => uint256) private feePercentage;
    // mapping(address => uint256) private feesAccrued;
    // uint256 private feesBalance;
    address[] private tokensSupported;
    address private immutable OWNER;

    // errors
    error OnlyOwnerAllowed();
    error TokenNotSupported(address token);
    error AddressShouldBeSmartContract(address token);
    error LoanAmountTooBig(uint256 amount);
    error NotEnoughBalanceToWithdraw();
    error WithdrawalFailed();
    error ZeroWithdrawalAmount();
    error FlashLoanNotSent();
    error BorrowerDoesNotFollowProtocol();
    error FlashLoanFailed();
    //

    // events
    event FlashLoanSuccessful(IERC3156FlashBorrower indexed receiver, address indexed token, uint256 amount);
    //

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert OnlyOwnerAllowed();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!tokenSupported[token]) revert TokenNotSupported(token);
        _;
    }

    constructor() {
        OWNER = msg.sender;
    }

    function addSupportedTokens(address[] memory tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (!tokenSupported[tokens[i]]) {
                if (tokens[i].code.length == 0) revert AddressShouldBeSmartContract(tokens[i]);
                tokenSupported[tokens[i]] = true;
                tokensSupported.push(tokens[i]);
                feePercentage[tokens[i]] = DEFAULT_FEE;
            }
        }
    }

    function _deleteToken(address token) private {
        for (uint256 i = 0; i < tokensSupported.length; i++) {
            if (tokensSupported[i] == token) {
                tokensSupported[i] = tokensSupported[tokensSupported.length - 1];
                tokensSupported.pop();
                break;
            }
        }
    }

    function removeToken(address token) external onlyOwner onlySupportedToken(token) {
        delete tokenSupported[token];
        _deleteToken(token);
    }

    function addCustomFee(address token, uint256 fee) external onlyOwner onlySupportedToken(token) {
        feePercentage[token] = fee;
    }

    function _maxFlashLoan(address token) private view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function maxFlashLoan(address token) external view override onlySupportedToken(token) returns (uint256) {
        return _maxFlashLoan(token);
    }

    function _flashFee(address token, uint256 amount) private view returns (uint256) {
        return (feePercentage[token] * amount) / DECIMALS;
    }

    function flashFee(address token, uint256 amount)
        external
        view
        override
        onlySupportedToken(token)
        returns (uint256)
    {
        return _flashFee(token, amount);
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        override
        onlySupportedToken(token)
        returns (bool)
    {
        if (amount > _maxFlashLoan(token)) revert LoanAmountTooBig(amount);
        IERC20 _token = IERC20(token);
        // Do the transfer
        bool sent = _token.transfer(msg.sender, amount);
        if (!sent) revert FlashLoanNotSent();
        uint256 fee = _flashFee(token, amount);
        uint256 amountToReturn = amount + fee;
        // Call onFlashLoan
        bytes32 borrowed = receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        if (borrowed != BORROW_SUCCESS) revert BorrowerDoesNotFollowProtocol();
        // Ensure funds + fee are returned
        bool received = _token.transferFrom(msg.sender, address(this), amountToReturn);
        if (!received) revert FlashLoanFailed();
        emit FlashLoanSuccessful(receiver, token, amount);
        return true;
    }

    function withdraw(IERC20 token, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroWithdrawalAmount();
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) revert NotEnoughBalanceToWithdraw();
        bool sent = token.transfer(OWNER, amount);
        if (!sent) revert WithdrawalFailed();
    }

    function getTokensSupported() external view returns (address[] memory) {
        return tokensSupported;
    }

    function isTokenSupported(address token) external view returns (bool) {
        return tokenSupported[token];
    }

    function getOwner() external view returns (address) {
        return OWNER;
    }
}
