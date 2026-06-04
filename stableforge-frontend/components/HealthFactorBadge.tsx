'use client';

import { formatHealthFactor, getHealthFactorStatus } from '@/lib/utils';

interface Props {
  hf: bigint;
  showBar?: boolean;
}

export function HealthFactorBadge({ hf, showBar = false }: Props) {
  const status = getHealthFactorStatus(hf);
  const formatted = formatHealthFactor(hf);

  const badgeClass = status === 'infinite' ? 'badge-infinite'
    : status === 'safe' ? 'badge-safe'
    : status === 'warning' ? 'badge-warning'
    : 'badge-danger';

  const barColor = status === 'safe' ? 'var(--safe)'
    : status === 'warning' ? 'var(--warning)'
    : status === 'infinite' ? 'var(--accent)'
    : 'var(--danger)';

  const barWidth = status === 'infinite' ? 100
    : Math.min(100, (parseFloat(formatted) / 3) * 100);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
      <span className={badgeClass}>
        <span style={{ fontSize: '8px', lineHeight: 1 }}>●</span>
        HF {formatted}
      </span>
      {showBar && (
        <div style={{ height: '3px', background: 'var(--bg-elevated)', borderRadius: '2px', overflow: 'hidden', width: '100%' }}>
          <div style={{ height: '100%', width: `${barWidth}%`, background: barColor, borderRadius: '2px', transition: 'width 0.6s ease' }} />
        </div>
      )}
    </div>
  );
}
