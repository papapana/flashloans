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

    function act(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        internal
        virtual
        returns (bool);

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
