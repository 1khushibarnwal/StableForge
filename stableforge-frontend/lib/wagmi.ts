"use client";

import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

import "dotenv/config";

export const wagmiConfig = getDefaultConfig({
  appName: "StableForge",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
    ? process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID
    : "",
  chains: [sepolia],
  ssr: true,
});
