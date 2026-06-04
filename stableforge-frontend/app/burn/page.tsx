'use client';

import { useState } from 'react';
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, maxUint256 } from 'viem';
import { ADDRESSES, SFC_ENGINE_ABI, ERC20_ABI } from '@/lib/contracts';
import { formatSfc } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { TxStatus } from '@/components/TxStatus';
import { HealthFactorBadge } from '@/components/HealthFactorBadge';

export default function BurnPage() {
  const { address, isConnected } = useAccount();
  const [amount, setAmount] = useState('');

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data } = useReadContracts({
    contracts: address ? [
      { address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'allowance', args: [address, ADDRESSES.SFCEngine] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getAccountInformation', args: [address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getHealthFactor', args: [address] },
    ] : [],
    query: { enabled: !!address, refetchInterval: 8000 },
  });

  const sfcBalance = data?.[0]?.result as bigint | undefined;
  const allowance = data?.[1]?.result as bigint | undefined;
  const accountInfo = data?.[2]?.result as [bigint, bigint] | undefined;
  const hf = data?.[3]?.result as bigint | undefined;
  const totalDscMinted = accountInfo?.[0] ?? 0n;

  const amountBn = amount ? parseUnits(amount, 18) : 0n;
  const needsApproval = allowance !== undefined && amountBn > 0n && allowance < amountBn;
  const txStatus = isPending || isConfirming ? 'pending' : isSuccess ? 'success' : 'idle';

  const handleApprove = () => {
    writeContract({ address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'approve', args: [ADDRESSES.SFCEngine, maxUint256] });
  };

  const handleBurn = () => {
    if (!amount) return;
    writeContract({ address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'burnDsc', args: [amountBn] });
  };

  if (!isConnected) return (
    <div style={{ maxWidth: '540px', margin: '60px auto', padding: '0 24px' }}>
      <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Wallet</div>
        <p style={{ color: 'var(--text-secondary)' }}>Connect your wallet to burn SFC.</p>
      </div>
    </div>
  );

  return (
    <div style={{ maxWidth: '540px', margin: '0 auto', padding: '40px 24px' }}>
      <PageHeader tag="Stablecoin" title="Burn SFC" subtitle="Burn SFC to reduce your debt and improve your health factor." />

      <div className="card" style={{ overflow: 'hidden', marginBottom: '16px' }}>
        <div style={{ padding: '16px 24px', borderBottom: '1px solid var(--border)', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
          {[
            { label: 'Wallet SFC', value: `${formatSfc(sfcBalance ?? 0n)} SFC` },
            { label: 'Outstanding Debt', value: `${formatSfc(totalDscMinted)} SFC` },
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
                Amount to Burn
              </label>
              {sfcBalance !== undefined && sfcBalance > 0n && (
                <button
                  onClick={() => setAmount((Number(sfcBalance) / 1e18).toString())}
                  style={{ fontSize: '11px', color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-mono)' }}
                >
                  Max: {formatSfc(sfcBalance)} SFC
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
          <TxStatus status={txStatus} hash={hash} successMessage="SFC burned successfully!" />

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: txStatus !== 'idle' ? '12px' : '0' }}>
            {needsApproval && (
              <button className="btn-secondary" onClick={handleApprove} disabled={isPending || isConfirming} style={{ width: '100%', justifyContent: 'center' }}>
                {isPending || isConfirming ? 'Approving…' : 'Approve SFC'}
              </button>
            )}
            <button
              className="btn-primary"
              onClick={handleBurn}
              disabled={!amount || needsApproval || isPending || isConfirming}
              style={{ width: '100%', justifyContent: 'center' }}
            >
              {isPending || isConfirming ? 'Burning…' : 'Burn SFC'}
            </button>
          </div>
        </div>
      </div>

      <div className="alert alert-info">
        <span>ℹ</span>
        <span style={{ fontSize: '12px' }}>Burning SFC reduces your outstanding debt and improves your health factor. You can burn up to your total minted amount.</span>
      </div>
    </div>
  );
}
