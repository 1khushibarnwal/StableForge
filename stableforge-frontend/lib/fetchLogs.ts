import { createPublicClient, http, parseAbiItem } from "viem";
import { sepolia } from "viem/chains";

import "dotenv/config";

export const DEPLOY_BLOCK = BigInt(process.env.DEPLOY_BLOCK || "10983674");

const client = createPublicClient({
  chain: sepolia,
  transport: http(),
});

const CHUNK_SIZE = 9_000n;
const PARALLEL_CHUNKS = 5;

const COLLATERAL_DEPOSITED_EVENT = parseAbiItem(
  "event CollateralDeposited(address indexed user, address indexed token, uint256 amount)",
);

export async function fetchAllDepositors(
  contractAddress: `0x${string}`,
): Promise<`0x${string}`[]> {
  const latestBlock = await client.getBlockNumber();

  const chunks: { from: bigint; to: bigint }[] = [];
  for (let from = DEPLOY_BLOCK; from <= latestBlock; from += CHUNK_SIZE) {
    chunks.push({
      from,
      to:
        from + CHUNK_SIZE - 1n < latestBlock
          ? from + CHUNK_SIZE - 1n
          : latestBlock,
    });
  }

  const users = new Set<`0x${string}`>();

  for (let i = 0; i < chunks.length; i += PARALLEL_CHUNKS) {
    const batch = chunks.slice(i, i + PARALLEL_CHUNKS);
    const results = await Promise.allSettled(
      batch.map(({ from, to }) =>
        client.getLogs({
          address: contractAddress,
          event: COLLATERAL_DEPOSITED_EVENT,
          fromBlock: from,
          toBlock: to,
        }),
      ),
    );

    for (const result of results) {
      if (result.status === "fulfilled") {
        for (const log of result.value) {
          if (log.args.user) users.add(log.args.user);
        }
      }
    }
  }

  return Array.from(users);
}
