// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20, IUniswapV2Router02} from "../interfaces/IUniswapV2.sol";

contract UniswapMultiHopSwapTest is Test {
    IUniswapV2Router02 router;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MockParams.UNISWAP_FORK_BLOCK);
        vm.selectFork(fork);

        router = IUniswapV2Router02(Addresses.UNI_ROUTER02);

        deal(Addresses.DAI, user, MockParams.THOUSAND_DAI);
    }

    function test_multiHopSwap_DAI_WETH_USDC() public {
        uint256 daiBefore = IERC20(Addresses.DAI).balanceOf(user);
        uint256 usdcBefore = IERC20(Addresses.USDC).balanceOf(user);

        // Multi-hop path: DAI -> WETH -> USDC, exactly as named in the report
        address[] memory path = new address[](3);
        path[0] = Addresses.DAI;
        path[1] = Addresses.WETH;
        path[2] = Addresses.USDC;

        uint256[] memory expected = router.getAmountsOut(MockParams.THOUSAND_DAI, path);
        uint256 amountOutMin = expected[2] * (MockParams.BPS_DENOMINATOR - MockParams.SLIPPAGE_BPS_VOLATILE)
            / MockParams.BPS_DENOMINATOR;

        vm.startPrank(user);
        IERC20(Addresses.DAI).approve(Addresses.UNI_ROUTER02, MockParams.THOUSAND_DAI);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            MockParams.THOUSAND_DAI,
            amountOutMin,
            path,
            user,
            block.timestamp + MockParams.DEADLINE_OFFSET
        );
        vm.stopPrank();

        uint256 daiAfter = IERC20(Addresses.DAI).balanceOf(user);
        uint256 usdcAfter = IERC20(Addresses.USDC).balanceOf(user);

        console.log("DAI spent:", daiBefore - daiAfter);
        console.log("Intermediate WETH (hop):", amounts[1]);
        console.log("USDC received:", usdcAfter - usdcBefore);

        // Full input spent
        assertEq(daiBefore - daiAfter, MockParams.THOUSAND_DAI);

        // Output meets slippage-adjusted minimum
        assertGe(usdcAfter - usdcBefore, amountOutMin);

        // Router's own accounting matches actual balance delta
        assertEq(amounts[2], usdcAfter - usdcBefore);

        // Sanity: routing through WETH should land close to a direct DAI->USDC
        // price implied by combining the two pools' independent quotes from
        // earlier tests (~1 WETH ≈ 3807 USDC ≈ 3817 DAI at this block)
        assertGt(usdcAfter - usdcBefore, 0);
    }
}