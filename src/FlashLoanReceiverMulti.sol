// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../test/interfaces/IUniswapV2.sol";
import {IFlashLoanReceiver} from "../test/interfaces/IAaveV3.sol";

/// @notice Multi-asset flash loan receiver for fork-testing Aave V3 flashLoan().
///         Repays all borrowed assets + premiums atomically. No strategy logic —
///         purely proves the multi-asset callback mechanism works.
contract FlashLoanReceiverMulti is IFlashLoanReceiver {
    address public immutable pool;

    event FlashLoanExecuted(address asset, uint256 amount, uint256 premium);

    constructor(address _pool) {
        pool = _pool;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        require(msg.sender == pool, "caller must be Aave Pool");

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwed = amounts[i] + premiums[i];
            emit FlashLoanExecuted(assets[i], amounts[i], premiums[i]);
            IERC20(assets[i]).approve(pool, amountOwed);
        }

        return true;
    }
}