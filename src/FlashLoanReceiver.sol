// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../test/interfaces/IUniswapV2.sol";
import {IFlashLoanSimpleReceiver} from "../test/interfaces/IAaveV3.sol";

contract FlashLoanReceiver is IFlashLoanSimpleReceiver {
    address public immutable pool;
    address public immutable owner;

    event FlashLoanExecuted(address asset, uint256 amount, uint256 premium);

    constructor(address _pool) {
        pool = _pool;
        owner = msg.sender;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        require(msg.sender == pool, "caller must be Aave Pool");

        uint256 amountOwed = amount + premium;
        emit FlashLoanExecuted(asset, amount, premium);

        IERC20(asset).approve(pool, amountOwed);

        return true;
    }
}