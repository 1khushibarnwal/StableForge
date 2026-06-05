"use client";

import Link from "next/link";
import { ArrowRight, ExternalLink } from "lucide-react";
import { FaGithub } from "react-icons/fa";

function Tag({ children }: { children: string }) {
  return (
    <span
      style={{
        display: "inline-block",
        background: "var(--accent-dim)",
        color: "var(--accent)",
        border: "1px solid var(--border-strong)",
        borderRadius: "20px",
        padding: "3px 10px",
        fontSize: "11px",
        fontWeight: 600,
        letterSpacing: "0.05em",
        textTransform: "uppercase",
        fontFamily: "var(--font-mono)",
      }}
    >
      {children}
    </span>
  );
}

export default function AboutPage() {
  return (
    <div
      style={{
        maxWidth: "1280px",
        margin: "0 auto",
        padding: "60px 24px 100px",
      }}
    >
      {/* Hero */}
      <div style={{ maxWidth: "720px", marginBottom: "80px" }}>
        <div
          style={{
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: "16px",
            fontFamily: "var(--font-mono)",
          }}
        >
          About StableForge
        </div>
        <h1
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(40px, 5vw, 64px)",
            fontWeight: 300,
            lineHeight: 1.05,
            color: "var(--text-primary)",
            marginBottom: "24px",
            letterSpacing: "-0.02em",
          }}
        >
          Built to understand DeFi
          <br />
          <span style={{ color: "var(--accent)", fontStyle: "italic" }}>
            from first principles.
          </span>
        </h1>
        <p
          style={{
            fontSize: "16px",
            color: "var(--text-secondary)",
            lineHeight: 1.8,
            maxWidth: "600px",
          }}
        >
          StableForge started as a deep-dive into how MakerDAO actually works
          under the hood — not just the UI, but the collateral math, the oracle
          design, the liquidation incentives, and the health factor invariants.
          What came out was a working, fully deployed protocol.
        </p>
      </div>

      {/* Origin story */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1fr",
          gap: "48px",
          marginBottom: "80px",
          alignItems: "start",
        }}
      >
        <div>
          <div
            style={{
              fontSize: "11px",
              fontWeight: 600,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              color: "var(--text-muted)",
              marginBottom: "12px",
              fontFamily: "var(--font-mono)",
            }}
          >
            The Problem
          </div>
          <h2
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "34px",
              fontWeight: 300,
              color: "var(--text-primary)",
              marginBottom: "16px",
              lineHeight: 1.1,
            }}
          >
            Most DeFi education stops at the surface
          </h2>
          <p
            style={{
              fontSize: "14px",
              color: "var(--text-secondary)",
              lineHeight: 1.8,
              marginBottom: "14px",
            }}
          >
            There are plenty of tutorials that walk you through <em>using</em> a
            stablecoin protocol. Very few explain why the 200% collateral ratio
            exists, how health factor math actually prevents insolvency, or why
            liquidation bonuses need to be calibrated correctly.
          </p>
          <p
            style={{
              fontSize: "14px",
              color: "var(--text-secondary)",
              lineHeight: 1.8,
            }}
          >
            StableForge was built to answer those questions by implementing them
            — every invariant, every edge case, every oracle validation — from
            scratch in Solidity, then building a full frontend on top.
          </p>
        </div>

        <div>
          <div
            style={{
              fontSize: "11px",
              fontWeight: 600,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              color: "var(--text-muted)",
              marginBottom: "12px",
              fontFamily: "var(--font-mono)",
            }}
          >
            The Approach
          </div>
          <h2
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "34px",
              fontWeight: 300,
              color: "var(--text-primary)",
              marginBottom: "16px",
              lineHeight: 1.1,
            }}
          >
            Minimal, honest, and fully on-chain
          </h2>
          <p
            style={{
              fontSize: "14px",
              color: "var(--text-secondary)",
              lineHeight: 1.8,
              marginBottom: "14px",
            }}
          >
            The contracts have no owner, no governance, no upgrade proxy, no fee
            switch, no admin backdoor. Every feature that was added had to
            justify its complexity. Everything that didn't survived the cut.
          </p>
          <p
            style={{
              fontSize: "14px",
              color: "var(--text-secondary)",
              lineHeight: 1.8,
            }}
          >
            The result is a protocol you can read in an afternoon and fully
            understand — while still being mechanically sound enough to run a
            real liquidation engine on Sepolia.
          </p>
        </div>
      </div>

      {/* Design principles */}
      <div style={{ marginBottom: "80px" }}>
        <div
          style={{
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: "12px",
            fontFamily: "var(--font-mono)",
          }}
        >
          Design Principles
        </div>
        <h2
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "38px",
            fontWeight: 300,
            color: "var(--text-primary)",
            marginBottom: "32px",
          }}
        >
          What StableForge is built on
        </h2>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(3, 1fr)",
            gap: "16px",
          }}
        >
          {[
            {
              num: "01",
              title: "Solvency over convenience",
              body: "Every design decision prioritizes keeping the protocol solvent. The 200% collateral ratio, the oracle stale-price halt, the liquidation health-factor check — all of these will block user actions if the alternative is a less solvent protocol.",
            },
            {
              num: "02",
              title: "No hidden complexity",
              body: "The entire system is two contracts and one library. No proxy pattern, no diamond pattern, no timelocked governance. If you can read Solidity, you can read the entire protocol in 30 minutes and know exactly what it does.",
            },
            {
              num: "03",
              title: "Incentives over enforcement",
              body: "The protocol doesn't need an admin to force liquidations — it pays liquidators 10% to do it voluntarily. It doesn't need a central issuer to maintain the peg — it relies on arbitrage and collateral math.",
            },
            {
              num: "04",
              title: "Fail loudly",
              body: "Every error condition in the protocol is a named custom error. Nothing fails silently with a boolean return. If something is wrong — bad oracle data, broken health factor, disallowed token — the contract reverts with a specific, debuggable error.",
            },
            {
              num: "05",
              title: "Oracle-first security",
              body: "A stablecoin protocol is only as trustworthy as its price data. StableForge validates every Chainlink read for staleness, round completeness, and sign — and halts all price-dependent operations if any check fails.",
            },
            {
              num: "06",
              title: "CEI, always",
              body: "Every external interaction follows Checks → Effects → Interactions. State is mutated before external calls are made. Combined with ReentrancyGuard, this makes the attack surface for reentrancy essentially zero.",
            },
          ].map(({ num, title, body }) => (
            <div
              key={num}
              className="card"
              style={{
                padding: "28px",
                position: "relative",
                overflow: "hidden",
              }}
            >
              <div
                style={{
                  position: "absolute",
                  top: 12,
                  right: 16,
                  fontFamily: "var(--font-display)",
                  fontSize: "52px",
                  fontWeight: 700,
                  color: "var(--border)",
                  lineHeight: 1,
                  userSelect: "none",
                }}
              >
                {num}
              </div>
              <h3
                style={{
                  fontSize: "15px",
                  fontWeight: 600,
                  color: "var(--text-primary)",
                  marginBottom: "10px",
                  marginTop: "8px",
                  position: "relative",
                }}
              >
                {title}
              </h3>
              <p
                style={{
                  fontSize: "13px",
                  color: "var(--text-secondary)",
                  lineHeight: 1.7,
                  position: "relative",
                }}
              >
                {body}
              </p>
            </div>
          ))}
        </div>
      </div>

      {/* Tech stack */}
      <div style={{ marginBottom: "80px" }}>
        <div
          style={{
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: "12px",
            fontFamily: "var(--font-mono)",
          }}
        >
          Technical Stack
        </div>
        <h2
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "38px",
            fontWeight: 300,
            color: "var(--text-primary)",
            marginBottom: "32px",
          }}
        >
          What it's built with
        </h2>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(2, 1fr)",
            gap: "16px",
          }}
        >
          {[
            {
              layer: "Smart Contracts",
              items: [
                "Solidity ^0.8.18",
                "Foundry (forge, cast, anvil)",
                "OpenZeppelin ReentrancyGuard, IERC20, ERC20Burnable, Ownable",
                "Chainlink AggregatorV3Interface",
              ],
              tags: ["Solidity", "Foundry", "OpenZeppelin"],
            },
            {
              layer: "Frontend",
              items: [
                "Next.js 15 (App Router)",
                "Wagmi v2 + Viem",
                "RainbowKit",
                "TanStack Query v5",
                "Tailwind CSS v4",
                "TypeScript",
              ],
              tags: ["Next.js", "Wagmi", "Viem", "RainbowKit"],
            },
            {
              layer: "Infrastructure",
              items: [
                "Ethereum Sepolia Testnet",
                "Chainlink ETH/USD + BTC/USD price feeds",
                "Thirdweb public Sepolia RPC",
                "Vercel for frontend hosting",
              ],
              tags: ["Sepolia", "Chainlink", "Vercel"],
            },
            {
              layer: "Testing",
              items: [
                "Foundry unit tests",
                "Fuzz testing with forge",
                "Invariant tests (WIP)",
                "forge coverage for coverage reports",
              ],
              tags: ["Foundry", "Fuzz", "Invariant"],
            },
          ].map(({ layer, items, tags }) => (
            <div key={layer} className="card" style={{ padding: "24px" }}>
              <div
                style={{
                  fontSize: "12px",
                  fontWeight: 600,
                  letterSpacing: "0.06em",
                  textTransform: "uppercase",
                  color: "var(--text-muted)",
                  marginBottom: "12px",
                }}
              >
                {layer}
              </div>
              <ul
                style={{ listStyle: "none", padding: 0, marginBottom: "14px" }}
              >
                {items.map((item) => (
                  <li
                    key={item}
                    style={{
                      fontSize: "13px",
                      color: "var(--text-secondary)",
                      padding: "4px 0",
                      borderBottom: "1px solid var(--border)",
                      display: "flex",
                      alignItems: "center",
                      gap: "8px",
                    }}
                  >
                    <span style={{ color: "var(--accent)", fontSize: "8px" }}>
                      ●
                    </span>
                    {item}
                  </li>
                ))}
              </ul>
              <div style={{ display: "flex", gap: "6px", flexWrap: "wrap" }}>
                {tags.map((t) => (
                  <Tag key={t}>{t}</Tag>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Timeline */}
      <div style={{ marginBottom: "80px" }}>
        <div
          style={{
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: "12px",
            fontFamily: "var(--font-mono)",
          }}
        >
          Build Timeline
        </div>
        <h2
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "38px",
            fontWeight: 300,
            color: "var(--text-primary)",
            marginBottom: "32px",
          }}
        >
          How it came together
        </h2>

        <div style={{ position: "relative", paddingLeft: "32px" }}>
          <div
            style={{
              position: "absolute",
              left: "7px",
              top: 0,
              bottom: 0,
              width: "1px",
              background: "var(--border)",
            }}
          />
          {[
            {
              phase: "Phase 1",
              title: "Protocol Design",
              desc: "Studied MakerDAO's DSS architecture. Designed the overcollateralization math, health factor formula, and liquidation incentive structure. Wrote the core SFCEngine and StableForgeCoin contracts with full NatSpec documentation.",
              status: "done",
            },
            {
              phase: "Phase 2",
              title: "Testing & Hardening",
              desc: "Wrote unit tests for every function — deposits, mints, burns, redeems, liquidations, oracle edge cases. Added the OracleLib stale-price guard. Iterated on the CEI pattern and reentrancy protection.",
              status: "done",
            },
            {
              phase: "Phase 3",
              title: "Sepolia Deployment",
              desc: "Deployed SFCEngine and StableForgeCoin to Ethereum Sepolia. Verified contracts on Etherscan. Renamed everything from DSC to SFC for the StableForge brand.",
              status: "done",
            },
            {
              phase: "Phase 4",
              title: "Frontend",
              desc: "Built a full Next.js 15 frontend with Wagmi v2, RainbowKit, and Viem. All 8 pages — landing, dashboard, deposit, mint, burn, redeem, liquidate, and all-users — with dark/light theme, real-time position data, and on-chain event indexing.",
              status: "done",
            },
            {
              phase: "Phase 5",
              title: "Fuzz & Invariant Tests",
              desc: "Adding Foundry invariant tests to formally verify the core protocol invariant: total collateral value ≥ total SFC minted, at all times, under any sequence of operations.",
              status: "wip",
            },
            {
              phase: "Phase 6",
              title: "Security Audit",
              desc: "Formal audit engagement planned before any mainnet deployment.",
              status: "planned",
            },
          ].map(({ phase, title, desc, status }) => {
            const dotColor =
              status === "done"
                ? "var(--safe)"
                : status === "wip"
                  ? "var(--warning)"
                  : "var(--text-muted)";
            const statusLabel =
              status === "done"
                ? "Complete"
                : status === "wip"
                  ? "In Progress"
                  : "Planned";
            return (
              <div
                key={phase}
                style={{ position: "relative", marginBottom: "32px" }}
              >
                <div
                  style={{
                    position: "absolute",
                    left: "-28px",
                    top: "4px",
                    width: 10,
                    height: 10,
                    borderRadius: "50%",
                    background: dotColor,
                    boxShadow:
                      status === "done" ? `0 0 6px ${dotColor}` : "none",
                  }}
                />
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "10px",
                    marginBottom: "6px",
                  }}
                >
                  <span
                    style={{
                      fontSize: "11px",
                      fontWeight: 600,
                      letterSpacing: "0.06em",
                      textTransform: "uppercase",
                      color: "var(--text-muted)",
                      fontFamily: "var(--font-mono)",
                    }}
                  >
                    {phase}
                  </span>
                  <span
                    style={{
                      fontSize: "10px",
                      fontWeight: 600,
                      letterSpacing: "0.05em",
                      textTransform: "uppercase",
                      color: dotColor,
                      background: `${dotColor}18`,
                      border: `1px solid ${dotColor}30`,
                      borderRadius: "10px",
                      padding: "2px 8px",
                    }}
                  >
                    {statusLabel}
                  </span>
                </div>
                <h3
                  style={{
                    fontSize: "16px",
                    fontWeight: 600,
                    color: "var(--text-primary)",
                    marginBottom: "6px",
                  }}
                >
                  {title}
                </h3>
                <p
                  style={{
                    fontSize: "13px",
                    color: "var(--text-secondary)",
                    lineHeight: 1.7,
                  }}
                >
                  {desc}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      {/* Author */}
      <div style={{ marginBottom: "80px" }}>
        <div
          style={{
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "var(--text-muted)",
            marginBottom: "12px",
            fontFamily: "var(--font-mono)",
          }}
        >
          Built by
        </div>
        <div
          className="card"
          style={{
            padding: "32px",
            maxWidth: "540px",
            display: "flex",
            alignItems: "flex-start",
            gap: "24px",
          }}
        >
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: "50%",
              flexShrink: 0,
              background: "var(--accent-dim)",
              border: "2px solid var(--border-strong)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontFamily: "var(--font-display)",
              fontSize: "22px",
              color: "var(--accent)",
            }}
          >
            K
          </div>
          <div style={{ flex: 1 }}>
            <div
              style={{
                fontSize: "18px",
                fontWeight: 600,
                color: "var(--text-primary)",
                marginBottom: "4px",
                fontFamily: "var(--font-display)",
              }}
            >
              Khushi Barnwal
            </div>
            <div
              style={{
                fontSize: "12px",
                color: "var(--text-muted)",
                fontFamily: "var(--font-mono)",
                marginBottom: "12px",
              }}
            >
              Solidity · DeFi · Full-Stack Web3
            </div>
            <p
              style={{
                fontSize: "13px",
                color: "var(--text-secondary)",
                lineHeight: 1.7,
                marginBottom: "16px",
              }}
            >
              Building StableForge to learn DeFi protocol mechanics from first
              principles — not just how to use them, but why they work.
            </p>
            <div style={{ display: "flex", gap: "10px" }}>
              <a
                href="https://github.com/1khushibarnwal"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary"
                style={{
                  fontSize: "12px",
                  padding: "7px 14px",
                  textDecoration: "none",
                }}
              >
                <FaGithub size={13} /> GitHub
              </a>
              <a
                href="https://github.com/1khushibarnwal/StableForge"
                target="_blank"
                rel="noopener noreferrer"
                className="btn-ghost"
                style={{
                  fontSize: "12px",
                  padding: "7px 14px",
                  textDecoration: "none",
                }}
              >
                <ExternalLink size={13} /> Repository
              </a>
            </div>
          </div>
        </div>
      </div>

      {/* CTA */}
      <div
        className="card"
        style={{
          padding: "56px",
          position: "relative",
          overflow: "hidden",
          textAlign: "center",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "radial-gradient(ellipse at center, var(--accent-glow) 0%, transparent 60%)",
            pointerEvents: "none",
          }}
        />
        <div style={{ position: "relative" }}>
          <h2
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "44px",
              fontWeight: 300,
              color: "var(--text-primary)",
              marginBottom: "12px",
            }}
          >
            Ready to explore?
          </h2>
          <p
            style={{
              fontSize: "14px",
              color: "var(--text-secondary)",
              marginBottom: "28px",
              maxWidth: "400px",
              margin: "0 auto 28px",
            }}
          >
            Read the docs to understand how the protocol works, or jump straight
            into the app.
          </p>
          <div
            style={{
              display: "flex",
              gap: "12px",
              justifyContent: "center",
              flexWrap: "wrap",
            }}
          >
            <Link href="/docs" style={{ textDecoration: "none" }}>
              <button className="btn-secondary" style={{ fontSize: "13px" }}>
                Read the Docs <ArrowRight size={13} />
              </button>
            </Link>
            <Link href="/deposit" style={{ textDecoration: "none" }}>
              <button className="btn-primary" style={{ fontSize: "13px" }}>
                Start Using StableForge <ArrowRight size={13} />
              </button>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
