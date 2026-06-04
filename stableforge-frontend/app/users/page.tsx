'use client';

import { useState, useEffect } from 'react';
import { usePublicClient } from 'wagmi';
import { formatUnits } from 'viem';
import { sepolia } from 'wagmi/chains';
import { ADDRESSES, SFC_ENGINE_ABI, COLLATERAL_TOKENS } from '@/lib/contracts';
import { fetchAllDepositors } from '@/lib/fetchLogs';
import { formatUsd, formatSfc, formatHealthFactor, getHealthFactorStatus, shortenAddress } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { HealthFactorBadge } from '@/components/HealthFactorBadge';
import { ExternalLink, X, ChevronDown, ChevronUp, Search } from 'lucide-react';

interface UserPosition {
  address: `0x${string}`;
  healthFactor: bigint;
  totalDscMinted: bigint;
  collateralValueInUsd: bigint;
  wethBalance: bigint;
  wbtcBalance: bigint;
}

function UserDetailModal({ pos, onClose }: { pos: UserPosition; onClose: () => void }) {
  const hfStatus = getHealthFactorStatus(pos.healthFactor);
  const hfNum = parseFloat(formatHealthFactor(pos.healthFactor));
  const barWidth = hfStatus === 'infinite' ? 100 : Math.min(100, (hfNum / 3) * 100);
  const barColor = hfStatus === 'safe' || hfStatus === 'infinite' ? 'var(--safe)' : hfStatus === 'warning' ? 'var(--warning)' : 'var(--danger)';

  const utilizationRate = pos.collateralValueInUsd > 0n
    ? (Number(pos.totalDscMinted * 10000n / pos.collateralValueInUsd) / 100).toFixed(2)
    : '0.00';

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 200,
      background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(6px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: '24px',
    }} onClick={onClose}>
      <div
        className="card fade-in"
        style={{ width: '100%', maxWidth: '520px', maxHeight: '85vh', overflow: 'auto', padding: 0 }}
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '6px' }}>
              User Position
            </div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: 'var(--text-primary)', wordBreak: 'break-all' }}>
              {pos.address}
            </div>
            <a
              href={`https://sepolia.etherscan.io/address/${pos.address}`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ fontSize: '11px', color: 'var(--accent)', display: 'inline-flex', alignItems: 'center', gap: '4px', marginTop: '4px', textDecoration: 'none' }}
            >
              View on Etherscan <ExternalLink size={10} />
            </a>
          </div>
          <button className="btn-ghost" onClick={onClose} style={{ padding: '6px', flexShrink: 0 }}>
            <X size={14} />
          </button>
        </div>

        {/* Health factor bar */}
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
            <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Health Factor</span>
            <HealthFactorBadge hf={pos.healthFactor} />
          </div>
          <div style={{ height: '6px', background: 'var(--bg-elevated)', borderRadius: '3px', overflow: 'hidden' }}>
            <div style={{ height: '100%', width: `${barWidth}%`, background: barColor, borderRadius: '3px', transition: 'width 0.6s ease' }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '5px', fontSize: '10px', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            <span>0</span><span>1.0 min</span><span>3.0+</span>
          </div>
        </div>

        {/* Stats */}
        <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            {[
              { label: 'SFC Minted', value: `${formatSfc(pos.totalDscMinted)} SFC` },
              { label: 'Collateral Value', value: formatUsd(pos.collateralValueInUsd) },
              { label: 'Utilization Rate', value: `${utilizationRate}%` },
              { label: 'Can Liquidate', value: parseFloat(formatHealthFactor(pos.healthFactor)) < 1.0 ? 'Yes' : 'No' },
            ].map(({ label, value }) => (
              <div key={label} style={{ padding: '14px', background: 'var(--bg-secondary)', borderRadius: '8px', border: '1px solid var(--border)' }}>
                <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '6px' }}>{label}</div>
                <div style={{ fontFamily: 'var(--font-mono)', fontSize: '14px', color: 'var(--text-primary)' }}>{value}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Collateral breakdown */}
        <div style={{ padding: '20px 24px' }}>
          <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '14px' }}>
            Collateral Breakdown
          </div>
          {COLLATERAL_TOKENS.map(token => {
            const bal = token.symbol === 'WETH' ? pos.wethBalance : pos.wbtcBalance;
            const formatted = parseFloat(formatUnits(bal, token.decimals)).toFixed(6);
            return (
              <div key={token.symbol} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 0', borderBottom: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ width: 32, height: 32, borderRadius: '50%', background: `${token.color}20`, border: `2px solid ${token.color}40`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <span style={{ fontSize: '10px', fontWeight: 700, color: token.color }}>{token.symbol[0]}</span>
                  </div>
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>{token.symbol}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{token.name}</div>
                  </div>
                </div>
                <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: bal > 0n ? 'var(--text-primary)' : 'var(--text-muted)' }}>
                  {formatted} {token.symbol}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

export default function UsersPage() {
  const publicClient = usePublicClient({ chainId: sepolia.id });

  const [positions, setPositions] = useState<UserPosition[]>([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState<UserPosition | null>(null);
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState<'hf' | 'debt' | 'collateral'>('hf');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  useEffect(() => {
    if (!publicClient) return;
    const load = async () => {
      setLoading(true);
      try {
        const uniqueUsers = await fetchAllDepositors(publicClient);

        const results = await Promise.all(
          uniqueUsers.map(async (user) => {
            try {
              const [accInfo, hf, weth, wbtc] = await Promise.all([
                publicClient.readContract({ address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getAccountInformation', args: [user] }),
                publicClient.readContract({ address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getHealthFactor', args: [user] }),
                publicClient.readContract({ address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [user, ADDRESSES.WETH] }),
                publicClient.readContract({ address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [user, ADDRESSES.WBTC] }),
              ]);
              const [totalDscMinted, collateralValueInUsd] = accInfo as [bigint, bigint];
              return { address: user, healthFactor: hf as bigint, totalDscMinted, collateralValueInUsd, wethBalance: weth as bigint, wbtcBalance: wbtc as bigint };
            } catch { return null; }
          })
        );

        setPositions(results.filter(Boolean) as UserPosition[]);
      } catch (e) { console.error(e); }
      finally { setLoading(false); }
    };
    load();
  }, [publicClient]);

  const handleSort = (col: typeof sortBy) => {
    if (sortBy === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortDir('asc'); }
  };

  const filtered = positions
    .filter(p => !search || p.address.toLowerCase().includes(search.toLowerCase()))
    .sort((a, b) => {
      let aVal: number, bVal: number;
      if (sortBy === 'hf') { aVal = Number(a.healthFactor); bVal = Number(b.healthFactor); }
      else if (sortBy === 'debt') { aVal = Number(a.totalDscMinted); bVal = Number(b.totalDscMinted); }
      else { aVal = Number(a.collateralValueInUsd); bVal = Number(b.collateralValueInUsd); }
      return sortDir === 'asc' ? aVal - bVal : bVal - aVal;
    });

  const atRiskCount = positions.filter(p => parseFloat(formatHealthFactor(p.healthFactor)) < 1.5 && p.totalDscMinted > 0n).length;

  const SortIcon = ({ col }: { col: typeof sortBy }) => (
    <span style={{ marginLeft: 4, display: 'inline-flex', opacity: sortBy === col ? 1 : 0.3 }}>
      {sortBy === col && sortDir === 'asc' ? <ChevronUp size={11} /> : <ChevronDown size={11} />}
    </span>
  );

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '40px 24px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
        <PageHeader
          tag="Protocol"
          title="All Users"
          subtitle="Every address that has interacted with StableForge. Click a row to inspect."
        />
        <div style={{ display: 'flex', gap: '12px', flexShrink: 0 }}>
          <div style={{ display: 'flex', gap: '12px' }}>
            {[
              { label: 'Total Users', value: positions.length },
              { label: 'At Risk', value: atRiskCount, color: atRiskCount > 0 ? 'var(--warning)' : undefined },
            ].map(({ label, value, color }) => (
              <div key={label} className="card" style={{ padding: '12px 20px', minWidth: '100px' }}>
                <div style={{ fontSize: '10px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '4px' }}>{label}</div>
                <div style={{ fontFamily: 'var(--font-display)', fontSize: '24px', fontWeight: 300, color: color || 'var(--text-primary)' }}>{value}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Search */}
      <div style={{ position: 'relative', marginBottom: '16px', maxWidth: '360px' }}>
        <Search size={13} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
        <input
          className="sf-input"
          placeholder="Search by address…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ paddingLeft: '34px' }}
        />
      </div>

      <div className="card" style={{ overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '60px', textAlign: 'center' }}>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
              Indexing on-chain events…
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
              {[0,1,2].map(i => (
                <div key={i} className="shimmer" style={{ width: '8px', height: '8px', borderRadius: '50%', animationDelay: `${i * 0.25}s` }} />
              ))}
            </div>
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: '60px', textAlign: 'center', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', fontSize: '13px' }}>
            {search ? 'No users match your search.' : 'No users found on-chain yet.'}
          </div>
        ) : (
          <table className="sf-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Address</th>
                <th style={{ cursor: 'pointer' }} onClick={() => handleSort('hf')}>
                  <span style={{ display: 'inline-flex', alignItems: 'center' }}>Health Factor <SortIcon col="hf" /></span>
                </th>
                <th style={{ cursor: 'pointer' }} onClick={() => handleSort('debt')}>
                  <span style={{ display: 'inline-flex', alignItems: 'center' }}>SFC Minted <SortIcon col="debt" /></span>
                </th>
                <th style={{ cursor: 'pointer' }} onClick={() => handleSort('collateral')}>
                  <span style={{ display: 'inline-flex', alignItems: 'center' }}>Collateral Value <SortIcon col="collateral" /></span>
                </th>
                <th>WETH</th>
                <th>WBTC</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((pos, i) => {
                const status = getHealthFactorStatus(pos.healthFactor);
                return (
                  <tr key={pos.address} onClick={() => setSelected(pos)}>
                    <td style={{ color: 'var(--text-muted)', fontSize: '11px' }}>{i + 1}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{ width: 24, height: 24, borderRadius: '50%', background: `hsl(${parseInt(pos.address.slice(2, 8), 16) % 360}, 50%, 30%)`, flexShrink: 0 }} />
                        <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-primary)' }}>{shortenAddress(pos.address)}</span>
                      </div>
                    </td>
                    <td><HealthFactorBadge hf={pos.healthFactor} /></td>
                    <td style={{ color: 'var(--text-primary)' }}>{formatSfc(pos.totalDscMinted)} SFC</td>
                    <td>{formatUsd(pos.collateralValueInUsd)}</td>
                    <td style={{ color: 'var(--weth)' }}>{parseFloat(formatUnits(pos.wethBalance, 18)).toFixed(4)}</td>
                    <td style={{ color: 'var(--wbtc)' }}>{parseFloat(formatUnits(pos.wbtcBalance, 8)).toFixed(4)}</td>
                    <td>
                      <span className={
                        status === 'infinite' ? 'badge-infinite' :
                        status === 'safe' ? 'badge-safe' :
                        status === 'warning' ? 'badge-warning' : 'badge-danger'
                      } style={{ fontSize: '10px', padding: '2px 8px' }}>
                        {status === 'infinite' ? '∞ Safe' : status === 'safe' ? 'Safe' : status === 'warning' ? 'Warning' : 'At Risk'}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {selected && <UserDetailModal pos={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}
