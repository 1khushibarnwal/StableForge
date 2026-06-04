'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useTheme } from './ThemeProvider';
import { Sun, Moon, Anvil } from 'lucide-react';
import { useState } from 'react';

const NAV_LINKS = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/deposit', label: 'Deposit' },
  { href: '/mint', label: 'Mint' },
  { href: '/burn', label: 'Burn' },
  { href: '/redeem', label: 'Redeem' },
  { href: '/liquidate', label: 'Liquidate' },
  { href: '/users', label: 'All Users' },
];

export function Navbar() {
  const pathname = usePathname();
  const { theme, toggleTheme } = useTheme();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <header style={{
      position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
      height: '64px',
      background: 'var(--bg-primary)',
      borderBottom: '1px solid var(--border)',
      backdropFilter: 'blur(12px)',
    }}>
      <div style={{
        maxWidth: '1280px', margin: '0 auto',
        height: '100%', padding: '0 24px',
        display: 'flex', alignItems: 'center', gap: '32px',
      }}>
        {/* Logo */}
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: '10px', textDecoration: 'none', flexShrink: 0 }}>
          <div style={{
            width: 32, height: 32,
            background: 'var(--accent)',
            borderRadius: '8px',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Anvil size={16} color="var(--bg-primary)" strokeWidth={2.5} />
          </div>
          <span style={{
            fontFamily: 'var(--font-display)',
            fontSize: '20px',
            fontWeight: 600,
            color: 'var(--text-primary)',
            letterSpacing: '0.02em',
          }}>
            StableForge
          </span>
        </Link>

        {/* Nav links */}
        <nav style={{ display: 'flex', alignItems: 'center', gap: '4px', flex: 1 }}>
          {NAV_LINKS.map(({ href, label }) => {
            const active = pathname === href;
            return (
              <Link key={href} href={href} style={{
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '13px',
                fontWeight: active ? 600 : 400,
                color: active ? 'var(--accent)' : 'var(--text-secondary)',
                background: active ? 'var(--accent-dim)' : 'transparent',
                textDecoration: 'none',
                transition: 'all 0.15s ease',
                letterSpacing: '0.01em',
                whiteSpace: 'nowrap',
              }}
              onMouseEnter={e => { if (!active) (e.target as HTMLElement).style.color = 'var(--text-primary)'; }}
              onMouseLeave={e => { if (!active) (e.target as HTMLElement).style.color = 'var(--text-secondary)'; }}
              >
                {label}
              </Link>
            );
          })}
        </nav>

        {/* Right side */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexShrink: 0 }}>
          <button
            onClick={toggleTheme}
            className="btn-ghost"
            style={{ padding: '8px', borderRadius: '8px' }}
            aria-label="Toggle theme"
          >
            {theme === 'dark'
              ? <Sun size={15} strokeWidth={2} />
              : <Moon size={15} strokeWidth={2} />
            }
          </button>
          <ConnectButton
            showBalance={false}
            chainStatus="icon"
            accountStatus="avatar"
          />
        </div>
      </div>
    </header>
  );
}
