import type { PublicClient } from "viem";
import { ADDRESSES } from "./contracts";

export const DEPLOY_BLOCK = 8_200_000n;
const CHUNK_SIZE = 9000n; // stay under 10k limit

const COLLATERAL_DEPOSITED_EVENT = {
  name: "CollateralDeposited",
  type: "event",
  inputs: [
    { name: "user", type: "address", indexed: true },
    { name: "token", type: "address", indexed: true },
    { name: "amount", type: "uint256", indexed: false },
  ],
} as const;

export async function fetchAllDepositors(
  publicClient: PublicClient,
): Promise<`0x${string}`[]> {
  const latestBlock = await publicClient.getBlockNumber();

  const allUsers = new Set<`0x${string}`>();

  for (let from = DEPLOY_BLOCK; from <= latestBlock; from += CHUNK_SIZE) {
    const to =
      from + CHUNK_SIZE - 1n > latestBlock
        ? latestBlock
        : from + CHUNK_SIZE - 1n;

    try {
      const logs = await publicClient.getLogs({
        address: ADDRESSES.SFCEngine,
        event: COLLATERAL_DEPOSITED_EVENT,
        fromBlock: from,
        toBlock: to,
      });

      for (const log of logs) {
        if (log.args.user) allUsers.add(log.args.user as `0x${string}`);
      }
    } catch (e) {
      // If a chunk still fails (e.g. very slow RPC), skip it silently
      console.warn(`Skipped block range ${from}-${to}:`, e);
    }
  }

  return [...allUsers];
}
