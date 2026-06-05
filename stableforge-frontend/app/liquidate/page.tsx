"use client";

import { useState, useEffect } from "react";
import {
  useAccount,
  usePublicClient,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { parseUnits, formatUnits, maxUint256 } from "viem";
import { sepolia } from "wagmi/chains";
import {
  ADDRESSES,
  SFC_ENGINE_ABI,
  ERC20_ABI,
  COLLATERAL_TOKENS,
} from "@/lib/contracts";
import { fetchAllDepositors } from "@/lib/fetchLogs";
import type { CollateralToken } from "@/lib/contracts";
import {
  formatUsd,
  formatSfc,
  formatHealthFactor,
  getHealthFactorStatus,
  shortenAddress,
} from "@/lib/utils";
import { PageHeader } from "@/components/PageHeader";
import { TxStatus } from "@/components/TxStatus";
import { HealthFactorBadge } from "@/components/HealthFactorBadge";
import { AlertTriangle, ChevronDown, ChevronUp } from "lucide-react";

interface UserPosition {
  address: `0x${string}`;
  healthFactor: bigint;
  totalDscMinted: bigint;
  collateralValueInUsd: bigint;
  wethBalance: bigint;
  wbtcBalance: bigint;
}

export default function LiquidatePage() {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient({ chainId: sepolia.id });

  const [positions, setPositions] = useState<UserPosition[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedPosition, setSelectedPosition] = useState<UserPosition | null>(
    null,
  );
  const [debtToCover, setDebtToCover] = useState("");
  const [collateralToken, setCollateralToken] = useState<CollateralToken>(
    COLLATERAL_TOKENS[0],
  );
  const [sortBy, setSortBy] = useState<"hf" | "debt">("hf");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");
  const [filterAtRisk, setFilterAtRisk] = useState(false);

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const { data: allowanceData } = useReadContracts({
    contracts: address
      ? [
          {
            address: ADDRESSES.StableForgeCoin,
            abi: ERC20_ABI,
            functionName: "allowance",
            args: [address, ADDRESSES.SFCEngine],
          },
        ]
      : [],
    query: { enabled: !!address },
  });
  const allowance = allowanceData?.[0]?.result as bigint | undefined;

  const debtBn = debtToCover ? parseUnits(debtToCover, 18) : 0n;
  const needsApproval =
    allowance !== undefined && debtBn > 0n && allowance < debtBn;
  const txStatus =
    isPending || isConfirming ? "pending" : isSuccess ? "success" : "idle";

  useEffect(() => {
    if (!publicClient) return;
    const load = async () => {
      setLoading(true);
      try {
        const uniqueUsers = await fetchAllDepositors(ADDRESSES.SFCEngine);

        const results = await Promise.all(
          uniqueUsers.map(async (user) => {
            try {
              const [accInfo, hf, weth, wbtc] = await Promise.all([
                publicClient.readContract({
                  address: ADDRESSES.SFCEngine,
                  abi: SFC_ENGINE_ABI,
                  functionName: "getAccountInformation",
                  args: [user],
                }),
                publicClient.readContract({
                  address: ADDRESSES.SFCEngine,
                  abi: SFC_ENGINE_ABI,
                  functionName: "getHealthFactor",
                  args: [user],
                }),
                publicClient.readContract({
                  address: ADDRESSES.SFCEngine,
                  abi: SFC_ENGINE_ABI,
                  functionName: "getCollateralBalanceOfUser",
                  args: [user, ADDRESSES.WETH],
                }),
                publicClient.readContract({
                  address: ADDRESSES.SFCEngine,
                  abi: SFC_ENGINE_ABI,
                  functionName: "getCollateralBalanceOfUser",
                  args: [user, ADDRESSES.WBTC],
                }),
              ]);
              const [totalDscMinted, collateralValueInUsd] = accInfo as [
                bigint,
                bigint,
              ];
              return {
                address: user,
                healthFactor: hf as bigint,
                totalDscMinted,
                collateralValueInUsd,
                wethBalance: weth as bigint,
                wbtcBalance: wbtc as bigint,
              };
            } catch {
              return null;
            }
          }),
        );

        setPositions(results.filter(Boolean) as UserPosition[]);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [publicClient]);

  const sorted = [...positions]
    .filter((p) =>
      filterAtRisk
        ? parseFloat(formatUnits(p.healthFactor, 18)) < 1.5 &&
          p.totalDscMinted > 0n
        : true,
    )
    .sort((a, b) => {
      const aVal =
        sortBy === "hf" ? Number(a.healthFactor) : Number(a.totalDscMinted);
      const bVal =
        sortBy === "hf" ? Number(b.healthFactor) : Number(b.totalDscMinted);
      return sortDir === "asc" ? aVal - bVal : bVal - aVal;
    });

  const handleSort = (col: "hf" | "debt") => {
    if (sortBy === col) setSortDir((d) => (d === "asc" ? "desc" : "asc"));
    else {
      setSortBy(col);
      setSortDir("asc");
    }
  };

  const handleApprove = () => {
    writeContract({
      address: ADDRESSES.StableForgeCoin,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [ADDRESSES.SFCEngine, maxUint256],
    });
  };

  const handleLiquidate = () => {
    if (!selectedPosition || !debtToCover) return;
    writeContract({
      address: ADDRESSES.SFCEngine,
      abi: SFC_ENGINE_ABI,
      functionName: "liquidate",
      args: [collateralToken.address, selectedPosition.address, debtBn],
    });
  };

  const SortIcon = ({ col }: { col: "hf" | "debt" }) => (
    <span style={{ marginLeft: 4, opacity: sortBy === col ? 1 : 0.3 }}>
      {sortBy === col && sortDir === "asc" ? (
        <ChevronUp size={12} />
      ) : (
        <ChevronDown size={12} />
      )}
    </span>
  );

  return (
    <div style={{ maxWidth: "1280px", margin: "0 auto", padding: "40px 24px" }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
          marginBottom: "32px",
        }}
      >
        <PageHeader
          tag="Liquidation"
          title="Liquidate Positions"
          subtitle="Browse at-risk positions. Earn a 10% bonus by liquidating undercollateralized users."
        />
        <div
          style={{
            display: "flex",
            gap: "8px",
            alignItems: "center",
            flexShrink: 0,
          }}
        >
          <button
            onClick={() => setFilterAtRisk(!filterAtRisk)}
            className={filterAtRisk ? "btn-secondary" : "btn-ghost"}
            style={{
              fontSize: "12px",
              display: "flex",
              alignItems: "center",
              gap: "6px",
            }}
          >
            <AlertTriangle size={12} /> At Risk Only
          </button>
        </div>
      </div>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: selectedPosition ? "1fr 380px" : "1fr",
          gap: "24px",
        }}
      >
        {/* Table */}
        <div className="card" style={{ overflow: "hidden" }}>
          {loading ? (
            <div
              style={{
                padding: "60px",
                textAlign: "center",
                color: "var(--text-muted)",
              }}
            >
              <div style={{ fontFamily: "var(--font-mono)", fontSize: "13px" }}>
                Scanning on-chain events…
              </div>
              <div
                style={{
                  marginTop: "12px",
                  display: "flex",
                  gap: "8px",
                  justifyContent: "center",
                }}
              >
                {[1, 2, 3].map((i) => (
                  <div
                    key={i}
                    className="shimmer"
                    style={{
                      width: "8px",
                      height: "8px",
                      borderRadius: "50%",
                      animationDelay: `${i * 0.2}s`,
                    }}
                  />
                ))}
              </div>
            </div>
          ) : sorted.length === 0 ? (
            <div
              style={{
                padding: "60px",
                textAlign: "center",
                color: "var(--text-muted)",
                fontFamily: "var(--font-mono)",
                fontSize: "13px",
              }}
            >
              No positions found.
            </div>
          ) : (
            <table className="sf-table">
              <thead>
                <tr>
                  <th>User</th>
                  <th
                    style={{ cursor: "pointer" }}
                    onClick={() => handleSort("hf")}
                  >
                    <span
                      style={{ display: "inline-flex", alignItems: "center" }}
                    >
                      Health Factor <SortIcon col="hf" />
                    </span>
                  </th>
                  <th
                    style={{ cursor: "pointer" }}
                    onClick={() => handleSort("debt")}
                  >
                    <span
                      style={{ display: "inline-flex", alignItems: "center" }}
                    >
                      SFC Debt <SortIcon col="debt" />
                    </span>
                  </th>
                  <th>Collateral Value</th>
                  <th>Action</th>
                </tr>
              </thead>
              <tbody>
                {sorted.map((pos) => {
                  const status = getHealthFactorStatus(pos.healthFactor);
                  const isSelected = selectedPosition?.address === pos.address;
                  return (
                    <tr
                      key={pos.address}
                      onClick={() =>
                        setSelectedPosition(isSelected ? null : pos)
                      }
                      style={{
                        background: isSelected
                          ? "var(--accent-glow)"
                          : undefined,
                      }}
                    >
                      <td
                        style={{
                          fontFamily: "var(--font-mono)",
                          fontSize: "13px",
                        }}
                      >
                        {shortenAddress(pos.address)}
                      </td>
                      <td>
                        <HealthFactorBadge hf={pos.healthFactor} />
                      </td>
                      <td style={{ color: "var(--text-primary)" }}>
                        {formatSfc(pos.totalDscMinted)} SFC
                      </td>
                      <td>{formatUsd(pos.collateralValueInUsd)}</td>
                      <td>
                        {status === "danger" ||
                        (status === "warning" &&
                          parseFloat(formatHealthFactor(pos.healthFactor)) <
                            1.0) ? (
                          <button
                            className="btn-secondary"
                            style={{
                              fontSize: "11px",
                              padding: "5px 12px",
                              background: "var(--danger-bg)",
                              color: "var(--danger)",
                              borderColor: "rgba(248,113,113,0.3)",
                            }}
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedPosition(pos);
                            }}
                          >
                            Liquidate
                          </button>
                        ) : (
                          <span
                            style={{
                              fontSize: "11px",
                              color: "var(--text-muted)",
                            }}
                          >
                            Safe
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* Liquidation panel */}
        {selectedPosition && (
          <div
            style={{ display: "flex", flexDirection: "column", gap: "16px" }}
          >
            <div className="card" style={{ overflow: "hidden" }}>
              <div
                style={{
                  padding: "16px 20px",
                  borderBottom: "1px solid var(--border)",
                }}
              >
                <div
                  style={{
                    fontSize: "11px",
                    fontWeight: 600,
                    letterSpacing: "0.08em",
                    textTransform: "uppercase",
                    color: "var(--text-muted)",
                    marginBottom: "4px",
                  }}
                >
                  Selected Position
                </div>
                <div
                  style={{
                    fontFamily: "var(--font-mono)",
                    fontSize: "12px",
                    color: "var(--text-primary)",
                  }}
                >
                  {selectedPosition.address}
                </div>
              </div>

              <div style={{ padding: "16px 20px" }}>
                {[
                  {
                    label: "Health Factor",
                    value: (
                      <HealthFactorBadge hf={selectedPosition.healthFactor} />
                    ),
                  },
                  {
                    label: "SFC Debt",
                    value: `${formatSfc(selectedPosition.totalDscMinted)} SFC`,
                  },
                  {
                    label: "Collateral Value",
                    value: formatUsd(selectedPosition.collateralValueInUsd),
                  },
                  {
                    label: "WETH Deposited",
                    value: `${formatUnits(selectedPosition.wethBalance, 18).slice(0, 8)} WETH`,
                  },
                  {
                    label: "WBTC Deposited",
                    value: `${formatUnits(selectedPosition.wbtcBalance, 8).slice(0, 8)} WBTC`,
                  },
                ].map(({ label, value }) => (
                  <div
                    key={label}
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      padding: "8px 0",
                      borderBottom: "1px solid var(--border)",
                      fontSize: "12px",
                    }}
                  >
                    <span style={{ color: "var(--text-secondary)" }}>
                      {label}
                    </span>
                    <span
                      style={{
                        fontFamily:
                          typeof value === "string"
                            ? "var(--font-mono)"
                            : undefined,
                        color: "var(--text-primary)",
                      }}
                    >
                      {value}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="card" style={{ padding: "20px" }}>
              <div
                style={{
                  fontSize: "13px",
                  fontWeight: 600,
                  color: "var(--text-primary)",
                  marginBottom: "16px",
                }}
              >
                Liquidate Position
              </div>

              <div style={{ marginBottom: "14px" }}>
                <label
                  style={{
                    fontSize: "11px",
                    fontWeight: 600,
                    letterSpacing: "0.06em",
                    textTransform: "uppercase",
                    color: "var(--text-muted)",
                    display: "block",
                    marginBottom: "8px",
                  }}
                >
                  Receive Collateral
                </label>
                <select
                  className="sf-select"
                  value={collateralToken.symbol}
                  onChange={(e) =>
                    setCollateralToken(
                      COLLATERAL_TOKENS.find(
                        (t) => t.symbol === e.target.value,
                      ) || COLLATERAL_TOKENS[0],
                    )
                  }
                >
                  {COLLATERAL_TOKENS.map((t) => (
                    <option key={t.symbol} value={t.symbol}>
                      {t.symbol} — {t.name}
                    </option>
                  ))}
                </select>
              </div>

              <div style={{ marginBottom: "16px" }}>
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    marginBottom: "8px",
                  }}
                >
                  <label
                    style={{
                      fontSize: "11px",
                      fontWeight: 600,
                      letterSpacing: "0.06em",
                      textTransform: "uppercase",
                      color: "var(--text-muted)",
                    }}
                  >
                    Debt to Cover
                  </label>
                  <button
                    onClick={() =>
                      setDebtToCover(
                        (
                          Number(selectedPosition.totalDscMinted) / 1e18
                        ).toString(),
                      )
                    }
                    style={{
                      fontSize: "11px",
                      color: "var(--accent)",
                      background: "none",
                      border: "none",
                      cursor: "pointer",
                      fontFamily: "var(--font-mono)",
                    }}
                  >
                    Full: {formatSfc(selectedPosition.totalDscMinted)} SFC
                  </button>
                </div>
                <div style={{ position: "relative" }}>
                  <input
                    className="sf-input"
                    type="number"
                    placeholder="0.0"
                    value={debtToCover}
                    onChange={(e) => setDebtToCover(e.target.value)}
                    style={{ paddingRight: "44px" }}
                  />
                  <span
                    style={{
                      position: "absolute",
                      right: "14px",
                      top: "50%",
                      transform: "translateY(-50%)",
                      fontSize: "12px",
                      fontWeight: 600,
                      color: "var(--text-muted)",
                    }}
                  >
                    SFC
                  </span>
                </div>
              </div>

              <div
                className="alert alert-info"
                style={{ marginBottom: "16px", fontSize: "12px" }}
              >
                <span>🎯</span>
                <span>
                  You receive {collateralToken.symbol} worth{" "}
                  <strong>110%</strong> of the debt you cover.
                </span>
              </div>

              <TxStatus
                status={txStatus}
                hash={hash}
                successMessage="Liquidation successful!"
              />

              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: "10px",
                  marginTop: txStatus !== "idle" ? "12px" : "0",
                }}
              >
                {needsApproval && (
                  <button
                    className="btn-secondary"
                    onClick={handleApprove}
                    disabled={isPending || isConfirming}
                    style={{ width: "100%", justifyContent: "center" }}
                  >
                    {isPending || isConfirming ? "Approving…" : "Approve SFC"}
                  </button>
                )}
                <button
                  className="btn-primary"
                  onClick={handleLiquidate}
                  disabled={
                    !debtToCover || needsApproval || isPending || isConfirming
                  }
                  style={{
                    width: "100%",
                    justifyContent: "center",
                    background: "var(--danger)",
                  }}
                >
                  {isPending || isConfirming
                    ? "Liquidating…"
                    : "Liquidate Position"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
