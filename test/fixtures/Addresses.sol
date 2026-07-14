// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Verified contract/token addresses, sourced from the DeFi Forking
///         Manifest (verified against Etherscan/Polygonscan, June 2026).
///         Kept as a single source of truth so test files never hardcode
///         addresses inline.
library Addresses {
    // ─────────────────────────────────────────────────────────────────────
    // Ethereum Mainnet — Uniswap V2
    // ─────────────────────────────────────────────────────────────────────
    address constant UNI_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNI_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address constant PAIR_WETH_USDC = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address constant PAIR_WETH_DAI = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address constant PAIR_WETH_USDT = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address constant PAIR_WETH_WBTC = 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940;
    address constant PAIR_USDC_DAI = 0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5;

    // ─────────────────────────────────────────────────────────────────────
    // Ethereum Mainnet — Aave V3
    // ─────────────────────────────────────────────────────────────────────
    address constant AAVE_POOL_ETHEREUM = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // ─────────────────────────────────────────────────────────────────────
    // Ethereum Mainnet — Chainlink price feeds
    // ─────────────────────────────────────────────────────────────────────
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant BTC_USD_FEED = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant USDT_USD_FEED = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32d;
    address constant DAI_USD_FEED = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address constant LINK_USD_FEED = 0x2c1d072e956AFFC0D435Cb7AC308d97936Ed4f5b;

    // ─────────────────────────────────────────────────────────────────────
    // Polygon Mainnet — Aave V3
    // ─────────────────────────────────────────────────────────────────────
    address constant AAVE_POOL_POLYGON = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address constant AAVE_ADDRESSES_PROVIDER_POLYGON = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant AAVE_POOL_DATA_PROVIDER_POLYGON = 0x9441B65EE553F70df9C77d45d3283B6BC24F222d;
    address constant AAVE_ORACLE_POLYGON = 0xb023e699F5a33916Ea823A16485e259257cA8Bd1;

    address constant USDC_NATIVE_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant USDC_E_POLYGON = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant USDT_POLYGON = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant WMATIC_POLYGON = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address constant DAI_POLYGON = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address constant WBTC_POLYGON = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    // aTokens (received on supply())
    address constant aPOL_USDC = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;
    address constant aPOL_WETH = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;
    address constant aPOL_DAI = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;
    address constant aPOL_USDT = 0x6ab707Aca953eDAEfBc4fD23bA73294241490620;

    // Variable debt tokens (held after borrow())
    address constant VAR_DEBT_POL_USDC = 0xFCCf3cAbbe80101232d343252614b6A3eE81C989;
    address constant VAR_DEBT_POL_WETH = 0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351;
    address constant VAR_DEBT_POL_DAI = 0x8619d80FB0141ba7F184CbF22fd724116D9f7fFc;

    // ─────────────────────────────────────────────────────────────────────
    // Polygon Mainnet — Chainlink price feeds
    // ─────────────────────────────────────────────────────────────────────
    address constant ETH_USD_FEED_POLY = 0xF9680D99D6C9589e2a93a78A04a279e509205945;
    address constant BTC_USD_FEED_POLY = 0xc907E116054Ad103354f2D350FD2514433D57F6f;
    address constant MATIC_USD_FEED_POLY = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;
    address constant USDC_USD_FEED_POLY = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    address constant USDT_USD_FEED_POLY = 0x0A6513e40db6EB1b165753AD52E80663aeA50545;
    address constant DAI_USD_FEED_POLY = 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D;
    address constant WBTC_USD_FEED_POLY = 0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6;
    address constant LINK_USD_FEED_POLY = 0xd9FFdb71EbE7496cC440152d43986Aae0AB76665;
}