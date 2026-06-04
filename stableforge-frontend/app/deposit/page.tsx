'use client';

import { useState } from 'react';
import { useAccount, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, maxUint256 } from 'viem';
import { ADDRESSES, SFC_ENGINE_ABI, ERC20_ABI, COLLATERAL_TOKENS } from '@/lib/contracts';
import type { CollateralToken } from '@/lib/contracts';
import { formatCollateral } from '@/lib/utils';
import { PageHeader } from '@/components/PageHeader';
import { TxStatus } from '@/components/TxStatus';
import { Info } from 'lucide-react';

export default function DepositPage() {
  const { address, isConnected } = useAccount();
  const [selectedToken, setSelectedToken] = useState<CollateralToken>(COLLATERAL_TOKENS[0]);
  const [amount, setAmount] = useState('');
  const [mintAmount, setMintAmount] = useState('');
  const [combinedMode, setCombinedMode] = useState(false);
  const [step, setStep] = useState<'approve' | 'deposit'>('approve');

  const { writeContract, data: hash, isPending, reset } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const { data } = useReadContracts({
    contracts: address ? [
      { address: selectedToken.address, abi: ERC20_ABI, functionName: 'balanceOf', args: [address] },
      { address: selectedToken.address, abi: ERC20_ABI, functionName: 'allowance', args: [address, ADDRESSES.SFCEngine] },
      { address: ADDRESSES.SFCEngine, abi: SFC_ENGINE_ABI, functionName: 'getCollateralBalanceOfUser', args: [address, selectedToken.address] },
    ] : [],
    query: { enabled: !!address, refetchInterval: 8000 },
  });

  const walletBalance = data?.[0]?.result as bigint | undefined;
  const allowance = data?.[1]?.result as bigint | undefined;
  const deposited = data?.[2]?.result as bigint | undefined;

  const amountBn = amount ? parseUnits(amount, selectedToken.decimals) : 0n;
  const needsApproval = allowance !== undefined && amountBn > 0n && allowance < amountBn;

  const txStatus = isPending || isConfirming ? 'pending' : isSuccess ? 'success' : 'idle';

  const handleApprove = () => {
    writeContract({
      address: selectedToken.address,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [ADDRESSES.SFCEngine, maxUint256],
    });
  };

  const handleDeposit = () => {
    if (!amount) return;
    if (combinedMode && mintAmount) {
      writeContract({
        address: ADDRESSES.SFCEngine,
        abi: SFC_ENGINE_ABI,
        functionName: 'depositCollateralAndMintDsc',
        args: [selectedToken.address, amountBn, parseUnits(mintAmount, 18)],
      });
    } else {
      writeContract({
        address: ADDRESSES.SFCEngine,
        abi: SFC_ENGINE_ABI,
        functionName: 'depositCollateral',
        args: [selectedToken.address, amountBn],
      });
    }
  };

  if (!isConnected) {
    return (
      <div style={{ maxWidth: '540px', margin: '60px auto', padding: '0 24px' }}>
        <div className="card" style={{ padding: '48px', textAlign: 'center' }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: '28px', marginBottom: '12px' }}>Connect Wallet</div>
          <p style={{ color: 'var(--text-secondary)' }}>Connect your wallet to deposit collateral.</p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '540px', margin: '0 auto', padding: '40px 24px' }}>
      <PageHeader tag="Collateral" title="Deposit" subtitle="Deposit WETH or WBTC as collateral to mint SFC stablecoins." />

      <div className="card" style={{ overflow: 'hidden' }}>
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
                  onClick={() => { setSelectedToken(token); setAmount(''); reset(); }}
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

          {/* Amount input */}
          <div style={{ marginBottom: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
              <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)' }}>
                Amount
              </label>
              {walletBalance !== undefined && (
                <button
                  onClick={() => setAmount(walletBalance > 0n ? (Number(walletBalance) / 10 ** selectedToken.decimals).toString() : '')}
                  style={{ fontSize: '11px', color: 'var(--accent)', background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'var(--font-mono)' }}
                >
                  Max: {formatCollateral(walletBalance, selectedToken.decimals)} {selectedToken.symbol}
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
                style={{ paddingRight: '60px' }}
              />
              <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                {selectedToken.symbol}
              </span>
            </div>
          </div>

          {/* Deposited balance info */}
          {deposited !== undefined && (
            <div className="alert alert-info" style={{ marginBottom: '16px' }}>
              <Info size={14} style={{ flexShrink: 0 }} />
              <span style={{ fontSize: '12px' }}>
                Already deposited: <strong>{formatCollateral(deposited, selectedToken.decimals)} {selectedToken.symbol}</strong>
              </span>
            </div>
          )}

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
              <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-primary)' }}>Also mint SFC</div>
              <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Deposit + mint in one transaction</div>
            </div>
          </div>

          {combinedMode && (
            <div style={{ marginBottom: '20px' }}>
              <label style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', display: 'block', marginBottom: '8px' }}>
                SFC to Mint
              </label>
              <div style={{ position: 'relative' }}>
                <input
                  className="sf-input"
                  type="number"
                  placeholder="0.0"
                  value={mintAmount}
                  onChange={e => setMintAmount(e.target.value)}
                  style={{ paddingRight: '44px' }}
                />
                <span style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                  SFC
                </span>
              </div>
            </div>
          )}

          <div className="divider" style={{ marginBottom: '20px' }} />

          <TxStatus
            status={txStatus}
            hash={hash}
            successMessage={step === 'approve' ? 'Approval confirmed!' : 'Collateral deposited!'}
          />

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: txStatus !== 'idle' ? '12px' : '0' }}>
            {needsApproval && (
              <button className="btn-secondary" onClick={handleApprove} disabled={isPending || isConfirming} style={{ width: '100%', justifyContent: 'center' }}>
                {isPending || isConfirming ? 'Approving…' : `Approve ${selectedToken.symbol}`}
              </button>
            )}
            <button
              className="btn-primary"
              onClick={handleDeposit}
              disabled={!amount || needsApproval || isPending || isConfirming}
              style={{ width: '100%', justifyContent: 'center' }}
            >
              {isPending || isConfirming ? 'Depositing…' : combinedMode ? 'Deposit & Mint' : 'Deposit Collateral'}
            </button>
          </div>
        </div>
      </div>

      {/* Info card */}
      <div className="card" style={{ marginTop: '16px', padding: '16px 20px' }}>
        <div style={{ fontSize: '11px', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '10px' }}>
          Protocol Info
        </div>
        {[
          ['Collateral Ratio', '200% minimum'],
          ['Liquidation Threshold', '50% of collateral value'],
          ['Liquidation Bonus', '10% for liquidators'],
        ].map(([k, v]) => (
          <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px solid var(--border)', fontSize: '12px' }}>
            <span style={{ color: 'var(--text-secondary)' }}>{k}</span>
            <span style={{ color: 'var(--text-primary)', fontFamily: 'var(--font-mono)' }}>{v}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
