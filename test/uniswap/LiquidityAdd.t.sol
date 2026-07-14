// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20, IUniswapV2Router02, IUniswapV2Pair} from "../interfaces/IUniswapV2.sol";

contract UniswapAddLiquidityTest is Test {
    IUniswapV2Router02 router;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MockParams.UNISWAP_FORK_BLOCK);
        vm.selectFork(fork);

        router = IUniswapV2Router02(Addresses.UNI_ROUTER02);

        // Fund user with both sides of the pair
        deal(Addresses.WETH, user, MockParams.TEN_WETH);
        deal(Addresses.DAI, user, MockParams.THOUSAND_DAI * 10); // 10,000 DAI buffer
    }

    function test_addLiquidity_WETH_DAI() public {
        IUniswapV2Pair pair = IUniswapV2Pair(Addresses.PAIR_WETH_DAI);

        // Read current pool reserves to compute a fair deposit ratio
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        address token0 = pair.token0();

        // token0 is DAI per report's note: token0 is always the lower address numerically
        uint256 daiReserve = token0 == Addresses.DAI ? reserve0 : reserve1;
        uint256 wethReserve = token0 == Addresses.DAI ? reserve1 : reserve0;

        uint256 wethToAdd = MockParams.ONE_WETH;
        // Compute matching DAI amount from the pool's current ratio to avoid
        // large slippage / imbalanced deposit rejection
        uint256 daiToAdd = (wethToAdd * daiReserve) / wethReserve;

        console.log("WETH reserve:", wethReserve);
        console.log("DAI reserve:", daiReserve);
        console.log("WETH to add:", wethToAdd);
        console.log("DAI to add (matched ratio):", daiToAdd);

        vm.startPrank(user);
        IERC20(Addresses.WETH).approve(Addresses.UNI_ROUTER02, wethToAdd);
        IERC20(Addresses.DAI).approve(Addresses.UNI_ROUTER02, daiToAdd);

        uint256 lpBefore = pair.balanceOf(user);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router.addLiquidity(
            Addresses.WETH,
            Addresses.DAI,
            wethToAdd,
            daiToAdd,
            wethToAdd * (MockParams.BPS_DENOMINATOR - MockParams.SLIPPAGE_BPS_VOLATILE) / MockParams.BPS_DENOMINATOR,
            daiToAdd * (MockParams.BPS_DENOMINATOR - MockParams.SLIPPAGE_BPS_VOLATILE) / MockParams.BPS_DENOMINATOR,
            user,
            block.timestamp + MockParams.DEADLINE_OFFSET
        );
        vm.stopPrank();

        uint256 lpAfter = pair.balanceOf(user);

        console.log("WETH actually used:", amountA);
        console.log("DAI actually used:", amountB);
        console.log("LP tokens minted:", liquidity);

        assertEq(lpAfter - lpBefore, liquidity);
        assertGt(liquidity, 0);
        assertLe(amountA, wethToAdd);
        assertLe(amountB, daiToAdd);
    }
}