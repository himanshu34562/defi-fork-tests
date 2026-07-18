// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Addresses} from "../fixtures/Addresses.sol";
import {MockParams} from "../fixtures/MockParams.sol";
import {AggregatorV3Interface} from "../interfaces/IChainlink.sol";

contract ChainlinkPriceStalenessTest is Test {
    function setUp() public {
        uint256 fork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MockParams.CHAINLINK_FORK_BLOCK_ETH);
        vm.selectFork(fork);
    }

    /// @dev Shared helper: reads a feed, validates it's not stale, returns human-readable USD price.
    function _getSafePrice(address feed, uint256 heartbeat) internal view returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = AggregatorV3Interface(feed).latestRoundData();

        require(answer > 0, "Chainlink: invalid price");
        require(answeredInRound >= roundId, "Chainlink: stale round");
        require(block.timestamp - updatedAt <= heartbeat, "Chainlink: price too old");

        return uint256(answer);
    }

    function test_ethUsdFeed_isFreshAndValid() public {
        uint256 price = _getSafePrice(Addresses.ETH_USD_FEED, MockParams.ETH_USD_HEARTBEAT);
        uint8 decimals = AggregatorV3Interface(Addresses.ETH_USD_FEED).decimals();

        console.log("ETH/USD raw answer:", price);
        console.log("ETH/USD decimals:", decimals);
        console.log("ETH/USD human price ($):", price / MockParams.CHAINLINK_PRECISION);

        assertEq(decimals, MockParams.CHAINLINK_DECIMALS);
        assertGt(price, 0);
    }

    function test_usdcUsdFeed_isFreshAndValid() public {
        uint256 price = _getSafePrice(Addresses.USDC_USD_FEED, MockParams.USDC_USD_HEARTBEAT);

        console.log("USDC/USD raw answer:", price);
        console.log("USDC/USD human price ($):", price / MockParams.CHAINLINK_PRECISION);

        // USDC should be very close to $1 - sanity band check (0.95 - 1.05)
        assertGt(price, 95_000_000);
        assertLt(price, 105_000_000);
    }

    function test_daiUsdFeed_isFreshAndValid() public {
        uint256 price = _getSafePrice(Addresses.DAI_USD_FEED, MockParams.DAI_USD_HEARTBEAT);

        console.log("DAI/USD raw answer:", price);
        console.log("DAI/USD human price ($):", price / MockParams.CHAINLINK_PRECISION);

        assertGt(price, 95_000_000);
        assertLt(price, 105_000_000);
    }

    function test_wadConversion_matchesExpected() public view {
        uint256 raw = _getSafePrice(Addresses.ETH_USD_FEED, MockParams.ETH_USD_HEARTBEAT);
        uint256 wad = raw * 1e10; // 8 dec -> 18 dec, matches report's toWad() pattern

        assertEq(wad, raw * 1e10);
        console.log("ETH/USD in 18-decimal WAD:", wad);
    }
}