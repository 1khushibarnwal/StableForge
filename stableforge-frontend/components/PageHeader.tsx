'use client';

interface Props {
  title: string;
  subtitle?: string;
  tag?: string;
}

export function PageHeader({ title, subtitle, tag }: Props) {
  return (
    <div style={{ marginBottom: '32px' }}>
      {tag && (
        <div style={{
          fontSize: '11px', fontWeight: 600, letterSpacing: '0.1em',
          textTransform: 'uppercase', color: 'var(--text-muted)',
          fontFamily: 'var(--font-mono)', marginBottom: '8px',
        }}>
          {tag}
        </div>
      )}
      <h1 style={{
        fontFamily: 'var(--font-display)',
        fontSize: '40px', fontWeight: 300,
        color: 'var(--text-primary)', lineHeight: 1.1,
        marginBottom: subtitle ? '10px' : 0,
      }}>
        {title}
      </h1>
      {subtitle && (
        <p style={{ fontSize: '14px', color: 'var(--text-secondary)', maxWidth: '520px' }}>
          {subtitle}
        </p>
      )}
    </div>
  );
}
