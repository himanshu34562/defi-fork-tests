// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool} from "../interfaces/IAaveV3.sol";

contract AaveWithdrawTest is Test {
    IAavePool pool;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);

        deal(Addresses.USDC_E_POLYGON, user, MockParams.SUPPLY_USDC);

        vm.startPrank(user);
        IERC20(Addresses.USDC_E_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, MockParams.SUPPLY_USDC);
        pool.supply(Addresses.USDC_E_POLYGON, MockParams.SUPPLY_USDC, user, MockParams.REFERRAL_CODE);
        vm.stopPrank();
    }

    function test_withdraw_returnsUnderlyingAndBurnsAToken() public {
        uint256 aTokenBefore = IERC20(Addresses.aPOL_USDC).balanceOf(user);
        uint256 underlyingBefore = IERC20(Addresses.USDC_E_POLYGON).balanceOf(user);

        console.log("aUSDC before withdraw:", aTokenBefore);
        console.log("USDC.e before withdraw:", underlyingBefore);
        assertEq(aTokenBefore, MockParams.SUPPLY_USDC);
        assertEq(underlyingBefore, 0);

        vm.prank(user);
        uint256 withdrawn = pool.withdraw(
            Addresses.USDC_E_POLYGON,
            type(uint256).max, // withdraw full balance
            user
        );

        uint256 aTokenAfter = IERC20(Addresses.aPOL_USDC).balanceOf(user);
        uint256 underlyingAfter = IERC20(Addresses.USDC_E_POLYGON).balanceOf(user);

        console.log("USDC.e withdrawn:", withdrawn);
        console.log("aUSDC after withdraw:", aTokenAfter);
        console.log("USDC.e after withdraw:", underlyingAfter);

        // aToken fully burned, underlying fully returned
        assertEq(aTokenAfter, 0);
        assertEq(underlyingAfter, withdrawn);
        assertGe(underlyingAfter, MockParams.SUPPLY_USDC); // >= since interest may have accrued
    }
}