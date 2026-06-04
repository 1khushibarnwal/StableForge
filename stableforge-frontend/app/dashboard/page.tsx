'use client';

import { useAccount, useReadContracts } from 'wagmi';
import { formatUnits } from 'viem';
import Link from 'next/link';
import { ADDRESSES, SFC_ENGINE_ABI, ERC20_ABI, COLLATERAL_TOKENS } from '@/lib/contracts';
import { formatUsd, formatSfc, formatCollateral, formatHealthFactor, getHealthFactorStatus, getLiquidationPrice } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { HealthFactorBadge } from '@/components/HealthFactorBadge';
import { ArrowRight, AlertTriangle } from 'lucide-react';

export default function DashboardPage() {
  const { address, isConnected } = useAccount();

  const { data, isLoading } = useReadContracts({
    contracts: address ? [
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getAccountInformation', args: [address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getHealthFactor', args: [address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [address, ADDRESSES.WETH] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [address, ADDRESSES.WBTC] },
      { address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'balanceOf', args: [address] },
    ] : [],
    query: { enabled: !!address, refetchInterval: 10000 },
  });

  if (!isConnected) {
    return (
      <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '60px 24px', textAlign: 'center' }}>
        <div className="card" style={{ padding: '60px', maxWidth: '440px', margin: '0 auto' }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '32px', fontWeight: 300, marginBottom: '12px' }}>
            Connect Wallet
          </div>
          <p style={{ color: 'var(--text-secondary)', marginBottom: '24px', fontSize: '14px' }}>
            Connect your wallet to view your StableForge position.
          </p>
        </div>
      </div>
    );
  }

  const accountInfo = data?.[0]?.result as [bigint, bigint] | undefined;
  const healthFactor = data?.[1]?.result as bigint | undefined;
  const wethBalance = data?.[2]?.result as bigint | undefined;
  const wbtcBalance = data?.[3]?.result as bigint | undefined;
  const sfcBalance = data?.[4]?.result as bigint | undefined;

  const totalDscMinted = accountInfo?.[0] ?? 0n;
  const collateralValueInUsd = accountInfo?.[1] ?? 0n;
  const hf = healthFactor ?? 0n;
  const hfStatus = getHealthFactorStatus(hf);

  const maxMintable = collateralValueInUsd > 0n ? (collateralValueInUsd / 2n) - totalDscMinted : 0n;
  const utilizationRate = collateralValueInUsd > 0n
    ? Number((totalDscMinted * 10000n) / collateralValueInUsd) / 100
    : 0;

  const wethUsd = wethBalance !== undefined
    ? parseFloat(formatUnits(wethBalance, 18))
    : 0;
  const wbtcUsd = wbtcBalance !== undefined
    ? parseFloat(formatUnits(wbtcBalance, 8))
    : 0;

  const shimmerBlock = (w: string, h: string) => (
    <div className="shimmer" style={{ width: w, height: h }} />
  );

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '40px 24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
        <PageHeader
          tag="My Position"
          title="Dashboard"
          subtitle="Monitor your collateral, SFC minted, and health factor in real time."
        />
        {hfStatus === 'danger' && (
          <div className="alert alert-error" style={{ maxWidth: '300px' }}>
            <AlertTriangle size={15} style={{ flexShrink: 0 }} />
            <span style={{ fontSize: '12px' }}>Health factor below 1. You may be liquidated!</span>
          </div>
        )}
        {hfStatus === 'warning' && (
          <div className="alert alert-warning" style={{ maxWidth: '300px' }}>
            <AlertTriangle size={15} style={{ flexShrink: 0 }} />
            <span style={{ fontSize: '12px' }}>Health factor below 1.5. Consider adding collateral.</span>
          </div>
        )}
      </div>

      {/* Stats grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '24px' }}>
        {[
          {
            label: 'Collateral Value',
            value: isLoading ? shimmerBlock('120px', '32px') : formatUsd(collateralValueInUsd),
            sub: 'Total USD value',
          },
          {
            label: 'SFC Minted',
            value: isLoading ? shimmerBlock('120px', '32px') : `${formatSfc(totalDscMinted)} SFC`,
            sub: 'Outstanding debt',
          },
          {
            label: 'Health Factor',
            value: isLoading ? shimmerBlock('80px', '32px') : formatHealthFactor(hf),
            sub: hfStatus === 'infinite' ? 'No debt' : hfStatus === 'safe' ? 'Safe' : hfStatus === 'warning' ? 'Warning' : 'Danger!',
            valueColor: hfStatus === 'safe' || hfStatus === 'infinite' ? 'var(--safe)' : hfStatus === 'warning' ? 'var(--warning)' : 'var(--danger)',
          },
          {
            label: 'Wallet SFC',
            value: isLoading ? shimmerBlock('120px', '32px') : `${formatSfc(sfcBalance ?? 0n)} SFC`,
            sub: 'In your wallet',
          },
        ].map(({ label, value, sub, valueColor }) => (
          <div key={label} className="card stat-card">
            <div className="stat-label">{label}</div>
            <div className="stat-value" style={{ color: valueColor || 'var(--text-primary)', fontSize: '26px' }}>
              {value}
            </div>
            <div className="stat-sub">{sub}</div>
          </div>
        ))}
      </div>

      {/* Health factor with bar */}
      {!isLoading && hf > 0n && (
        <div className="card" style={{ padding: '20px 24px', marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
            <span style={{ fontSize: '12px', fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
              Health Factor
            </span>
            <HealthFactorBadge hf={hf} />
          </div>
          <div style={{ height: '6px', background: 'var(--bg-elevated)', borderRadius: '3px', overflow: 'hidden' }}>
            {(() => {
              const val = hfStatus === 'infinite' ? 100 : Math.min(100, (parseFloat(formatHealthFactor(hf)) / 3) * 100);
              const col = hfStatus === 'safe' || hfStatus === 'infinite' ? 'var(--safe)' : hfStatus === 'warning' ? 'var(--warning)' : 'var(--danger)';
              return <div style={{ height: '100%', width: `${val}%`, background: col, borderRadius: '3px', transition: 'width 0.6s ease' }} />;
            })()}
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '6px', fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            <span>0 — Liquidation</span>
            <span>1.0 — Min Safe</span>
            <span>3.0+</span>
          </div>
        </div>
      )}

      {/* Two-column: collateral breakdown + position details */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '24px' }}>
        {/* Collateral */}
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
            <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>Collateral Deposited</div>
          </div>
          {COLLATERAL_TOKENS.map((token) => {
            const bal = token.symbol === 'WETH' ? wethBalance : wbtcBalance;
            const dec = token.decimals;
            return (
              <div key={token.symbol} style={{ padding: '18px 24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{ width: 36, height: 36, borderRadius: '50%', background: `${token.color}20`, border: `2px solid ${token.color}40`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <span style={{ fontSize: '11px', fontWeight: 700, color: token.color }}>{token.symbol[0]}</span>
                  </div>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>{token.symbol}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>{token.name}</div>
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  {isLoading ? shimmerBlock('80px', '18px') : (
                    <div style={{ fontFamily: 'var(--font-mono)', fontSize: '14px', color: 'var(--text-primary)' }}>
                      {formatCollateral(bal ?? 0n, dec)} {token.symbol}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
          <div style={{ padding: '18px 24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Value</span>
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '14px', color: 'var(--text-primary)', fontWeight: 600 }}>
              {isLoading ? shimmerBlock('80px', '18px') : formatUsd(collateralValueInUsd)}
            </span>
          </div>
        </div>

        {/* Position details */}
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
            <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>Position Details</div>
          </div>
          {[
            { label: 'Debt (SFC Minted)', value: isLoading ? null : `${formatSfc(totalDscMinted)} SFC` },
            { label: 'Max Mintable', value: isLoading ? null : `${formatSfc(maxMintable > 0n ? maxMintable : 0n)} SFC` },
            { label: 'Utilization Rate', value: isLoading ? null : `${utilizationRate.toFixed(2)}%` },
            { label: 'Liq. Threshold', value: '50%' },
            { label: 'Liq. Bonus', value: '10%' },
            {
              label: 'Liq. Price (WETH)',
              value: isLoading ? null : getLiquidationPrice(collateralValueInUsd, totalDscMinted, wethBalance ?? 0n, 18),
            },
          ].map(({ label, value }) => (
            <div key={label} style={{ padding: '14px 24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{label}</span>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: 'var(--text-primary)' }}>
                {value === null ? shimmerBlock('80px', '16px') : value}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Quick actions */}
      <div className="card" style={{ padding: '20px 24px' }}>
        <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '16px' }}>
          Quick Actions
        </div>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          {[
            { href: '/deposit', label: 'Deposit Collateral' },
            { href: '/mint', label: 'Mint SFC' },
            { href: '/burn', label: 'Burn SFC' },
            { href: '/redeem', label: 'Redeem Collateral' },
          ].map(({ href, label }) => (
            <Link key={href} href={href} style={{ textDecoration: 'none' }}>
              <button className="btn-secondary" style={{ fontSize: '12px' }}>
                {label} <ArrowRight size={13} />
              </button>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
