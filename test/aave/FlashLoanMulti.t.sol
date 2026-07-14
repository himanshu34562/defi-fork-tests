// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20} from "../interfaces/IUniswapV2.sol";
import {IAavePool} from "../interfaces/IAaveV3.sol";
import {FlashLoanReceiverMulti} from "../../src/FlashLoanReceiverMulti.sol";

contract AaveFlashLoanMultiTest is Test {
    IAavePool pool;
    FlashLoanReceiverMulti receiver;

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), MockParams.AAVE_FORK_BLOCK_POLYGON);
        vm.selectFork(fork);

        pool = IAavePool(Addresses.AAVE_POOL_POLYGON);
        receiver = new FlashLoanReceiverMulti(Addresses.AAVE_POOL_POLYGON);

        // Fund receiver with buffers to cover premiums on both assets (0.05% each)
        deal(Addresses.USDC_E_POLYGON, address(receiver), 10e6);   // 10 USDC buffer
        deal(Addresses.DAI_POLYGON, address(receiver), 10e18);     // 10 DAI buffer
    }

    function test_flashLoan_multiAsset_borrowAndRepay() public {
        address[] memory assets = new address[](2);
        assets[0] = Addresses.USDC_E_POLYGON;
        assets[1] = Addresses.DAI_POLYGON;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = MockParams.THOUSAND_USDC;
        amounts[1] = MockParams.THOUSAND_DAI;

        uint256[] memory modes = new uint256[](2);
        modes[0] = 0; // 0 = repay in same tx (not a borrow)
        modes[1] = 0;

        uint256 usdcBefore = IERC20(Addresses.USDC_E_POLYGON).balanceOf(address(receiver));
        uint256 daiBefore = IERC20(Addresses.DAI_POLYGON).balanceOf(address(receiver));

        pool.flashLoan(
            address(receiver),
            assets,
            amounts,
            modes,
            address(receiver),
            "",
            MockParams.REFERRAL_CODE
        );

        uint256 usdcAfter = IERC20(Addresses.USDC_E_POLYGON).balanceOf(address(receiver));
        uint256 daiAfter = IERC20(Addresses.DAI_POLYGON).balanceOf(address(receiver));

        uint256 usdcPremium = usdcBefore - usdcAfter;
        uint256 daiPremium = daiBefore - daiAfter;

        console.log("USDC premium paid:", usdcPremium);
        console.log("DAI premium paid:", daiPremium);

        // 0.05% of 1000 USDC (6 dec) = 500000 ; 0.05% of 1000 DAI (18 dec) = 5e17
        assertEq(usdcPremium, 500000);
        assertEq(daiPremium, 5e17);
    }
}