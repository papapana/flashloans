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

    /**
     * @notice Adds multiple tokens to the list of supported tokens
     * @dev Only the owner can call this function
     * @param tokens An array of token addresses to be added as supported tokens
     * @custom:throws AddressShouldBeSmartContract if any of the token addresses is not a contract
     */
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

    /**
     * @notice Removes a token from the list of supported tokens
     * @dev Only the owner can call this function, and the token must be currently supported
     * @param token The address of the token to be removed
     */
    function removeToken(address token) external onlyOwner onlySupportedToken(token) {
        delete tokenSupported[token];
        _deleteToken(token);
    }

    /**
     * @notice Adds a custom fee for a specific token
     * @dev Only the owner can call this function, and the token must be currently supported
     * @param token The address of the token for which to set a custom fee
     * @param fee The new fee to be set for the token
     */
    function addCustomFee(address token, uint256 fee) external onlyOwner onlySupportedToken(token) {
        feePercentage[token] = fee;
    }

    function _maxFlashLoan(address token) private view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token) external view override onlySupportedToken(token) returns (uint256) {
        return _maxFlashLoan(token);
    }

    function _flashFee(address token, uint256 amount) private view returns (uint256) {
        return (feePercentage[token] * amount) / DECIMALS;
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 amount)
        external
        view
        override
        onlySupportedToken(token)
        returns (uint256)
    {
        return _flashFee(token, amount);
    }

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
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

    /**
     * @notice Allows the owner to withdraw tokens from the contract
     * @dev Only the owner can call this function
     * @param token The ERC20 token to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(IERC20 token, uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroWithdrawalAmount();
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) revert NotEnoughBalanceToWithdraw();
        bool sent = token.transfer(OWNER, amount);
        if (!sent) revert WithdrawalFailed();
    }

    /**
     * @notice Returns an array of all supported token addresses
     * @return An array of addresses representing the supported tokens
     */
    function getTokensSupported() external view returns (address[] memory) {
        return tokensSupported;
    }

    /**
     * @notice Checks if a given token is supported by the contract
     * @param token The address of the token to check
     * @return A boolean indicating whether the token is supported (true) or not (false)
     */
    function isTokenSupported(address token) external view returns (bool) {
        return tokenSupported[token];
    }

    /**
     * @notice Returns the address of the contract owner
     * @return The address of the owner
     */
    function getOwner() external view returns (address) {
        return OWNER;
    }
}
