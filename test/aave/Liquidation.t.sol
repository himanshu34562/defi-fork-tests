// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool , IAaveOracle} from "../interfaces/IAaveV3.sol";

contract AaveLiquidationTest is Test {
    IAavePool pool;
    IAaveOracle oracle;
    address borrower = address(0xBEEF);
    address liquidator = address(0xCAFE);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);
        oracle = IAaveOracle(Addresses.AAVE_ORACLE_POLYGON);

        // Borrower supplies 1 WETH as volatile collateral
        deal(Addresses.WETH_POLYGON, borrower, MockParams.ONE_WETH);

        vm.startPrank(borrower);
        IERC20(Addresses.WETH_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, MockParams.ONE_WETH);
        pool.supply(Addresses.WETH_POLYGON, MockParams.ONE_WETH, borrower, MockParams.REFERRAL_CODE);

        // Borrow USDC.e against it — a real, safe amount well under max LTV initially
        pool.borrow(
            Addresses.USDC_E_POLYGON,
            MockParams.BORROW_USDC,
            MockParams.VARIABLE_RATE,
            MockParams.REFERRAL_CODE,
            borrower
        );
        vm.stopPrank();

        // Liquidator needs USDC.e on hand to repay the borrower's debt
        deal(Addresses.USDC_E_POLYGON, liquidator, MockParams.BORROW_USDC);
    }

    function test_liquidation_afterPriceCrash() public {
        // ── 1. Confirm position is healthy before the crash ────────────────
        (,,,,, uint256 healthFactorBefore) = pool.getUserAccountData(borrower);
        console.log("Health factor before crash:", healthFactorBefore);
        assertGt(healthFactorBefore, MockParams.LIQUIDATION_THRESHOLD);

        // ── 2. Read the real WETH price, then mock a crash ─────────────────
        uint256 realWethPrice = oracle.getAssetPrice(Addresses.WETH_POLYGON);
        uint256 crashedPrice = realWethPrice / 10; // simulate a ~66% price crash

        console.log("Real WETH price (8 dec):", realWethPrice);
        console.log("Crashed WETH price (8 dec):", crashedPrice);

        vm.mockCall(
            Addresses.AAVE_ORACLE_POLYGON,
            abi.encodeWithSelector(IAaveOracle.getAssetPrice.selector, Addresses.WETH_POLYGON),
            abi.encode(crashedPrice)
        );

        // ── 3. Confirm the position is now liquidatable ─────────────────────
        (,,,,, uint256 healthFactorAfterCrash) = pool.getUserAccountData(borrower);
        console.log("Health factor after crash:", healthFactorAfterCrash);
        assertLt(healthFactorAfterCrash, MockParams.LIQUIDATION_THRESHOLD);

        // ── 4. Liquidator repays part of the debt, receives discounted WETH ─
        uint256 debtToCover = MockParams.BORROW_USDC / 2; // partial liquidation

        uint256 liquidatorWethBefore = IERC20(Addresses.WETH_POLYGON).balanceOf(liquidator);
        uint256 borrowerDebtBefore = IERC20(Addresses.VAR_DEBT_POL_USDC).balanceOf(borrower);

        vm.startPrank(liquidator);
        IERC20(Addresses.USDC_E_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, debtToCover);

        pool.liquidationCall(
            Addresses.WETH_POLYGON,    // collateral asset seized
            Addresses.USDC_E_POLYGON,  // debt asset repaid
            borrower,
            debtToCover,
            false // false = receive underlying WETH, not aTokens
        );
        vm.stopPrank();

        uint256 liquidatorWethAfter = IERC20(Addresses.WETH_POLYGON).balanceOf(liquidator);
        uint256 borrowerDebtAfter = IERC20(Addresses.VAR_DEBT_POL_USDC).balanceOf(borrower);

        uint256 wethSeized = liquidatorWethAfter - liquidatorWethBefore;
        console.log("WETH seized by liquidator:", wethSeized);
        console.log("Borrower debt before liquidation:", borrowerDebtBefore);
        console.log("Borrower debt after liquidation:", borrowerDebtAfter);

        // ── 5. Verify outcomes ───────────────────────────────────────────────
        assertGt(wethSeized, 0);
        assertLt(borrowerDebtAfter, borrowerDebtBefore);
        assertApproxEqAbs(borrowerDebtBefore - borrowerDebtAfter, debtToCover, 1e6); // ~debtToCover repaid
    }    
}