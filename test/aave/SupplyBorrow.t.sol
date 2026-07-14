// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool} from "../interfaces/IAaveV3.sol";

contract AaveSupplyBorrowTest is Test {
    IAavePool pool;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);

        deal(Addresses.USDC_E_POLYGON, user, MockParams.SUPPLY_USDC);
    }

    function test_supplyThenBorrow() public {
        vm.startPrank(user);

        // 1. Supply USDC.e as collateral
        IERC20(Addresses.USDC_E_POLYGON).approve(Addresses.AAVE_POOL_POLYGON, MockParams.SUPPLY_USDC);
        pool.supply(Addresses.USDC_E_POLYGON, MockParams.SUPPLY_USDC, user, MockParams.REFERRAL_CODE);

        uint256 aTokenBalance = IERC20(Addresses.aPOL_USDC).balanceOf(user);
        console.log("aUSDC received:", aTokenBalance);
        assertEq(aTokenBalance, MockParams.SUPPLY_USDC);

        // 2. Check borrowing power before borrowing
        (
            uint256 totalCollateralBase,
            ,
            uint256 availableBorrowsBase,
            ,
            ,
            uint256 healthFactorBefore
        ) = pool.getUserAccountData(user);

        console.log("Total collateral (USD, 8dec):", totalCollateralBase);
        console.log("Available to borrow (USD, 8dec):", availableBorrowsBase);
        console.log("Health factor before borrow:", healthFactorBefore);

        // 3. Borrow DAI against the collateral, variable rate
        pool.borrow(
            Addresses.DAI_POLYGON,
            MockParams.BORROW_DAI,
            MockParams.VARIABLE_RATE,
            MockParams.REFERRAL_CODE,
            user
        );

        uint256 daiBalance = IERC20(Addresses.DAI_POLYGON).balanceOf(user);
        console.log("DAI borrowed:", daiBalance);
        assertEq(daiBalance, MockParams.BORROW_DAI);

        // 4. Confirm health factor is still safe post-borrow
        (,,,,, uint256 healthFactorAfter) = pool.getUserAccountData(user);
        console.log("Health factor after borrow:", healthFactorAfter);

        assertGt(healthFactorAfter, MockParams.LIQUIDATION_THRESHOLD);

        vm.stopPrank();
    }
}