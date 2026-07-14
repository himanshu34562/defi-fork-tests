// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20, IUniswapV2Router02} from "../interfaces/IUniswapV2.sol";

contract UniswapSwapTest is Test {
    IUniswapV2Router02 router;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MockParams.UNISWAP_FORK_BLOCK);
        vm.selectFork(fork);

        router = IUniswapV2Router02(Addresses.UNI_ROUTER02);

        // Give the test user WETH directly on the fork, no need to wrap real ETH
        deal(Addresses.WETH, user, MockParams.ONE_WETH);
    }

    function test_swapExactWETHForUSDC() public {
        uint256 wethBefore = IERC20(Addresses.WETH).balanceOf(user);
        uint256 usdcBefore = IERC20(Addresses.USDC).balanceOf(user);

        address[] memory path = new address[](2);
        path[0] = Addresses.WETH;
        path[1] = Addresses.USDC;

        uint256[] memory expected = router.getAmountsOut(MockParams.ONE_WETH, path);
        uint256 amountOutMin = expected[1] * (MockParams.BPS_DENOMINATOR - MockParams.SLIPPAGE_BPS_VOLATILE)
            / MockParams.BPS_DENOMINATOR;

        vm.startPrank(user);
        IERC20(Addresses.WETH).approve(Addresses.UNI_ROUTER02, MockParams.ONE_WETH);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            MockParams.ONE_WETH,
            amountOutMin,
            path,
            user,
            block.timestamp + MockParams.DEADLINE_OFFSET
        );
        vm.stopPrank();

        uint256 wethAfter = IERC20(Addresses.WETH).balanceOf(user);
        uint256 usdcAfter = IERC20(Addresses.USDC).balanceOf(user);

        console.log("WETH spent:", wethBefore - wethAfter);
        console.log("USDC received:", usdcAfter - usdcBefore);

        assertEq(wethBefore - wethAfter, MockParams.ONE_WETH);
        assertGe(usdcAfter - usdcBefore, amountOutMin);
        assertEq(amounts[1], usdcAfter - usdcBefore);
    }
}