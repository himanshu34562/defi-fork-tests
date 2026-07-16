# DeFi Fork Testing Suite

A Foundry-based mainnet-fork integration test suite validating real, on-chain
protocol interactions across **Uniswap V2**, **Aave V3**, and **Chainlink**
price feeds — built directly from a verified DeFi protocol reference manifest
(the "DeFi Forking Manifest").

This is a **testing/validation harness**, not a trading bot or standalone
product. Its purpose is to prove that every address, interface, and parameter
documented in the manifest is correct and functions as expected against real,
forked mainnet and Polygon state — before any of it gets integrated into a
larger system (bot, monitoring tool, or strategy layer).

---

## Why this exists

The original manifest documented verified contract addresses, Solidity
interfaces, and standard mock parameters for three protocols, intended as a
reference for future on-chain integrations. Trusting a document is not the
same as proving it works. This suite:

- Executes real transactions against **pinned historical blocks** on forked
  mainnet/Polygon state (via Foundry + Alchemy archive RPC access)
- Verifies every address, interface signature, and parameter in the manifest
  actually behaves as documented
- Caught and fixed **5 EIP-55 checksum errors** in the original address list
  during transcription — a concrete example of why validation matters before
  addresses are trusted in production code
- Serves as a **regression suite**: if a protocol address changes or an
  interface is upgraded, rerunning this suite catches the drift immediately

---

## Tech stack

- **Foundry** (Forge) — Solidity-native testing framework
- **Alchemy** — archive-node RPC access for Ethereum Mainnet and Polygon Mainnet
- Fork blocks pinned per the manifest for deterministic, reproducible results:
  - Ethereum Mainnet: block `20,000,000`
  - Polygon Mainnet: block `58,000,000`

---

## Project structure
defi-fork-tests/
├── src/
│   ├── FlashLoanReceiver.sol          # single-asset flash loan callback
│   └── FlashLoanReceiverMulti.sol     # multi-asset flash loan callback
├── test/
│   ├── fixtures/
│   │   ├── Addresses.sol              # all verified contract/token addresses
│   │   └── MockParams.sol             # amounts, slippage, deadlines, fork blocks
│   ├── interfaces/
│   │   ├── IUniswapV2.sol
│   │   ├── IAaveV3.sol
│   │   └── IChainlink.sol
│   ├── uniswap/
│   │   ├── Swap.t.sol
│   │   ├── LiquidityAdd.t.sol
│   │   ├── LiquidityRemove.t.sol
│   │   └── MultiHopSwap.t.sol
│   ├── aave/
│   │   ├── SupplyBorrow.t.sol
│   │   ├── FlashLoan.t.sol
│   │   ├── FlashLoanMulti.t.sol
│   │   ├── Repay.t.sol
│   │   ├── Withdraw.t.sol
│   │   └── Liquidation.t.sol
│   ├── chainlink/
│   │   └── PriceStaleness.t.sol
│   └── ForkSetup.t.sol                # baseline fork-validation test
├── foundry.toml
├── .env                                # RPC URLs (gitignored, not committed)
└── README.md

---

## Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and enter the repo
git clone https://github.com/himanshu34562/defi-fork-tests.git
cd defi-fork-tests

# Configure RPC access — create a .env file:
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/<your-key>
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/<your-key>

