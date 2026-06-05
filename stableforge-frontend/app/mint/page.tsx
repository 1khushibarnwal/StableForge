'use client';

import { useState } from 'react';
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { ADDRESSES, SFC_ENGINE_ABI } from '@/lib/contracts';
import { formatUsd, formatSfc, formatHealthFactor } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { TxStatus } from '@/components/TxStatus';
import { HealthFactorBadge } from '@/components/HealthFactorBadge';

export default function MintPage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState('');

  const { writeContract, data: hash, isPending, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data } = useReadContracts({
    contracts: address ? [
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getAccountInformation', args: [address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getHealthFactor', args: [address] },
    ] : [],
    query: { enabled: !!address, refetchInterval: 8000 },
  });

  const accountInfo = data?.[0]?.result as [bigint, bigint] | undefined;
  const hf = data?.[1]?.result as bigint | undefined;

  const totalDscMinted = accountInfo?.[0] ?? 0n;
  const collateralValueInUsd = accountInfo?.[1] ?? 0n;
  const maxMintable = collateralValueInUsd > 0n ? (collateralValueInUsd / 2n) - totalDscMinted : 0n;

  const txStatus = isPending || isConfirming ? 'pending' : isSuccess ? 'success' : 'idle';

  const handleMint = () => {
    if (!amount) return;
    writeContract({
      address: ADDRESSES.SFCEngine,
      abi: SFC_ENGINE_ABI,
      functionName: 'mintSfc',
      args: [parseUnits(amount, 18)],
    });
  };

  if (!isConnected) return (
    <div style={{ maxWidth: '540px', margin: '60px auto', padding: '0 24px' }}>
      <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Wallet</div>
        <p style={{ color: 'var(--text-secondary)' }}>Connect your wallet to mint SFC.</p>
      </div>
    </div>
  );

  return (
    <div style={{ maxWidth: '540px', margin: '0 auto', padding: '40px 24px' }}>
      <PageHeader tag="Stablecoin" title="Mint SFC" subtitle="Mint SFC against your deposited collateral. Maintain health factor above 1.0." />

      <div className="card" style={{ overflow: 'hidden', marginBottom: '16px' }}>
        <div style={{ padding: '16px 24px', borderBottom: '1px solid var(--border)', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '16px' }}>
          {[
            { label: 'Collateral', value: formatUsd(collateralValueInUsd) },
            { label: 'Minted', value: `${formatSfc(totalDscMinted)} SFC` },
            { label: 'Available', value: `${formatSfc(maxMintable > 0n ? maxMintable : 0n)} SFC` },
          ].map(({ label, value }) => (
            <div key={label}>
              <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '4px' }}>{label}</div>
              <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: 'var(--text-primary)' }}>{value}</div>
            </div>
          ))}
        </div>

        <div style={{ padding: '24px' }}>
          {hf && (
            <div style={{ marginBottom: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Current Health Factor</span>
              <HealthFactorBadge hf={hf} />
            </div>
          )}

          <div style={{ marginBottom: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Amount to Mint
              </label>
              {maxMintable > 0n && (
                <button
                  onClick={() => setAmount((Number(maxMintable) / 1e18 * 0.9).toFixed(6))}
                  style={{ fontSize: '11px', color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-mono)' }}
                >
                  90% max: {formatSfc(maxMintable > 0n ? (maxMintable * 9n) / 10n : 0n)}
                </button>
              )}
            </div>
            <div style={{ position: 'relative' }}>
              <input
                className="sf-input"
                type="number"
                placeholder="0.0"
                value={amount}
                onChange={e => setAmount(e.target.value)}
                style={{ paddingRight: '44px' }}
              />
              <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                SFC
              </span>
            </div>
          </div>

          <div className="divider" style={{ marginBottom: '20px' }} />
          <TxStatus status={txStatus} hash={hash} successMessage="SFC minted successfully!" />

          <button
            className="btn-primary"
            onClick={handleMint}
            disabled={!amount || isPending || isConfirming}
            style={{ width: '100%', justifyContent: 'center', marginTop: txStatus !== 'idle' ? '12px' : '0' }}
          >
            {isPending || isConfirming ? 'Minting…' : 'Mint SFC'}
          </button>
        </div>
      </div>

      <div className="alert alert-warning">
        <span style={{ fontSize: '20px' }}>⚠</span>
        <span style={{ fontSize: '12px' }}>Minting increases your debt. Ensure your health factor stays above 1.0 to avoid liquidation.</span>
      </div>
    </div>
  );
}
