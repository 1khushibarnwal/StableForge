# DecentralizedStableCoin (DSC)

A **decentralized, crypto-collateralized stablecoin protocol** built using **Solidity** and **Foundry**.

This project is inspired by systems like MakerDAO (DAI) and demonstrates how a decentralized stablecoin can be designed using smart contracts, over-collateralization, and on-chain price feeds.

---

## 📌 What is DSC?

**DecentralizedStableCoin (DSC)** is a stablecoin protocol that allows users to:

- Deposit crypto collateral (e.g., wETH, wBTC)
- Mint a USD-pegged stablecoin against that collateral
- Burn stablecoins to unlock collateral
- Maintain protocol solvency via over-collateralization and liquidation logic

The system is designed to be:

- **Decentralized**
- **Transparent**
- **Non-custodial**
- **Permissionless**

---

## ✨ Features

- 🪙 ERC20-based stablecoin (DSC)
- 🔒 Crypto-collateralized (no fiat backing)
- 📉 Over-collateralization to protect the peg
- 🔥 Mint & burn functionality controlled by the engine
- ⚖️ Health factor checks to prevent under-collateralized positions
- 🧪 Extensive unit, fuzz, and invariant tests
- 🛠 Built with Foundry for fast testing and debugging

---

## 🧱 Architecture Overview

User \
└── deposits collateral \
└── DSC Engine \
├── tracks collateral value \
├── calculates health factor \
├── mints / burns DSC \
└── handles liquidation \
└── DecentralizedStableCoin (ERC20)

---

## 📂 Project Structure

├── src/ \
│ ├── DecentralizedStableCoin.sol \
│ ├── DSCEngine.sol \
│ └── libraries/ \
├── test/ \
│ ├── unit/ \
│ ├── fuzz/ \
│ └── invariant/ \
├── script/ \
│ └── DeployDSC.s.sol \
├── lib/ \
├── foundry.toml \
├── Makefile \
└── README.md

---

## 🧱 Tech Stack

| Layer           | Technology                                               |
| --------------- | -------------------------------------------------------- |
| Smart Contracts | Solidity ^0.8.x                                          |
| Framework       | Foundry (Forge, Anvil, Cast)                             |
| Randomness      | Chainlink VRF (or mock implementation for local testing) |
| Testing         | Forge test suite                                         |
| Tooling         | Git, Makefile                                            |
| Network Support | Localhost, Ethereum Testnets                             |

---

## ⚙️ Installation

### Prerequisites

- Foundry installed
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

---

## 📥 Clone the Repository

```bash
git clone https://github.com/1khushibarnwal/DecentralizedStableCoin.git
cd DecentralizedStableCoin
```

## 📦 Install Dependencies

```bash
forge install
```

## 🧪 Running Tests

### All tests

```bash
forge test
```

### Run with verbose output

```bash
forge test -vvvv
```

### Run invariant tests only

```bash
forge test --mt invariant
```

---

## 🧰 Makefile

This project includes a `Makefile` to simplify common development workflows by wrapping frequently used Foundry commands into short, memorable targets.

Using the Makefile helps ensure:

- Consistent command usage
- Faster development workflows
- Fewer mistakes when running complex commands

### Common Makefile Commands

Run all tests:

```bash
make test
```

Run invariant tests:

```bash
make invariant
```

And many more! \
💡 Tip: Run make or make help to see all available commands defined in the Makefile.

## 🚀 Deployment

Deploy locally or to a testnet using Foundry scripts:

```bash
forge script script/DeployDSC.s.sol \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

Your .env file must have an RPC_URL and a PRIVATE_KEY in order to deploy it.

## 🔐 Security Notes

- This project is not audited

- Intended for learning and experimentation

- Do NOT use in production without a full security audit

## 📚 Learning Goals of This Project

- Stablecoin design patterns

- Over-collateralization mechanics

- Health factor calculations

- Liquidation logic

- Fuzz testing and invariant testing

- Writing secure and testable smart contracts

## 📄 License

This project is licensed under the MIT License.
