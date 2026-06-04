export const ADDRESSES = {
  SFCEngine: "0xb3aaed6233f01d0b77ec265a7bdfce83e71bf9f1" as `0x${string}`,
  StableForgeCoin: "0x98b1383944e6058643183a842578c4df0d096245" as `0x${string}`,
  WETH: "0xdd13E55209Fd76AfE204dBda4007C227904f0a81" as `0x${string}`,
  WBTC: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063" as `0x${string}`,
  ETH_USD_FEED: "0x694AA1769357215DE4FAC081bf1f309aDC325306" as `0x${string}`,
  BTC_USD_FEED: "0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43" as `0x${string}`,
} as const;

export const SFC_ENGINE_ABI = [
  // Write functions
  {
    name: "depositCollateral",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "tokenCollateralAddress", type: "address" },
      { name: "amountCollateral", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "depositCollateralAndMintDsc",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "tokenCollateralAddress", type: "address" },
      { name: "amountCollateral", type: "uint256" },
      { name: "amountDscToMint", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "mintDsc",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "amountDscToMint", type: "uint256" }],
    outputs: [],
  },
  {
    name: "burnDsc",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    name: "redeemCollateral",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "tokenCollateralAddress", type: "address" },
      { name: "amountCollateral", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "redeemCollateralForDsc",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "tokenCollateralAddress", type: "address" },
      { name: "amountCollateral", type: "uint256" },
      { name: "amountDscToBurn", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "liquidate",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "collateral", type: "address" },
      { name: "user", type: "address" },
      { name: "debtToCover", type: "uint256" },
    ],
    outputs: [],
  },
  // View functions
  {
    name: "getAccountInformation",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [
      { name: "totalDscMinted", type: "uint256" },
      { name: "collateralValueInUsd", type: "uint256" },
    ],
  },
  {
    name: "getHealthFactor",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getCollateralBalanceOfUser",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "user", type: "address" },
      { name: "token", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getAccountCollateralValue",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "totalCollateralValueInUsd", type: "uint256" }],
  },
  {
    name: "getUsdValue",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "token", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getTokenAmountFromUsd",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "token", type: "address" },
      { name: "usdAmountInWei", type: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getCollateralTokens",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address[]" }],
  },
  {
    name: "getLiquidationBonus",
    type: "function",
    stateMutability: "pure",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getLiquidationThreshold",
    type: "function",
    stateMutability: "pure",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "getMinHealthFactor",
    type: "function",
    stateMutability: "pure",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  // Events
  {
    name: "CollateralDeposited",
    type: "event",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "token", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    name: "CollateralRedeemed",
    type: "event",
    inputs: [
      { name: "redeemedFrom", type: "address", indexed: true },
      { name: "redeemedTo", type: "address", indexed: true },
      { name: "token", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
] as const;

export const ERC20_ABI = [
  {
    name: "approve",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    name: "allowance",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "decimals",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
] as const;

export const COLLATERAL_TOKENS = [
  {
    address: ADDRESSES.WETH,
    symbol: "WETH",
    name: "Wrapped Ether",
    priceFeed: ADDRESSES.ETH_USD_FEED,
    decimals: 18,
    color: "#627EEA",
  },
  {
    address: ADDRESSES.WBTC,
    symbol: "WBTC",
    name: "Wrapped Bitcoin",
    priceFeed: ADDRESSES.BTC_USD_FEED,
    decimals: 8,
    color: "#F7931A",
  },
] as const;

export type CollateralToken = typeof COLLATERAL_TOKENS[number];
