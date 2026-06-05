# StableForge — Frontend

**Next.js interface for the StableForge decentralized stablecoin protocol on Ethereum Sepolia**

This is the official frontend for [StableForge](https://github.com/1khushibarnwal/StableForge) — a decentralized protocol that lets you mint **SFC** (StableForge Coin, a USD-pegged stablecoin) by depositing WETH or WBTC as collateral. Built with Next.js 15, Wagmi v2, RainbowKit, and Viem.

---

## Table of Contents

- [Before You Interact — What You Need to Know](#before-you-interact--what-you-need-to-know)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Page Reference](#page-reference)
- [Component Architecture](#component-architecture)
- [Data Flow](#data-flow)
- [Contract Integration](#contract-integration)
- [On-Chain Event Indexing](#on-chain-event-indexing)
- [Theme System](#theme-system)
- [Project Structure](#project-structure)
- [Environment Variables](#environment-variables)
- [Deployment](#deployment)
- [Known Limitations](#known-limitations)

---

## Before You Interact — What You Need to Know

**Read this section before using any feature of the app.**

### 1. You need Sepolia ETH for gas

All transactions happen on **Ethereum Sepolia testnet**. You need Sepolia ETH to pay gas fees. Get it free from:

- https://sepoliafaucet.com
- https://faucet.sepolia.dev

### 2. You need Sepolia WETH or WBTC to deposit collateral

The protocol accepts two collateral tokens — both are testnet ERC-20s:

| Token    | Sepolia Address                              | How to Get                             |
| -------- | -------------------------------------------- | -------------------------------------- |
| **WETH** | `0xdd13E55209Fd76AfE204dBda4007C227904f0a81` | Wrap Sepolia ETH via any WETH contract |
| **WBTC** | `0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063` | Sepolia testnet faucet or DEX          |

### 3. The collateral ratio is 200%

To mint SFC, you must lock **at least twice** the USD value in collateral.

```
Example: To mint $100 SFC → you must deposit at least $200 worth of WETH or WBTC
Maximum you can mint: 50% of your collateral's USD value
```

### 4. Your health factor is everything

Your **health factor** tells you how safe your position is:

| Health Factor | Status     | Meaning                                                   |
| ------------- | ---------- | --------------------------------------------------------- |
| `∞`           | ✅ Safe    | No debt minted                                            |
| `≥ 1.5`       | ✅ Safe    | Comfortable buffer                                        |
| `1.0 – 1.5`   | ⚠️ Warning | Getting close — consider adding collateral or burning SFC |
| `< 1.0`       | ☠️ Danger  | You **can be liquidated** — act immediately               |

```
Health Factor = (Collateral Value × 0.5) / SFC Minted
```

If ETH or BTC drops in price, your health factor drops. Monitor it regularly.

### 5. Liquidation means you lose collateral

If your health factor falls below `1.0`, **anyone** can liquidate your position:

- They repay some or all of your SFC debt
- They receive your collateral at a **10% discount**
- You lose that collateral (though your debt is cleared proportionally)

There is **no grace period**. Liquidation can happen in the same block your health factor breaks.

### 6. Every write action requires two steps: Approve → Transact

Before the protocol can move your tokens, you must approve it. The UI handles this automatically — if an approval is needed, you'll see an **Approve** button before the main action button. You'll sign two transactions:

1. `approve(SFCEngine, amount)` on the ERC-20 token
2. The actual protocol action (deposit, mint, burn, etc.)

### 7. There are no protocol fees

StableForge charges **zero fees**. You only pay Ethereum gas. No interest rate, no stability fee, no exit fee.

---

## Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn
- A browser wallet (MetaMask, Coinbase Wallet, etc.)

### Install & Run

```bash
# Clone the StableForge repo
git clone https://github.com/1khushibarnwal/StableForge.git
cd StableForge/stableforge-frontend

# Install dependencies (note: wagmi must be pinned to v2)
npm install wagmi@2.19.5
npm install

# Start the development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

> **Important:** If you get an `ERESOLVE` peer dependency error on `npm install`, run `npm install wagmi@2.19.5` first. RainbowKit 2.x requires Wagmi 2.x, but create-next-app installs Wagmi 3.x by default.

### Build for Production

```bash
npm run build
npm run start
```

---

## Configuration

Before running, update two values in `lib/`:

### 1. WalletConnect Project ID — `lib/wagmi.ts`

```ts
export const wagmiConfig = getDefaultConfig({
  appName: "StableForge",
  projectId: "YOUR_WALLETCONNECT_PROJECT_ID", // ← replace this
  chains: [sepolia],
  ssr: true,
});
```

Get a free project ID at [cloud.walletconnect.com](https://cloud.walletconnect.com). Without a real ID, WalletConnect-based wallets (e.g. mobile wallets) won't work, though injected wallets like MetaMask will.

### 2. Deployment Block — `lib/fetchLogs.ts`

```ts
export const DEPLOY_BLOCK = 8_200_000n; // ← update this
```

This is the Sepolia block at which `SFCEngine` was deployed. The `/users` and `/liquidate` pages scan from this block onward to find all depositors. If it's set too low, the app will make thousands of unnecessary RPC calls and load slowly.

**How to find your deployment block:**

1. Go to [sepolia.etherscan.io/address/0xb3aaed6233f01d0b77ec265a7bdfce83e71bf9f1](https://sepolia.etherscan.io/address/0xb3aaed6233f01d0b77ec265a7bdfce83e71bf9f1)
2. Click the first transaction in the list
3. Copy the **Block** number
4. Set it as `DEPLOY_BLOCK` in `lib/fetchLogs.ts`

---

## Page Reference

### `/` — Landing Page

What it shows: Protocol overview, key stats (200% collateral ratio, 10% liquidation bonus, WETH/WBTC, Sepolia), feature cards, 3-step explainer, and CTA.

No wallet required.

---

### `/dashboard` — My Position

What it shows: A real-time view of **your own** position in the protocol.

**Requires wallet connection.**

| Data Shown                   | Source                                          |
| ---------------------------- | ----------------------------------------------- |
| Total collateral value (USD) | `getAccountInformation(address)`                |
| SFC minted (debt)            | `getAccountInformation(address)`                |
| Health factor                | `getHealthFactor(address)`                      |
| SFC balance in wallet        | `balanceOf(address)` on StableForgeCoin         |
| WETH deposited               | `getCollateralBalanceOfUser(address, WETH)`     |
| WBTC deposited               | `getCollateralBalanceOfUser(address, WBTC)`     |
| Max mintable SFC             | Derived: `(collateralValueUsd / 2) - sfcMinted` |
| Utilization rate             | Derived: `sfcMinted / collateralValueUsd × 100` |
| Liquidation price (WETH)     | Derived: `(sfcMinted × 2) / wethAmount`         |

Data refreshes every **10 seconds** automatically.

A red warning banner appears if your health factor is below `1.5`. A critical banner appears if it's below `1.0`.

---

### `/deposit` — Deposit Collateral

What you can do here:

- Deposit **WETH** or **WBTC** into the protocol
- Optionally mint SFC in the **same transaction** (toggle "Also mint SFC")

**Flow:**

```
Select token (WETH / WBTC)
  ↓
Enter amount
  ↓
[If allowance < amount]
  → Click "Approve WETH/WBTC" → Sign tx 1
  ↓
Click "Deposit Collateral" (or "Deposit & Mint") → Sign tx 2
  ↓
Position updated
```

**Contract calls:**

- Approval: `ERC20.approve(SFCEngine, amount)`
- Deposit only: `SFCEngine.depositCollateral(token, amount)`
- Deposit + mint: `SFCEngine.depositCollateralAndMintDsc(token, collateralAmount, mintAmount)`

The "Max" button fills the amount field with your full wallet balance of the selected token.

---

### `/mint` — Mint SFC

What you can do here:

- Mint additional SFC against **already deposited** collateral

Use this page when you've already deposited collateral (e.g. via `/deposit`) and want to draw more SFC later.

**Flow:**

```
Enter SFC amount to mint
  ↓
Click "Mint SFC" → Sign tx
  ↓
SFC appears in your wallet
```

**Contract call:** `SFCEngine.mintDsc(amount)`

The "90% max" button fills 90% of your available mintable amount, leaving a health factor buffer.

> ⚠️ Minting increases your debt. Your health factor will decrease. Do not mint if you are already close to 1.0.

---

### `/burn` — Burn SFC

What you can do here:

- Burn SFC from your wallet to reduce your outstanding debt
- This improves your health factor without adding collateral

**Flow:**

```
Enter SFC amount to burn
  ↓
[If SFC allowance to SFCEngine < amount]
  → Click "Approve SFC" → Sign tx 1
  ↓
Click "Burn SFC" → Sign tx 2
  ↓
Debt reduced, health factor improves
```

**Contract calls:**

- Approval: `StableForgeCoin.approve(SFCEngine, amount)`
- Burn: `SFCEngine.burnDsc(amount)`

The "Max" button fills your full SFC wallet balance.

> 💡 If your health factor is dangerously low, burning SFC is the fastest way to recover without touching your collateral.

---

### `/redeem` — Redeem Collateral

What you can do here:

- Withdraw **WETH** or **WBTC** collateral back to your wallet
- Optionally burn SFC in the **same transaction** (toggle "Also burn SFC")

Redemption will revert if it would push your health factor below `1.0`.

**Flow:**

```
Select token (WETH / WBTC)
  ↓
Enter collateral amount to redeem
  ↓
[If "Also burn SFC" toggled]
  → [If SFC not approved] → Click "Approve SFC" → Sign tx 1
  → Enter SFC burn amount
  ↓
Click "Redeem Collateral" (or "Redeem & Burn") → Sign tx
  ↓
Collateral returned to wallet
```

**Contract calls:**

- Redeem only: `SFCEngine.redeemCollateral(token, amount)`
- Redeem + burn: `SFCEngine.redeemCollateralForDsc(token, collateralAmount, burnAmount)`

The "Max" button fills your full deposited balance of the selected token.

> ⚠️ Redeeming collateral reduces your collateral value, which lowers your health factor. The transaction will revert on-chain if it would drop your health factor below 1.0.

---

### `/liquidate` — Liquidate Positions

What you can do here:

- Browse **all protocol positions** and identify undercollateralized users
- Execute a liquidation to earn a **10% collateral bonus**

**To liquidate someone:**

1. The table shows all users indexed from on-chain `CollateralDeposited` events
2. Filter to "At Risk Only" to see positions with health factor < 1.5
3. Click any row to open the liquidation panel on the right
4. Choose which collateral token you want to receive (WETH or WBTC)
5. Enter the SFC debt you want to cover
6. Approve SFC (if not already approved), then click "Liquidate Position"

**Flow:**

```
Browse positions table (sorted by health factor)
  ↓
Click row → Liquidation panel opens
  ↓
Select collateral token to receive
  ↓
Enter debtToCover (SFC amount)
  ↓
[If SFC not approved]
  → Click "Approve SFC" → Sign tx 1
  ↓
Click "Liquidate Position" → Sign tx 2
  ↓
You receive: collateralEquivalentOfDebt + 10% bonus
```

**Contract calls:**

- Approval: `StableForgeCoin.approve(SFCEngine, debtToCover)`
- Liquidate: `SFCEngine.liquidate(collateralToken, userAddress, debtToCover)`

**The liquidation reverts if:**

- The user's health factor is ≥ 1.0 (not liquidatable)
- The liquidation doesn't improve the user's health factor
- The liquidation would break the liquidator's own health factor

> 💡 You can partially liquidate — you don't have to cover 100% of the debt.

---

### `/users` — All Protocol Users

What it shows: Every address that has ever deposited collateral into StableForge, with their current position data. Click any row to open a detailed modal.

**How users are discovered:**
The page scans `CollateralDeposited` events emitted by `SFCEngine` from `DEPLOY_BLOCK` to the latest block. It uses paginated RPC calls (9,000 blocks per request, 5 in parallel) to avoid exceeding the RPC provider's log range limit.

**Modal shows:**

- Full address + Etherscan link
- Health factor with visual bar
- SFC minted, collateral value, utilization rate
- WETH and WBTC deposited amounts
- Whether the position is currently liquidatable

**Table features:**

- Sort by health factor, SFC debt, or collateral value (ascending/descending)
- Search by address
- Status badges: Safe / Warning / At Risk / ∞ Safe

> ⚠️ If this page is slow to load, check that `DEPLOY_BLOCK` in `lib/fetchLogs.ts` is set close to your actual deployment block. Scanning from block 0 would require thousands of RPC calls.

---

## Component Architecture

```
app/
├── layout.tsx                  Root layout — wraps all pages with ThemeProvider + Providers
├── page.tsx                    / Landing page
├── dashboard/page.tsx          /dashboard
├── deposit/page.tsx            /deposit
├── mint/page.tsx               /mint
├── burn/page.tsx               /burn
├── redeem/page.tsx             /redeem
├── liquidate/page.tsx          /liquidate
└── users/page.tsx              /users

components/
├── Providers.tsx               Wagmi + QueryClient + RainbowKit providers
├── ThemeProvider.tsx           Dark/light theme context + localStorage persistence
├── Navbar.tsx                  Top navigation bar with Connect button + theme toggle
├── HealthFactorBadge.tsx       Color-coded HF badge (safe/warning/danger/infinite)
├── TxStatus.tsx                Pending/success/error transaction feedback with Etherscan link
└── PageHeader.tsx              Consistent page title + subtitle + tag

lib/
├── contracts.ts                Contract addresses, ABIs (SFCEngine + ERC-20), collateral token metadata
├── wagmi.ts                    Wagmi config — chains: [sepolia], RainbowKit getDefaultConfig
├── fetchLogs.ts                Paginated on-chain event fetcher with parallel batching
└── utils.ts                    Formatting helpers: formatUsd, formatSfc, formatHealthFactor, etc.
```

### Component Dependency Flow

```
layout.tsx
  └── ThemeProvider           (context: theme, toggleTheme)
        └── Providers         (Wagmi + QueryClient + RainbowKit)
              ├── Navbar      (usePathname, ConnectButton, useTheme)
              └── [page]
                    ├── PageHeader
                    ├── HealthFactorBadge   (uses formatHealthFactor, getHealthFactorStatus)
                    └── TxStatus            (useWaitForTransactionReceipt result)
```

---

## Data Flow

### Read Flow (view calls)

```
Page mounts
  ↓
useReadContracts([...calls])     ← wagmi hook, batches multicall
  ↓
viem decodes returndata
  ↓
Component renders with live data
  ↓
Refetch every 8–10s (refetchInterval)
```

### Write Flow (transactions)

```
User fills form → clicks action button
  ↓
useWriteContract()               ← wagmi hook
  ↓
Wallet prompts for signature
  ↓
hash returned → isPending = true
  ↓
TxStatus shows "pending"
  ↓
useWaitForTransactionReceipt(hash)
  ↓
isSuccess = true → TxStatus shows "confirmed" + Etherscan link
```

### Approval Flow

Before any token movement, the UI checks:

```
allowance = useReadContracts → ERC20.allowance(user, SFCEngine)
  ↓
if allowance < inputAmount:
  → show "Approve" button
  → on click: writeContract(ERC20.approve(SFCEngine, MaxUint256))
  ↓
after approval confirmed:
  → show main action button (enabled)
```

All approvals use `MaxUint256` — you only approve once per token.

### Users / Liquidate Event Indexing Flow

```
Component mounts
  ↓
publicClient.getBlockNumber()         ← get latest block
  ↓
Build chunk ranges [DEPLOY_BLOCK, DEPLOY_BLOCK+9000, ...]
  ↓
Promise.allSettled(5 getLogs at a time)   ← parallel batches
  ↓
Collect unique user addresses from logs
  ↓
For each address: parallel readContract calls
  (getAccountInformation, getHealthFactor, getCollateralBalanceOfUser×2)
  ↓
Render table
```

---

## Contract Integration

All contract interaction happens through two files:

### `lib/contracts.ts`

Contains:

- `ADDRESSES` — all deployed contract and token addresses
- `SFC_ENGINE_ABI` — full ABI for SFCEngine (write + view functions + events)
- `ERC20_ABI` — minimal ABI for approve/allowance/balanceOf/decimals
- `COLLATERAL_TOKENS` — array of `{ address, symbol, name, decimals, color, priceFeed }` for WETH and WBTC
- `CollateralToken` — TypeScript type for a collateral token entry

### `lib/wagmi.ts`

Configures Wagmi with:

- Chain: `sepolia` only (the app will prompt users to switch if on a different network)
- SSR: `true` (required for Next.js App Router)
- RainbowKit's `getDefaultConfig` for automatic wallet detection

### Key Wagmi Hooks Used

| Hook                           | Used For                                               |
| ------------------------------ | ------------------------------------------------------ |
| `useAccount`                   | Get connected address, connection status               |
| `useReadContracts`             | Batch multiple view calls with auto-refetch            |
| `useWriteContract`             | Send state-modifying transactions                      |
| `useWaitForTransactionReceipt` | Wait for tx confirmation, get success/error            |
| `usePublicClient`              | Low-level viem client for `getLogs` and `readContract` |

---

## On-Chain Event Indexing

The `/users` and `/liquidate` pages discover all protocol participants by reading `CollateralDeposited` events directly from the chain — no backend, no subgraph, no indexer.

### Why Paginated?

Sepolia RPC providers (including Thirdweb's public endpoint) limit `eth_getLogs` to a **10,000 block range** per request. The app works around this by:

1. Splitting the range `[DEPLOY_BLOCK, latestBlock]` into 9,000-block chunks
2. Fetching 5 chunks in parallel via `Promise.allSettled`
3. Collecting unique user addresses across all chunks

### Performance

With `DEPLOY_BLOCK` set correctly (close to actual deployment):

- Typical scan: 1–5 chunks (under 50,000 blocks since deployment)
- Load time: 1–3 seconds

With `DEPLOY_BLOCK = 0n`:

- Sepolia is ~8M+ blocks deep → ~900 chunks → minutes to load

**Always set `DEPLOY_BLOCK` accurately.**

---

## Theme System

The app supports dark and light themes, toggled via the sun/moon button in the navbar.

- Default: dark (`#080808` background, `#C9A96E` gold accent)
- Light: warm off-white (`#FAF8F4` background, `#8B6914` amber accent)
- Preference is persisted in `localStorage` under the key `sf-theme`
- Theme is applied via `data-theme` attribute on `<html>` and CSS custom properties

All colors are defined as CSS variables in `app/globals.css` under `[data-theme='dark']` and `[data-theme='light']` selectors.

### Typography

| Role    | Font               | Usage                                  |
| ------- | ------------------ | -------------------------------------- |
| Display | Cormorant Garamond | Page titles, large numbers, hero text  |
| Body    | Syne               | Labels, buttons, navigation, body copy |
| Mono    | DM Mono            | Addresses, amounts, transaction data   |

---

## Project Structure

```
stableforge-frontend/
├── app/
│   ├── globals.css          Design tokens, CSS variables, utility classes
│   ├── layout.tsx           Root layout (ThemeProvider → Providers → Navbar)
│   ├── page.tsx             Landing page
│   ├── dashboard/
│   │   └── page.tsx
│   ├── deposit/
│   │   └── page.tsx
│   ├── mint/
│   │   └── page.tsx
│   ├── burn/
│   │   └── page.tsx
│   ├── redeem/
│   │   └── page.tsx
│   ├── liquidate/
│   │   └── page.tsx
│   └── users/
│       └── page.tsx
├── components/
│   ├── HealthFactorBadge.tsx
│   ├── Navbar.tsx
│   ├── PageHeader.tsx
│   ├── Providers.tsx
│   ├── ThemeProvider.tsx
│   └── TxStatus.tsx
├── lib/
│   ├── contracts.ts         ABIs + addresses
│   ├── fetchLogs.ts         Paginated event indexer
│   ├── utils.ts             Format helpers
│   └── wagmi.ts             Chain config
├── public/                  Static assets
├── next.config.ts           Turbopack + webpack fallbacks for web3 libs
├── tsconfig.json            target: ES2020 (required for BigInt literals)
└── package.json
```

---

## Environment Variables

This app does **not** require a `.env` file to run locally. The only external dependency is the WalletConnect Project ID, which is configured directly in `lib/wagmi.ts`.

If you want to use a custom RPC URL (e.g. Alchemy or Infura instead of the default public Sepolia endpoint), you can configure it in `lib/wagmi.ts`:

```ts
import { http } from "wagmi";

export const wagmiConfig = getDefaultConfig({
  appName: "StableForge",
  projectId: "YOUR_PROJECT_ID",
  chains: [sepolia],
  transports: {
    [sepolia.id]: http("https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY"),
  },
  ssr: true,
});
```

Using a dedicated RPC key significantly improves load speed on the `/users` and `/liquidate` pages.

---

## Deployment

### Vercel (recommended)

```bash
npm install -g vercel
vercel
```

The app is fully static-export compatible — all data is fetched client-side. No server-side environment variables are needed.

### Manual

```bash
npm run build
npm run start   # serves on port 3000
```

Or export as static HTML:

```bash
# Add to next.config.ts: output: 'export'
npm run build
# Output in /out directory
```

---

## Known Limitations

| Limitation                                         | Detail                                                                                                                                 |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| **Sepolia only**                                   | The app is hardcoded to Sepolia. Connecting on mainnet will show a "wrong network" prompt from RainbowKit.                             |
| **No real-time liquidation alerts**                | Health factor is polled every 10s on the dashboard, not pushed. For high-risk positions, monitor manually.                             |
| **Event indexing requires correct `DEPLOY_BLOCK`** | If `/users` is slow or empty, this is why. See [Configuration](#configuration).                                                        |
| **Public RPC rate limits**                         | The default Thirdweb Sepolia endpoint can rate-limit heavy `getLogs` usage. Use a dedicated Alchemy/Infura key for better performance. |
| **WalletConnect on localhost**                     | Some WalletConnect wallets block `localhost` origins. Use MetaMask (injected) for local development.                                   |
| **React 19 peer warnings**                         | RainbowKit/valtio dependency tree warns about React 19 compatibility. These are warnings only and do not affect functionality.         |

---

## Contract Addresses (Sepolia)

| Contract              | Address                                      |
| --------------------- | -------------------------------------------- |
| SFCEngine             | `0xb3aaed6233f01d0b77ec265a7bdfce83e71bf9f1` |
| StableForgeCoin (SFC) | `0x98b1383944e6058643183a842578c4df0d096245` |
| WETH (collateral)     | `0xdd13E55209Fd76AfE204dBda4007C227904f0a81` |
| WBTC (collateral)     | `0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063` |
| ETH/USD Price Feed    | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| BTC/USD Price Feed    | `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43` |

---

_Part of the [StableForge Protocol](https://github.com/1khushibarnwal/StableForge) — built by [Khushi Barnwal](https://github.com/1khushibarnwal)_
