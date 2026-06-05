import type { Metadata } from "next";
import "./globals.css";
import { ThemeProvider } from "@/components/ThemeProvider";
import { Providers } from "@/components/Providers";
import { Navbar } from "@/components/Navbar";

export const metadata: Metadata = {
  title: "StableForge",
  description:
    "A decentralized, overcollateralized stablecoin protocol on Ethereum. Deposit WETH or WBTC as collateral and mint SFC — a USD-pegged stablecoin — with no fees, no governance, and full on-chain transparency.",
  openGraph: {
    title: "StableForge",
    description:
      "Mint SFC, a decentralized USD-pegged stablecoin, by depositing ETH or BTC collateral. Built on Sepolia with Chainlink price feeds.",
    url: "https://stableforge.vercel.app",
    siteName: "StableForge",
    type: "website",
  },
  icons: {
    icon: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body>
        <ThemeProvider>
          <Providers>
            <div style={{ position: "relative", minHeight: "100vh" }}>
              <Navbar />
              <main style={{ paddingTop: "64px" }}>{children}</main>
            </div>
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  );
}
