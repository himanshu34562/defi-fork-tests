// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool} from "../interfaces/IAaveV3.sol";
import {FlashLoanReceiver} from "../../src/FlashLoanReceiver.sol";

contract AaveFlashLoanTest is Test {
    IAavePool pool;
    FlashLoanReceiver receiver;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);
        receiver = new FlashLoanReceiver(Addresses.AAVE_POOL_POLYGON);

        // Fund receiver with a small buffer to cover the flash loan premium
        // (Aave V3 premium is typically 0.05% = 5 bps of the borrowed amount)
        deal(Addresses.USDC_E_POLYGON, address(receiver), 10e6); // 10 USDC buffer
    }

    function test_flashLoanSimple_borrowAndRepay() public {
        uint256 loanAmount = MockParams.THOUSAND_USDC;

        uint256 poolBalanceBefore = IERC20(Addresses.USDC_E_POLYGON).balanceOf(Addresses.AAVE_POOL_POLYGON);
        uint256 receiverBalanceBefore = IERC20(Addresses.USDC_E_POLYGON).balanceOf(address(receiver));

        pool.flashLoanSimple(
            address(receiver),
            Addresses.USDC_E_POLYGON,
            loanAmount,
            "",
            MockParams.REFERRAL_CODE
        );

        uint256 poolBalanceAfter = IERC20(Addresses.USDC_E_POLYGON).balanceOf(Addresses.AAVE_POOL_POLYGON);
        uint256 receiverBalanceAfter = IERC20(Addresses.USDC_E_POLYGON).balanceOf(address(receiver));

        console.log("Receiver balance before:", receiverBalanceBefore);
        console.log("Receiver balance after:", receiverBalanceAfter);
        console.log("Pool balance before:", poolBalanceBefore);
        console.log("Pool balance after:", poolBalanceAfter);
        console.log("Premium paid:", receiverBalanceBefore - receiverBalanceAfter);

        // Receiver should have paid out exactly the premium (loan itself nets to zero)
        assertLt(receiverBalanceAfter, receiverBalanceBefore);

        // Pool should have received the premium — its balance increases by that amount
        assertEq(receiverBalanceBefore - receiverBalanceAfter, 500000); // exact premium check
    }
}