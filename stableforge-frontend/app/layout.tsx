import type { Metadata } from 'next';
import './globals.css';
import { ThemeProvider } from '@/components/ThemeProvider';
import { Providers } from '@/components/Providers';
import { Navbar } from '@/components/Navbar';

export const metadata: Metadata = {
  title: 'StableForge — Decentralized Stablecoin Protocol',
  description: 'Mint SFC stablecoins backed by WETH and WBTC collateral on Sepolia.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body>
        <ThemeProvider>
          <Providers>
            <div style={{ position: 'relative', minHeight: '100vh' }}>
              <Navbar />
              <main style={{ paddingTop: '64px' }}>
                {children}
              </main>
            </div>
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  );
}
