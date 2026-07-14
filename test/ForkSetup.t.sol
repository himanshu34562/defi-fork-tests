// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

contract ForkSetupTest is Test {
    function test_mainnetForkAtBlock() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 20_000_000);
        vm.selectFork(fork);
        assertEq(block.number, 20_000_000);
    }

    function test_polygonForkAtBlock() public {
        uint256 fork = vm.createFork(vm.envString("POLYGON_RPC_URL"), 58_000_000);
        vm.selectFork(fork);
        assertEq(block.number, 58_000_000);
    }
}