# Load env vars and run all tests
source .env
forge test -vvv
```

Archive-node access (via Alchemy or Infura) is required, since tests fork at
specific historical block numbers rather than the current chain tip.

---

## How this maps to the manifest

| Manifest Section | Covered By |
|---|---|
| 1.1 Uniswap V2 addresses | `test/fixtures/Addresses.sol` |
| 1.2 Uniswap V2 interfaces | `test/interfaces/IUniswapV2.sol` |
| 1.3 Uniswap V2 mock params | `test/fixtures/MockParams.sol` |
| 2.1 Aave V3 addresses | `test/fixtures/Addresses.sol` |
| 2.2 Aave V3 interfaces | `test/interfaces/IAaveV3.sol` |
| 2.3 Aave V3 mock params | `test/fixtures/MockParams.sol` |
| 3.1 Chainlink feed addresses | `test/fixtures/Addresses.sol` |
| 3.2 Chainlink interface | `test/interfaces/IChainlink.sol` |
| 3.3 Chainlink mock params | `test/fixtures/MockParams.sol` |

Fixtures are a **single source of truth** — every test references
`Addresses.X` and `MockParams.Y` rather than hardcoding values, so the
manifest's data only needs to be correct in one place.

---

## Test suite breakdown

### Uniswap V2

**`Swap.t.sol` — `test_swapExactWETHForUSDC`**
Swaps 1 WETH for USDC via `swapExactTokensForTokens`, using a live on-chain
quote (`getAmountsOut`) and the manifest's documented 50 bps slippage
tolerance for volatile pairs. Verifies the router's returned amount matches
the actual balance change.
> Result: 1 WETH → 3,807.77 USDC at block 20,000,000.

**`LiquidityAdd.t.sol` — `test_addLiquidity_WETH_DAI`**
Reads live pool reserves, computes a ratio-matched WETH/DAI deposit to avoid
imbalanced-deposit slippage, and adds liquidity. Verifies LP tokens are
minted 1:1 with the router's returned `liquidity` value.
> Result: 1 WETH + 3,817.7 DAI deposited → 32.3 LP tokens minted.

**`LiquidityRemove.t.sol` — `test_removeLiquidity_returnsBothTokens`**
Closes the loop on liquidity provision: burns LP tokens via `removeLiquidity`
and verifies both underlying tokens are returned in full (within 1 wei
rounding, standard for AMMs).

**`MultiHopSwap.t.sol` — `test_multiHopSwap_DAI_WETH_USDC`**
Executes the exact multi-hop path named in the manifest (DAI → WETH → USDC),
verifying the router correctly reports the intermediate hop amount and final
output, and that pricing is consistent with the direct-swap and liquidity
tests above (cross-validation across independent pools).

### Aave V3

**`SupplyBorrow.t.sol` — `test_supplyThenBorrow`**
Supplies 1,000 USDC.e as collateral (receiving aTokens 1:1), then borrows 500
DAI at the variable rate. Validates health factor both before borrowing
(uint256.max — Aave's "no debt" convention) and after (1.56 — above the
manifest's documented safe threshold of 1.5).

**`Repay.t.sol` — `test_repay_clearsDebt`**
Repays the full DAI debt using `type(uint256).max` (per the manifest's
documented pattern for full-balance repayment including accrued interest).
Verifies debt tokens burn to exactly zero and health factor returns to
uint256.max.

**`Withdraw.t.sol` — `test_withdraw_returnsUnderlyingAndBurnsAToken`**
Withdraws the full USDC.e collateral position. Verifies aTokens burn to zero
and the underlying asset is returned 1:1.

**`FlashLoan.t.sol` — `test_flashLoanSimple_borrowAndRepay`**
Executes a single-asset flash loan via `flashLoanSimple`, using a custom
receiver contract (`src/FlashLoanReceiver.sol`) implementing
`IFlashLoanSimpleReceiver`. Verifies the exact premium (0.05% — Aave V3's
standard flash loan fee) is paid.
> Result: 1,000 USDC borrowed, 0.5 USDC premium paid exactly.

**`FlashLoanMulti.t.sol` — `test_flashLoan_multiAsset_borrowAndRepay`**
Executes a multi-asset flash loan (USDC.e + DAI simultaneously) via
`flashLoan`, using a second receiver contract
(`src/FlashLoanReceiverMulti.sol`) implementing the array-based
`IFlashLoanReceiver`. This is a genuinely different callback interface from
the single-asset variant — discovered and fixed during development (see
"Issues encountered" below). Verifies both premiums independently.

**`Liquidation.t.sol` — `test_liquidation_afterPriceCrash`**
The most involved test in the suite. Establishes a WETH-collateralized
borrow position, then uses `vm.mockCall` to simulate a ~90% WETH price crash
via Aave's price oracle — a standard Foundry testing technique for
simulating market conditions that can't be replayed from real historical
data. Confirms the position becomes liquidatable (health factor < 1.0), then
executes a real `liquidationCall` from a second address acting as liquidator.
Verifies the liquidator's seized collateral reflects Aave's liquidation
bonus, and that the borrower's debt is correctly reduced.
> Result: health factor dropped from 6.08 → 0.61 after the simulated crash;
> liquidator repaid 250 USDC of debt and seized 0.708 WETH in return
> (liquidation bonus economics working as designed).

### Chainlink

**`PriceStaleness.t.sol`** (4 sub-tests)
- `test_ethUsdFeed_isFreshAndValid` — confirms feed decimals (8) and a valid,
  non-zero price
- `test_usdcUsdFeed_isFreshAndValid` / `test_daiUsdFeed_isFreshAndValid` —
  same checks plus a sanity band (stablecoins must read between $0.95–$1.05)
- `test_wadConversion_matchesExpected` — verifies the 8-decimal → 18-decimal
  (WAD) conversion pattern documented in the manifest

All price reads use a shared `_getSafePrice` helper that enforces the
manifest's documented staleness rule: reject if `block.timestamp - updatedAt`
exceeds the feed's heartbeat.

---

## Cross-validation

Because these tests hit real forked state rather than mocks, independent
tests naturally cross-check each other. At block 20,000,000:

| Source | Implied WETH price |
|---|---|
| Uniswap WETH/USDC swap | ~$3,807.77 |
| Uniswap WETH/DAI liquidity add | ~$3,817.72 |
| Chainlink ETH/USD feed | ~$3,810.14 |
| Multi-hop DAI→WETH→USDC swap | ~$3,809–3,830 (implied) |

All four independent sources land within ~0.5% of each other — a strong
signal that the fixtures, fork pinning, and interfaces are all internally
consistent.

---

## Issues encountered and fixed during development

- **EIP-55 checksum errors**: 5 addresses in the original manifest transcription
  failed Solidity's checksum validation. Corrected using solc's suggested
  checksums; underlying hex values were not altered, only letter casing.
- **Flash loan interface mismatch**: Aave V3 has two distinct receiver
  interfaces — `IFlashLoanReceiver` (array-based, for multi-asset
  `flashLoan()`) and `IFlashLoanSimpleReceiver` (single-value, for
  `flashLoanSimple()`). The manifest only documented the former; the latter
  was added after a live revert (`unrecognized function selector`) surfaced
  the gap.
- **`liquidationCall` missing from manifest interface**: added to
  `IAavePool` in `test/interfaces/IAaveV3.sol`, since it wasn't included in
  the original manifest's Aave interface section.
- **Insufficiently steep price crash for liquidation test**: an initial ~66%
  simulated crash left the test position too well-collateralized to trigger
  liquidation (health factor only dropped to ~2.0). Increased to a ~90%
  crash to correctly push health factor below the 1.0 threshold.

---

## What remains (not yet covered)

This suite covers the **core lifecycle** of all three protocols, but is not
100% exhaustive against every function in the manifest. Remaining gaps:

**Uniswap V2**
- `swapTokensForExactTokens` (exact-output swap direction)
- `swapExactETHForTokens` / `swapTokensForExactETH` (native ETH variants)
- Flash swaps (calling `pair.swap()` directly with non-empty `data`)
- `factory.createPair()` / `getPair()` (pair creation, not just reading
  existing pairs)

**Aave V3**
- `getReserveData()` (direct reserve/rate inspection — used indirectly via
  `getUserAccountData`, never called directly)
- `IAaveOracle.getAssetPrice()` as a first-class test (used internally by the
  liquidation test's mock, but never independently verified as its own test)

**Chainlink**
- `getRoundData()` (historical round lookups — only `latestRoundData()` is
  tested)

These are all extensions of already-proven interfaces rather than new
integration risk, and are reasonable next steps if this suite continues
beyond its current prototype scope.

---

## Test results summary
11 test files, 16 test functions, all passing
✔ Uniswap V2:  4 test files (swap, addLiquidity, removeLiquidity, multi-hop)
✔ Aave V3:     6 test files (supply/borrow, repay, withdraw,
flashLoanSimple, flashLoan multi, liquidation)
✔ Chainlink:   1 test file, 4 sub-tests (staleness + sanity validation)

Run the full suite:

```bash
forge test -vvv
```

---

## Status

This is a **prototype / validation layer**, built to prove the manifest's
documented addresses, interfaces, and parameters work correctly against live
forked state before integration into a larger system (e.g. a bot, monitoring
tool, or strategy layer). It is not itself a trading system or production
deployment target.