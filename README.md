# DeFi Fork Testing Suite

A Foundry-based mainnet-fork integration test suite validating real, on-chain
protocol interactions across **Uniswap V2**, **Aave V3**, and **Chainlink**
price feeds — built directly on top of a verified DeFi protocol reference
manifest (`defi_forking_manifest.md`).

This is a **testing/validation harness**, not a trading bot or standalone
product. Its purpose is to put the manifest into practice: build real,
executable software directly from its documented addresses, interfaces, and
parameters, and confirm that all of it functions correctly against real,
forked mainnet and Polygon state — before any of it gets integrated into a
larger system (bot, monitoring tool, or strategy layer).

---

## Why this exists

The manifest documents verified contract addresses, Solidity interfaces, and
standard mock parameters for three protocols, intended as a reference for
on-chain integration work. This suite puts that reference into action:

- Executes real transactions against **pinned historical blocks** on forked
  mainnet/Polygon state (via Foundry + Alchemy archive RPC access)
- Confirms every address, interface signature, and parameter in the manifest
  behaves exactly as documented, via real passing tests rather than
  inspection alone
- Extends the manifest's interface coverage to two additional scenarios —
  single-asset flash loans and liquidation — that fall within its documented
  scope (evidenced by its own `SAFE_HEALTH_FACTOR` and flash-loan
  parameters) but hadn't yet been written out as callable interfaces
- Serves as a **regression suite**: if a protocol address changes or an
  interface is upgraded, rerunning this suite catches the drift immediately

---

## Documentation

This repository includes three companion documents alongside the code:

| Document | Purpose |
|---|---|
| [`defi_forking_manifest.md`](./defi_forking_manifest.md) | The master reference manifest — verified addresses, interfaces, and mock parameters, with validation status and extensions documented inline |
| [`DeFi_Fork_Testing_Report.pdf`](./DeFi_Fork_Testing_Report.pdf) | Full project report: methodology, implementation walkthrough, results, and cross-validation analysis |
| `README.md` (this file) | Repository overview and quick reference for the test suite itself |

---

## Tech stack

- **Foundry** (Forge) — Solidity-native testing framework
- **Alchemy** — archive-node RPC access for Ethereum Mainnet and Polygon Mainnet
- Fork blocks pinned per the manifest for deterministic, reproducible results:
  - Ethereum Mainnet: block `20,000,000`
  - Polygon Mainnet: block `58,000,000`

---

## Project Structure

```
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
├── defi_forking_manifest.md            # master reference manifest
├── DeFi_Fork_Testing_Report.pdf        # full project report
└── README.md
```

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
| 2.2 Aave V3 interfaces (incl. extensions) | `test/interfaces/IAaveV3.sol` |
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
`IFlashLoanSimpleReceiver` — an interface extension added to the manifest's
Aave section (see "Suite Extensions" below). Verifies the exact premium
(0.05% — Aave V3's standard flash loan fee) is paid.
> Result: 1,000 USDC borrowed, 0.5 USDC premium paid exactly.

**`FlashLoanMulti.t.sol` — `test_flashLoan_multiAsset_borrowAndRepay`**
Executes a multi-asset flash loan (USDC.e + DAI simultaneously) via
`flashLoan`, using a second receiver contract
(`src/FlashLoanReceiverMulti.sol`) implementing the manifest's originally
documented, array-based `IFlashLoanReceiver`. Verifies both premiums
independently.

**`Liquidation.t.sol` — `test_liquidation_afterPriceCrash`**
The most involved test in the suite. Establishes a WETH-collateralized
borrow position, then uses `vm.mockCall` to simulate a ~90% WETH price crash
via Aave's price oracle — a standard Foundry testing technique for
simulating market conditions that can't be replayed from real historical
data. Confirms the position becomes liquidatable (health factor < 1.0), then
executes a real `liquidationCall` — an interface extension added to the
manifest's `IAavePool` to act on its already-documented
`LIQUIDATION_THRESHOLD` and `SAFE_HEALTH_FACTOR` constants — from a second
address acting as liquidator. Verifies the liquidator's seized collateral
reflects Aave's liquidation bonus, and that the borrower's debt is correctly
reduced.
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

All four independent sources land within ~0.5% of each other — strong
evidence that the manifest's fixtures, fork pinning, and interfaces are
correct and internally consistent.

---

## Suite extensions and implementation notes

Building this suite directly from the manifest surfaced a small number of
practical implementation details. None of these reflect errors in the
manifest's underlying data — they're documented here for transparency, and
in full detail in the accompanying report.

- **Address casing normalized for compiler compatibility**: 5 addresses
  required letter-casing adjustments to satisfy Solidity's EIP-55 checksum
  validation at compile time. The underlying address values were correct and
  unchanged throughout — only formatting was adjusted. All affected
  addresses were additionally cross-referenced against Etherscan/Polygonscan
  to confirm they resolve to the correct, verified contracts.
- **`IFlashLoanSimpleReceiver` added**: Aave V3 exposes a single-asset flash
  loan entry point (`flashLoanSimple()`) alongside the multi-asset
  `flashLoan()` the manifest originally documented. A companion callback
  interface was added to extend coverage to both entry points.
- **`liquidationCall` added to `IAavePool`**: the manifest documented
  liquidation-related constants (`LIQUIDATION_THRESHOLD`,
  `SAFE_HEALTH_FACTOR`) without the function that acts on them. This was
  added to build out the full liquidation scenario described above.
- **Liquidation test calibration**: an initial 66% simulated price crash
  wasn't steep enough to trigger liquidation given the manifest's
  conservative documented borrow amounts; increased to ~90% to correctly
  demonstrate the mechanism.

See `defi_forking_manifest.md` (Validation & Extension Summary) and
`DeFi_Fork_Testing_Report.pdf` (Section 6) for full detail on each of these.

---

## What remains (not yet covered)

This suite covers the **core lifecycle** of all three protocols. The
following manifest-documented functions are extensions of already-proven
interfaces and represent reasonable next steps rather than new integration
risk:

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

---

## Test results summary

```
11 test files, 16 test functions, all passing
✔ Uniswap V2:  4 test files (swap, addLiquidity, removeLiquidity, multi-hop)
✔ Aave V3:     6 test files (supply/borrow, repay, withdraw,
                              flashLoanSimple, flashLoan multi, liquidation)
✔ Chainlink:   1 test file, 4 sub-tests (staleness + sanity validation)
```

Run the full suite:

```bash
forge test -vvv
```

---

## Status

This is a **validation layer**, built to put the manifest's documented
addresses, interfaces, and parameters into real, executable use, and to
confirm — through passing tests against live forked state — that it forms a
reliable foundation for future integration work (e.g. a bot, monitoring
tool, or strategy layer). It is not itself a trading system or production
deployment target.