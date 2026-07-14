// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Standard mock input parameters, sourced from the DeFi Forking
///         Manifest sections 1.3 / 2.3 / 3.3. Single source of truth for
///         amounts, slippage, deadlines, rate modes, and fork blocks so
///         every test runs against the same known-good fixtures.
library MockParams {
    // ─────────────────────────────────────────────────────────────────────
    // Fork blocks (pinned for deterministic, reproducible tests)
    // ─────────────────────────────────────────────────────────────────────
    uint256 constant UNISWAP_FORK_BLOCK = 20_000_000; // ~July 2024, deep liquidity
    uint256 constant AAVE_FORK_BLOCK_POLYGON = 58_000_000; // ~early 2024, all reserves active
    uint256 constant CHAINLINK_FORK_BLOCK_ETH = 20_000_000;
    uint256 constant CHAINLINK_FORK_BLOCK_POLY = 58_000_000;

    // ─────────────────────────────────────────────────────────────────────
    // Token amounts (human-readable → on-chain)
    // WETH/DAI: 18 decimals | USDC/USDT: 6 decimals | WBTC: 8 decimals
    // ─────────────────────────────────────────────────────────────────────
    uint256 constant ONE_WETH = 1e18;
    uint256 constant TEN_WETH = 10e18;
    uint256 constant THOUSAND_USDC = 1_000e6;
    uint256 constant THOUSAND_DAI = 1_000e18;
    uint256 constant ONE_WBTC = 1e8;

    // ─────────────────────────────────────────────────────────────────────
    // Uniswap V2 swap parameters
    // ─────────────────────────────────────────────────────────────────────
    uint256 constant DEADLINE_OFFSET = 15 minutes; // always relative to block.timestamp

    // Slippage in basis points: volatile pairs 50 bps, stable pairs 10 bps
    uint256 constant SLIPPAGE_BPS_VOLATILE = 50;
    uint256 constant SLIPPAGE_BPS_STABLE = 10;
    uint256 constant BPS_DENOMINATOR = 10_000;

    // ─────────────────────────────────────────────────────────────────────
    // Aave V3 parameters
    // ─────────────────────────────────────────────────────────────────────
    uint256 constant SUPPLY_USDC = 1_000e6; // 1000 USDC
    uint256 constant SUPPLY_WETH = 1e18; // 1 WETH
    uint256 constant BORROW_USDC = 500e6; // 500 USDC
    uint256 constant BORROW_DAI = 500e18; // 500 DAI

    uint256 constant STABLE_RATE = 1; // often disabled on V3 — avoid
    uint256 constant VARIABLE_RATE = 2; // always use this

    uint16 constant REFERRAL_CODE = 0;

    // Health factor thresholds (18 decimals)
    uint256 constant LIQUIDATION_THRESHOLD = 1e18; // < 1e18 => liquidatable
    uint256 constant SAFE_HEALTH_FACTOR = 1.5e18; // comfortably safe

    uint256 constant RAY = 1e27; // Aave interest rates use Ray precision

    // ─────────────────────────────────────────────────────────────────────
    // Chainlink parameters
    // ─────────────────────────────────────────────────────────────────────
    uint8 constant CHAINLINK_DECIMALS = 8;
    uint256 constant CHAINLINK_PRECISION = 1e8;

    // Staleness thresholds (heartbeat, in seconds)
    uint256 constant ETH_USD_HEARTBEAT = 3_600; // 1 hour
    uint256 constant BTC_USD_HEARTBEAT = 3_600; // 1 hour
    uint256 constant USDC_USD_HEARTBEAT = 86_400; // 24 hours
    uint256 constant USDT_USD_HEARTBEAT = 86_400; // 24 hours
    uint256 constant DAI_USD_HEARTBEAT = 3_600; // 1 hour
    uint256 constant POLYGON_HEARTBEAT = 60; // conservative 1 min (27s actual)
}