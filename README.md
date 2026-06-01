<h1 align="center">
⚒️ StableForge
</h1>

<h3 align="center">
A Decentralized Overcollateralized Stablecoin Protocol Built with Solidity & Foundry
</h3>

<p align="center">
Mint a USD-pegged stablecoin backed by crypto collateral with transparent on-chain solvency.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Solidity-0.8.24-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Foundry-Framework-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Chainlink-Oracle-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

---

# 📖 About The Project

StableForge is a decentralized stablecoin protocol that allows users to deposit collateral assets and mint a USD-pegged stablecoin.

The system is designed around overcollateralization, oracle-based pricing, health factor monitoring, and liquidation mechanisms to maintain protocol solvency.

Inspired by battle-tested DeFi systems like MakerDAO, StableForge focuses on security, transparency, and decentralized stablecoin issuance.

---

# ✨ Features

✅ Overcollateralized Stablecoin System

✅ Chainlink Price Feed Integration

✅ Decentralized Minting & Burning

✅ Health Factor Protection

✅ Liquidation Engine

✅ Multi-Collateral Architecture

✅ Foundry Testing Suite

✅ Gas Optimized Solidity Contracts

---

# 🏗️ Protocol Architecture

```text
                ┌──────────────────┐
                │      User        │
                └────────┬─────────┘
                         │
                         ▼
             Deposit Collateral
                         │
                         ▼
        ┌──────────────────────────┐
        │     StableForgeEngine    │
        └──────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          ▼                             ▼

 Mint StableCoin             Redeem Collateral

          ▼                             ▼

  StableForgeToken           Burn StableCoin

          │
          ▼

 Health Factor Monitoring

          │
          ▼

 Liquidation If Undercollateralized
```

---

# ⚙️ Tech Stack

| Technology     | Usage                 |
| -------------- | --------------------- |
| Solidity       | Smart Contracts       |
| Foundry        | Development Framework |
| Chainlink      | Price Oracles         |
| OpenZeppelin   | Security Standards    |
| GitHub Actions | CI/CD                 |

---

# 📂 Project Structure

```bash
StableForge
│
├── src
│   ├── StableForgeEngine.sol
│   ├── StableForgeToken.sol
│
├── script
│   ├── DeployStableForge.s.sol
│
├── test
│   ├── unit
│   ├── fuzz
│   ├── invariant
│
├── lib
│
└── README.md
```

---

# 🚀 Getting Started

## Prerequisites

Make sure you have installed:

- Git
- Foundry

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## Clone Repository

```bash
git clone https://github.com/1khushibarnwal/StableForge.git
```

```bash
cd StableForge
```

---

## Install Dependencies

```bash
forge install
```

---

## Build

```bash
forge build
```

---

## Test

```bash
forge test
```

---

## Coverage

```bash
forge coverage
```

---

# 🔒 Security Model

StableForge maintains solvency through:

- Overcollateralization
- Oracle-backed asset pricing
- Health factor calculations
- Liquidation incentives
- Restricted minting logic

Every minted stablecoin must remain backed by sufficient collateral value.

---

# 📊 Health Factor

```text
HF > 1  → Healthy Position

HF = 1  → Liquidation Threshold

HF < 1  → Eligible For Liquidation
```

---

# 🧪 Testing

The protocol includes:

- Unit Tests
- Fuzz Tests
- Invariant Tests

Run all tests:

```bash
forge test -vvv
```

Run invariant tests:

```bash
forge test --match-path test/invariant/*
```

---

# 🛣️ Roadmap

- [x] Stablecoin Minting
- [x] Collateral Deposits
- [x] Redemption Logic
- [x] Liquidation Mechanism
- [x] Health Factor Enforcement
- [ ] Governance Module
- [ ] Cross-Chain Support
- [ ] Yield Bearing Collateral
- [ ] DAO Treasury
- [ ] Dynamic Stability Fees

---

# 🤝 Contributing

Contributions, issues, and feature requests are welcome.

```bash
Fork → Branch → Commit → Pull Request
```

---

# 📜 License

Distributed under the MIT License.

---

# 👨‍💻 Authors

### Khushi Barnwal

- GitHub: https://github.com/1khushibarnwal

---

# ⚠️ Disclaimer

This project is built for educational and research purposes.

Do not use in production environments without professional audits and extensive security reviews.

---

<p align="center">
Built with ❤️ using Solidity, Foundry and Chainlink
</p>
