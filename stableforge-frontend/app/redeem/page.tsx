'use client';

import { useState } from 'react';
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, maxUint256 } from 'viem';
import { ADDRESSES, SFC_ENGINE_ABI, ERC20_ABI, COLLATERAL_TOKENS } from '@/lib/contracts';
import type { CollateralToken } from '@/lib/contracts';
import { formatCollateral, formatSfc } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { TxStatus } from '@/components/TxStatus';
import { HealthFactorBadge } from '@/components/HealthFactorBadge';

export default function RedeemPage() {
  const { address, isConnected } = useAccount();
  const [selectedToken, setSelectedToken] = useState<CollateralToken>(COLLATERAL_TOKENS[0]);
  const [colAmount, setColAmount] = useState('');
  const [burnAmount, setBurnAmount] = useState('');
  const [combinedMode, setCombinedMode] = useState(false);

  const { writeContract, data: hash, isPending, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data } = useReadContracts({
    contracts: address ? [
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [address, selectedToken.address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getHealthFactor', args: [address] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getAccountInformation', args: [address] },
      { address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'balanceOf', args: [address] },
      { address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'allowance', args: [address, ADDRESSES.SFCEngine] },
    ] : [],
    query: { enabled: !!address, refetchInterval: 8000 },
  });

  const deposited = data?.[0]?.result as bigint | undefined;
  const hf = data?.[1]?.result as bigint | undefined;
  const accountInfo = data?.[2]?.result as [bigint, bigint] | undefined;
  const sfcBalance = data?.[3]?.result as bigint | undefined;
  const allowance = data?.[4]?.result as bigint | undefined;

  const totalDscMinted = accountInfo?.[0] ?? 0n;

  const colAmountBn = colAmount ? parseUnits(colAmount, selectedToken.decimals) : 0n;
  const burnAmountBn = burnAmount ? parseUnits(burnAmount, 18) : 0n;
  const needsSfcApproval = combinedMode && allowance !== undefined && burnAmountBn > 0n && allowance < burnAmountBn;

  const txStatus = isPending || isConfirming ? 'pending' : isSuccess ? 'success' : 'idle';

  const handleApprove = () => {
    writeContract({ address: ADDRESSES.StableForgeCoin, abi: ERC20_ABI, functionName: 'approve', args: [ADDRESSES.SFCEngine, maxUint256] });
  };

  const handleRedeem = () => {
    if (!colAmount) return;
    if (combinedMode && burnAmount) {
      writeContract({
        address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI,
        functionName: 'redeemCollateralForDsc',
        args: [selectedToken.address, colAmountBn, burnAmountBn],
      });
    } else {
      writeContract({
        address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI,
        functionName: 'redeemCollateral',
        args: [selectedToken.address, colAmountBn],
      });
    }
  };

  if (!isConnected) return (
    <div style={{ maxWidth: '540px', margin: '60px auto', padding: '0 24px' }}>
      <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Wallet</div>
        <p style={{ color: 'var(--text-secondary)' }}>Connect your wallet to redeem collateral.</p>
      </div>
    </div>
  );

  return (
    <div style={{ maxWidth: '540px', margin: '0 auto', padding: '40px 24px' }}>
      <PageHeader tag="Collateral" title="Redeem" subtitle="Withdraw your collateral. Health factor must remain above 1.0 after redemption." />

      <div className="card" style={{ overflow: 'hidden', marginBottom: '16px' }}>
        <div style={{ padding: '16px 24px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '4px' }}>Outstanding Debt</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: '13px', color: 'var(--text-primary)' }}>{formatSfc(totalDscMinted)} SFC</div>
          </div>
          {hf && <HealthFactorBadge hf={hf} />}
        </div>

        <div style={{ padding: '24px' }}>
          {/* Token selector */}
          <div style={{ marginBottom: '20px' }}>
            <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', display: 'block', marginBottom: '8px' }}>
              Collateral Token
            </label>
            <div style={{ display: 'flex', gap: '8px' }}>
              {COLLATERAL_TOKENS.map((token) => (
                <button
                  key={token.symbol}
                  onClick={() => { setSelectedToken(token); setColAmount(''); reset(); }}
                  style={{
                    flex: 1, padding: '12px', borderRadius: '8px', cursor: 'pointer',
                    border: `1px solid ${selectedToken.symbol === token.symbol ? token.color + '60' : 'var(--border)'}`,
                    background: selectedToken.symbol === token.symbol ? `${token.color}15` : 'var(--bg-secondary)',
                    color: selectedToken.symbol === token.symbol ? token.color : 'var(--text-secondary)',
                    transition: 'all 0.2s',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px',
                  }}
                >
                  <span style={{ fontSize: '14px', fontWeight: 700 }}>{token.symbol}</span>
                  <span style={{ fontSize: '11px', opacity: 0.7 }}>{token.name}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Collateral amount */}
          <div style={{ marginBottom: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Collateral to Redeem
              </label>
              {deposited !== undefined && (
                <button
                  onClick={() => setColAmount((Number(deposited) / 10 ** selectedToken.decimals).toString())}
                  style={{ fontSize: '11px', color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-mono)' }}
                >
                  Max: {formatCollateral(deposited, selectedToken.decimals)} {selectedToken.symbol}
                </button>
              )}
            </div>
            <div style={{ position: 'relative' }}>
              <input
                className="sf-input"
                type="number"
                placeholder="0.0"
                value={colAmount}
                onChange={e => setColAmount(e.target.value)}
                style={{ paddingRight: '60px' }}
              />
              <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                {selectedToken.symbol}
              </span>
            </div>
          </div>

          {/* Combined mode toggle */}
          <div style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px', padding: '12px', background: 'var(--bg-secondary)', borderRadius: '8px', border: '1px solid var(--border)', cursor: 'pointer' }}
            onClick={() => setCombinedMode(!combinedMode)}>
            <div style={{
              width: 36, height: 20, borderRadius: '10px', position: 'relative',
              background: combinedMode ? 'var(--accent)' : 'var(--bg-elevated)',
              transition: 'background 0.2s', flexShrink: 0, border: '1px solid var(--border-strong)',
            }}>
              <div style={{
                position: 'absolute', top: '2px',
                left: combinedMode ? '18px' : '2px',
                width: 14, height: 14, borderRadius: '50%',
                background: 'white', transition: 'left 0.2s',
                boxShadow: '0 1px 3px rgba(0,0,0,0.3)',
              }} />
            </div>
            <div>
              <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>Also burn SFC</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Redeem + burn in one transaction</div>
            </div>
          </div>

          {combinedMode && (
            <div style={{ marginBottom: '20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                  SFC to Burn
                </label>
                {sfcBalance !== undefined && sfcBalance > 0n && (
                  <button
                    onClick={() => setBurnAmount((Number(sfcBalance) / 1e18).toString())}
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
                  value={burnAmount}
                  onChange={e => setBurnAmount(e.target.value)}
                  style={{ paddingRight: '44px' }}
                />
                <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                  SFC
                </span>
              </div>
            </div>
          )}

          <div className="divider" style={{ marginBottom: '20px' }} />
          <TxStatus status={txStatus} hash={hash} successMessage="Collateral redeemed!" />

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: txStatus !== 'idle' ? '12px' : '0' }}>
            {needsSfcApproval && (
              <button className="btn-secondary" onClick={handleApprove} disabled={isPending || isConfirming} style={{ width: '100%', justifyContent: 'center' }}>
                {isPending || isConfirming ? 'Approving…' : 'Approve SFC'}
              </button>
            )}
            <button
              className="btn-primary"
              onClick={handleRedeem}
              disabled={!colAmount || needsSfcApproval || isPending || isConfirming}
              style={{ width: '100%', justifyContent: 'center' }}
            >
              {isPending || isConfirming ? 'Redeeming…' : combinedMode ? 'Redeem & Burn' : 'Redeem Collateral'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
