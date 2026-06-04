'use client';

import Link from 'next/link';
import { ArrowRight, Shield, Zap, TrendingUp, Lock } from 'lucide-react';

const FEATURES = [
  { icon: Shield, title: 'Overcollateralized', desc: '200% collateral ratio ensures the protocol stays solvent at all times.' },
  { icon: Zap, title: 'Instant Minting', desc: 'Deposit WETH or WBTC and mint SFC stablecoins in a single transaction.' },
  { icon: TrendingUp, title: 'Chainlink Oracles', desc: 'Real-time price feeds for accurate collateral valuation and liquidations.' },
  { icon: Lock, title: 'Liquidation Engine', desc: '10% bonus incentivizes liquidators to keep the protocol healthy.' },
];

export default function HomePage() {
  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '0 24px' }}>
      {/* Hero */}
      <section style={{
        paddingTop: '100px',
        paddingBottom: '80px',
        position: 'relative',
      }}>
        {/* Background decoration */}
        <div style={{
          position: 'absolute', top: '10%', right: '0',
          width: '500px', height: '500px',
          background: 'radial-gradient(circle, var(--accent-glow) 0%, transparent 70%)',
          pointerEvents: 'none',
          zIndex: 0,
        }} />

        <div style={{ position: 'relative', zIndex: 1, maxWidth: '700px' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: '8px',
            background: 'var(--accent-dim)', border: '1px solid var(--border-strong)',
            borderRadius: '20px', padding: '5px 14px', marginBottom: '32px',
          }}>
            <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--safe)', boxShadow: '0 0 6px var(--safe)' }} />
            <span style={{ fontSize: '12px', fontWeight: 600, color: 'var(--accent)', letterSpacing: '0.06em', textTransform: 'uppercase', fontFamily: 'var(--font-mono)' }}>
              Live on Sepolia Testnet
            </span>
          </div>

          <h1 style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(52px, 7vw, 88px)',
            fontWeight: 300,
            lineHeight: 1.0,
            color: 'var(--text-primary)',
            marginBottom: '8px',
            letterSpacing: '-0.02em',
          }}>
            Forge Stable
          </h1>
          <h1 style={{
            fontFamily: 'var(--font-display)',
            fontSize: 'clamp(52px, 7vw, 88px)',
            fontWeight: 300,
            lineHeight: 1.0,
            color: 'var(--accent)',
            marginBottom: '32px',
            letterSpacing: '-0.02em',
            fontStyle: 'italic',
          }}>
            Value On-Chain
          </h1>

          <p style={{
            fontSize: '17px',
            color: 'var(--text-secondary)',
            lineHeight: 1.7,
            marginBottom: '40px',
            maxWidth: '520px',
          }}>
            Deposit WETH or WBTC as collateral and mint <strong style={{ color: 'var(--text-primary)' }}>SFC</strong> — a USD-pegged stablecoin secured by overcollateralization, Chainlink price feeds, and an on-chain liquidation engine.
          </p>

          {/* Buttons — no longer overlapping */}
          <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', marginBottom: '56px' }}>
            <Link href="/deposit" style={{ textDecoration: 'none' }}>
              <button className="btn-primary" style={{ fontSize: '14px', padding: '13px 28px' }}>
                Start Minting <ArrowRight size={15} />
              </button>
            </Link>
            <Link href="/dashboard" style={{ textDecoration: 'none' }}>
              <button className="btn-secondary" style={{ fontSize: '14px', padding: '12px 28px' }}>
                View Dashboard
              </button>
            </Link>
            <Link href="/users" style={{ textDecoration: 'none' }}>
              <button className="btn-ghost" style={{ fontSize: '14px', padding: '12px 28px' }}>
                All Positions
              </button>
            </Link>
          </div>
        </div>

        {/* Stats row — flows naturally BELOW the buttons */}
        <div style={{
          display: 'flex', gap: '1px',
          background: 'var(--border)',
          borderRadius: '12px',
          overflow: 'hidden',
          border: '1px solid var(--border)',
        }}>
          {[
            { label: 'Collateral Ratio', value: '200%' },
            { label: 'Liquidation Bonus', value: '10%' },
            { label: 'Accepted Collateral', value: 'WETH · WBTC' },
            { label: 'Network', value: 'Sepolia' },
          ].map((stat, i) => (
            <div key={i} style={{
              flex: 1, padding: '16px 20px',
              background: 'var(--bg-card)',
              display: 'flex', flexDirection: 'column', gap: '4px',
            }}>
              <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                {stat.label}
              </div>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: '22px', fontWeight: 400, color: 'var(--text-primary)' }}>
                {stat.value}
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Features */}
      <section style={{ paddingBottom: '100px' }}>
        <div style={{ marginBottom: '48px' }}>
          <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '12px', fontFamily: 'var(--font-mono)' }}>
            Protocol Design
          </div>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '42px', fontWeight: 300, color: 'var(--text-primary)' }}>
            Built for Solvency
          </h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
          {FEATURES.map(({ icon: Icon, title, desc }) => (
            <div key={title} className="card" style={{ padding: '28px' }}>
              <div style={{
                width: 40, height: 40,
                background: 'var(--accent-dim)',
                borderRadius: '10px',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                marginBottom: '16px',
              }}>
                <Icon size={18} color="var(--accent)" strokeWidth={1.5} />
              </div>
              <h3 style={{ fontSize: '16px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>
                {title}
              </h3>
              <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
                {desc}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* How it works */}
      <section style={{ paddingBottom: '100px' }}>
        <div style={{ marginBottom: '40px' }}>
          <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '12px', fontFamily: 'var(--font-mono)' }}>
            How It Works
          </div>
          <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '42px', fontWeight: 300, color: 'var(--text-primary)' }}>
            Three Simple Steps
          </h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px', position: 'relative' }}>
          {[
            { step: '01', title: 'Deposit Collateral', desc: 'Approve and deposit WETH or WBTC into the SFCEngine contract.' },
            { step: '02', title: 'Mint SFC', desc: 'Mint up to 50% of your collateral value as SFC stablecoins.' },
            { step: '03', title: 'Manage Position', desc: 'Monitor health factor, redeem collateral, or burn SFC to stay safe.' },
          ].map(({ step, title, desc }) => (
            <div key={step} className="card" style={{ padding: '32px 28px', position: 'relative', overflow: 'hidden' }}>
              <div style={{
                position: 'absolute', top: 16, right: 20,
                fontFamily: 'var(--font-display)', fontSize: '64px', fontWeight: 700,
                color: 'var(--border)', lineHeight: 1, userSelect: 'none',
              }}>
                {step}
              </div>
              <div style={{ position: 'relative' }}>
                <h3 style={{ fontSize: '17px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '10px', marginTop: '8px' }}>
                  {title}
                </h3>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', lineHeight: 1.6 }}>
                  {desc}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section style={{ paddingBottom: '100px' }}>
        <div className="card" style={{
          padding: '64px',
          background: 'var(--bg-card)',
          position: 'relative',
          overflow: 'hidden',
          textAlign: 'center',
        }}>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'radial-gradient(ellipse at center, var(--accent-glow) 0%, transparent 60%)',
            pointerEvents: 'none',
          }} />
          <div style={{ position: 'relative' }}>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: '52px', fontWeight: 300, color: 'var(--text-primary)', marginBottom: '16px' }}>
              Ready to mint?
            </h2>
            <p style={{ fontSize: '15px', color: 'var(--text-secondary)', marginBottom: '32px' }}>
              Connect your wallet and start forging stable value on Sepolia.
            </p>
            <Link href="/deposit" style={{ textDecoration: 'none' }}>
              <button className="btn-primary" style={{ fontSize: '14px', padding: '14px 32px' }}>
                Get Started <ArrowRight size={15} />
              </button>
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
