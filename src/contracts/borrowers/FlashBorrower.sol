// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC3156FlashBorrower} from "../../interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "../../interfaces/IERC3156FlashLender.sol";

abstract contract FlashBorrower is IERC3156FlashBorrower {
    address private immutable OWNER;
    IERC3156FlashLender private lender;

    // errors
    error BorrowingFailed();
    error OnlyLenderCanCallOnFlashLoan();
    error WrongInitiator();
    error BorrowingActionsFailed();
    //

    constructor() {
        OWNER = msg.sender;
    }

    /**
     * @notice Initiates a flash loan borrowing process
     * @dev This function sets up and executes a flash loan
     * @param _lender The address of the flash loan lender
     * @param token The address of the token to borrow
     * @param amount The amount of tokens to borrow
     * @param data Additional data to pass to the flash loan
     * @custom:throws BorrowingFailed if the flash loan fails to execute
     */
    function borrow(IERC3156FlashLender _lender, address token, uint256 amount, bytes calldata data) external {
        lender = _lender;
        // We have to take into account existing loans
        uint256 existingBalance = IERC20(token).allowance(address(this), address(_lender));
        uint256 fee = _lender.flashFee(token, amount);
        IERC20(token).approve(address(_lender), existingBalance + amount + fee);
        // Initiate the flashloan
        bool borrowed = _lender.flashLoan(IERC3156FlashBorrower(address(this)), token, amount, data);
        if (!borrowed) revert BorrowingFailed();
    }

    /**
     * @notice Performs actions with the borrowed funds
     * @dev This function should be overridden by inheriting contracts to define specific actions
     * @param initiator The address that initiated the flash loan
     * @param token The address of the borrowed token
     * @param amount The amount of tokens borrowed
     * @param fee The fee for the flash loan
     * @param data Additional data passed from the flash loan
     * @return A boolean indicating whether the actions were successful
     */
    function act(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        internal
        virtual
        returns (bool);

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        if (msg.sender != address(lender)) revert OnlyLenderCanCallOnFlashLoan();
        if (initiator != address(this)) revert WrongInitiator();
        bool actionsSuccess = act(initiator, token, amount, fee, data);
        if (!actionsSuccess) revert BorrowingActionsFailed();
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
