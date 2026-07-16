// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {IERC20, IUniswapV2Router02, IUniswapV2Pair} from "../interfaces/IUniswapV2.sol";

contract UniswapRemoveLiquidityTest is Test {
    IUniswapV2Router02 router;
    IUniswapV2Pair pair;
    address user = address(0xBEEF);

    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MockParams.UNISWAP_FORK_BLOCK);
        vm.selectFork(fork);

        router = IUniswapV2Router02(Addresses.UNI_ROUTER02);
        pair = IUniswapV2Pair(Addresses.PAIR_WETH_DAI);

        // Replicate the same add-liquidity position as LiquidityAdd.t.sol
        // so this test is self-contained and doesn't depend on test order.
        deal(Addresses.WETH, user, MockParams.TEN_WETH);
        deal(Addresses.DAI, user, MockParams.THOUSAND_DAI * 10);

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        uint256 daiReserve = token0 == Addresses.DAI ? reserve0 : reserve1;
        uint256 wethReserve = token0 == Addresses.DAI ? reserve1 : reserve0;

        uint256 wethToAdd = MockParams.ONE_WETH;
        uint256 daiToAdd = (wethToAdd * daiReserve) / wethReserve;

        vm.startPrank(user);
        IERC20(Addresses.WETH).approve(Addresses.UNI_ROUTER02, wethToAdd);
        IERC20(Addresses.DAI).approve(Addresses.UNI_ROUTER02, daiToAdd);

        router.addLiquidity(
            Addresses.WETH,
            Addresses.DAI,
            wethToAdd,
            daiToAdd,
            0,
            0,
            user,
            block.timestamp + MockParams.DEADLINE_OFFSET
        );
        vm.stopPrank();
    }

    function test_removeLiquidity_returnsBothTokens() public {
        uint256 lpBalance = pair.balanceOf(user);
        console.log("LP tokens held before removal:", lpBalance);
        assertGt(lpBalance, 0);

        uint256 wethBefore = IERC20(Addresses.WETH).balanceOf(user);
        uint256 daiBefore = IERC20(Addresses.DAI).balanceOf(user);

        vm.startPrank(user);
        pair.approve(Addresses.UNI_ROUTER02, lpBalance);

        (uint256 amountWeth, uint256 amountDai) = router.removeLiquidity(
            Addresses.WETH,
            Addresses.DAI,
            lpBalance,
            0, // amountAMin - accept any amount back for this proof-of-mechanism test
            0, // amountBMin
            user,
            block.timestamp + MockParams.DEADLINE_OFFSET
        );
        vm.stopPrank();

        uint256 wethAfter = IERC20(Addresses.WETH).balanceOf(user);
        uint256 daiAfter = IERC20(Addresses.DAI).balanceOf(user);
        uint256 lpAfter = pair.balanceOf(user);

        console.log("WETH returned:", amountWeth);
        console.log("DAI returned:", amountDai);
        console.log("LP tokens after removal:", lpAfter);

        // LP tokens fully burned
        assertEq(lpAfter, 0);

        // Both underlying tokens returned to user
        assertEq(wethAfter - wethBefore, amountWeth);
        assertEq(daiAfter - daiBefore, amountDai);
        assertGt(amountWeth, 0);
        assertGt(amountDai, 0);
    }
}