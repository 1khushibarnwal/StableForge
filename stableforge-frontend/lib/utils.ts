import { formatUnits } from 'viem';

export function formatUsd(value: bigint, decimals = 18): string {
  const num = parseFloat(formatUnits(value, decimals));
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(num);
}

export function formatSfc(value: bigint): string {
  const num = parseFloat(formatUnits(value, 18));
  return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
}

export function formatCollateral(value: bigint, decimals: number): string {
  const num = parseFloat(formatUnits(value, decimals));
  return num.toLocaleString('en-US', { minimumFractionDigits: 4, maximumFractionDigits: 6 });
}

export function formatHealthFactor(hf: bigint): string {
  if (hf === BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')) {
    return '∞';
  }
  const num = parseFloat(formatUnits(hf, 18));
  if (num > 999) return '>999';
  return num.toFixed(2);
}

export function getHealthFactorStatus(hf: bigint): 'safe' | 'warning' | 'danger' | 'infinite' {
  if (hf === BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')) return 'infinite';
  const num = parseFloat(formatUnits(hf, 18));
  if (num >= 1.5) return 'safe';
  if (num >= 1.0) return 'warning';
  return 'danger';
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function getLiquidationPrice(
  collateralUsd: bigint,
  dscMinted: bigint,
  collateralAmount: bigint,
  collateralDecimals: number
): string {
  if (collateralAmount === 0n || dscMinted === 0n) return 'N/A';
  // liquidation when collateralUsd * 0.5 = dscMinted
  // price = (dscMinted * 2) / collateralAmount
  const dscNum = parseFloat(formatUnits(dscMinted, 18));
  const colNum = parseFloat(formatUnits(collateralAmount, collateralDecimals));
  if (colNum === 0) return 'N/A';
  const liqPrice = (dscNum * 2) / colNum;
  return `$${liqPrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
