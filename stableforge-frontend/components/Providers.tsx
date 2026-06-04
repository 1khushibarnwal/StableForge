'use client';

import { RainbowKitProvider, darkTheme, lightTheme } from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { wagmiConfig } from '@/lib/wagmi';
import { useTheme } from '@/components/ThemeProvider';
import '@rainbow-me/rainbowkit/styles.css';

const queryClient = new QueryClient();

function RainbowKitWithTheme({ children }: { children: React.ReactNode }) {
  const { theme } = useTheme();
  return (
    <RainbowKitProvider
      theme={theme === 'dark' ? darkTheme({
        accentColor: '#C9A96E',
        accentColorForeground: '#0A0A0A',
        borderRadius: 'medium',
        fontStack: 'system',
      }) : lightTheme({
        accentColor: '#8B6914',
        accentColorForeground: '#FFFFFF',
        borderRadius: 'medium',
        fontStack: 'system',
      })}
    >
      {children}
    </RainbowKitProvider>
  );
}

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitWithTheme>
          {children}
        </RainbowKitWithTheme>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
