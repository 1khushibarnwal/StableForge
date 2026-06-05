import type { PublicClient } from 'viem';
import { ADDRESSES } from './contracts';

// ─────────────────────────────────────────────────────────────────
// SET THIS to the block your SFCEngine was deployed on Sepolia.
// Find it on Etherscan: https://sepolia.etherscan.io/address/0xb3aaed6233f01d0b77ec265a7bdfce83e71bf9f1
// Look at the first transaction — that's the deployment block.
// ─────────────────────────────────────────────────────────────────
export const DEPLOY_BLOCK = 8_200_000n; // ← update this with your real deployment block

const CHUNK_SIZE = 9_000n;   // under the 10k RPC limit
const MAX_PARALLEL = 5;       // concurrent requests at a time

const COLLATERAL_DEPOSITED_EVENT = {
  name: 'CollateralDeposited',
  type: 'event',
  inputs: [
    { name: 'user', type: 'address', indexed: true },
    { name: 'token', type: 'address', indexed: true },
    { name: 'amount', type: 'uint256', indexed: false },
  ],
} as const;

export async function fetchAllDepositors(
  publicClient: PublicClient
): Promise<`0x${string}`[]> {
  const latestBlock = await publicClient.getBlockNumber();

  // Build all chunk ranges from deploy block to now
  const ranges: Array<{ from: bigint; to: bigint }> = [];
  for (let from = DEPLOY_BLOCK; from <= latestBlock; from += CHUNK_SIZE) {
    const to = from + CHUNK_SIZE - 1n > latestBlock ? latestBlock : from + CHUNK_SIZE - 1n;
    ranges.push({ from, to });
  }

  const allUsers = new Set<`0x${string}`>();

  // Process in parallel batches of MAX_PARALLEL
  for (let i = 0; i < ranges.length; i += MAX_PARALLEL) {
    const batch = ranges.slice(i, i + MAX_PARALLEL);
    const results = await Promise.allSettled(
      batch.map(({ from, to }) =>
        publicClient.getLogs({
          address: ADDRESSES.SFCEngine,
          event: COLLATERAL_DEPOSITED_EVENT,
          fromBlock: from,
          toBlock: to,
        })
      )
    );

    for (const result of results) {
      if (result.status === 'fulfilled') {
        for (const log of result.value) {
          if (log.args.user) allUsers.add(log.args.user as `0x${string}`);
        }
      }
    }
  }

  return [...allUsers];
}
