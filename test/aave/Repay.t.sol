// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool} from "../interfaces/IAaveV3.sol";

contract AaveRepayTest is Test {
    IAavePool pool;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);

        // Seed collateral, supply it, then borrow — replicate the same
        // position as SupplyBorrow.t.sol so this test is self-contained.
        deal(Addresses.USDC_E_POLYGON, user, MockParams.SUPPLY_USDC);

        vm.startPrank(user);
        IERC20(Addresses.USDC_E_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, MockParams.SUPPLY_USDC);
        pool.supply(Addresses.USDC_E_POLYGON, MockParams.SUPPLY_USDC, user, MockParams.REFERRAL_CODE);

        pool.borrow(
            Addresses.DAI_POLYGON,
            MockParams.BORROW_DAI,
            MockParams.VARIABLE_RATE,
            MockParams.REFERRAL_CODE,
            user
        );
        vm.stopPrank();

        // Give user a small extra buffer of DAI to cover any accrued interest
        deal(Addresses.DAI_POLYGON, user, MockParams.BORROW_DAI + 10e18);
    }

    function test_repay_clearsDebt() public {
        uint256 debtTokenBefore = IERC20(Addresses.VAR_DEBT_POL_DAI).balanceOf(user);
        console.log("Debt (variableDebtDAI) before repay:", debtTokenBefore);
        assertGt(debtTokenBefore, 0);

        (,,,,, uint256 healthFactorBeforeRepay) = pool.getUserAccountData(user);
        console.log("Health factor before repay:", healthFactorBeforeRepay);

        vm.startPrank(user);
        IERC20(Addresses.DAI_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, type(uint256).max);

        uint256 repaid = pool.repay(
            Addresses.DAI_POLYGON,
            type(uint256).max, // repay full balance incl. accrued interest
            MockParams.VARIABLE_RATE,
            user
        );
        vm.stopPrank();

        uint256 debtTokenAfter = IERC20(Addresses.VAR_DEBT_POL_DAI).balanceOf(user);
        console.log("DAI repaid:", repaid);
        console.log("Debt (variableDebtDAI) after repay:", debtTokenAfter);

        (,,,,, uint256 healthFactorAfterRepay) = pool.getUserAccountData(user);
        console.log("Health factor after repay:", healthFactorAfterRepay);

        // Debt should be fully cleared
        assertEq(debtTokenAfter, 0);

        // Health factor returns to max (uint256.max) once debt is zero,
        // same convention Aave used before any borrow existed
        assertEq(healthFactorAfterRepay, type(uint256).max);
    }
}