'use client';

import { CheckCircle, XCircle, Loader2, ExternalLink } from 'lucide-react';

type Status = 'idle' | 'pending' | 'success' | 'error';

interface Props {
  status: Status;
  hash?: string;
  errorMessage?: string;
  successMessage?: string;
}

export function TxStatus({ status, hash, errorMessage, successMessage }: Props) {
  if (status === 'idle') return null;

  if (status === 'pending') {
    return (
      <div className="alert alert-info">
        <Loader2 size={15} style={{ flexShrink: 0, animation: 'spin 1s linear infinite' }} />
        <span>Transaction pending... Please confirm in your wallet.</span>
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      </div>
    );
  }

  if (status === 'success') {
    return (
      <div className="alert alert-success">
        <CheckCircle size={15} style={{ flexShrink: 0 }} />
        <div style={{ flex: 1 }}>
          <div>{successMessage || 'Transaction confirmed!'}</div>
          {hash && (
            <a
              href={`https://sepolia.etherscan.io/tx/${hash}`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ fontSize: '12px', display: 'inline-flex', alignItems: 'center', gap: '4px', marginTop: '4px', color: 'inherit', opacity: 0.8 }}
            >
              View on Etherscan <ExternalLink size={11} />
            </a>
          )}
        </div>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="alert alert-error">
        <XCircle size={15} style={{ flexShrink: 0 }} />
        <span>{errorMessage || 'Transaction failed. Please try again.'}</span>
      </div>
    );
  }

  return null;
}
