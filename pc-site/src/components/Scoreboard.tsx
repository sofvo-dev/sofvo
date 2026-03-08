"use client";

import { useEffect, useState } from "react";
import {
  collection,
  onSnapshot,
  query,
  orderBy,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Match } from "@/types/firestore";

/** court_1 → "A", court_2 → "B", ... */
function getCourtLabel(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return courtId;
  return String.fromCharCode(64 + num);
}

const courtBorderColors = [
  "border-l-[#1B3A5C]",   // A - navy
  "border-l-[#D32F2F]",   // B - red
  "border-l-[#2E7D32]",   // C - green
  "border-l-[#7B1FA2]",   // D - purple
  "border-l-[#E65100]",   // E - orange
  "border-l-[#0277BD]",   // F - light blue
  "border-l-[#4E342E]",   // G - brown
  "border-l-[#00695C]",   // H - teal
];

function getCourtBorderColor(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return "border-l-gray-400";
  return courtBorderColors[(num - 1) % courtBorderColors.length];
}

function MatchCard({ match }: { match: Match }) {
  const isLive =
    match.status !== "completed" &&
    match.sets?.some((s) => s.a > 0 || s.b > 0);
  const isCompleted = match.status === "completed";
  const courtLabel = getCourtLabel(match.courtId);
  const borderColor = getCourtBorderColor(match.courtId);

  return (
    <div
      className={`bg-white rounded-lg border border-gray-200 border-l-4 ${borderColor} overflow-hidden ${
        isLive ? "ring-2 ring-green-400/50" : ""
      }`}
    >
      {/* ヘッダー */}
      <div className="flex items-center justify-between px-4 py-2 bg-gray-50 border-b border-gray-100">
        <span className="text-xs font-bold text-muted">
          {courtLabel}コート 第{match.matchOrder}試合
        </span>
        {isLive && (
          <span className="flex items-center gap-1 text-xs font-semibold text-green-600">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-live-pulse" />
            LIVE
          </span>
        )}
        {isCompleted && (
          <span className="text-xs font-semibold text-gray-500">終了</span>
        )}
        {!isLive && !isCompleted && (
          <span className="text-xs text-gray-400">待機中</span>
        )}
      </div>

      {/* スコア */}
      <div className="px-4 py-3">
        <div className="flex items-center justify-between mb-1">
          <span
            className={`text-sm font-bold truncate max-w-[40%] ${
              isCompleted && match.result?.winner === match.teamAId
                ? "text-[#1B3A5C]"
                : isCompleted && match.result?.winner === match.teamBId
                ? "text-gray-400"
                : "text-foreground"
            }`}
          >
            {match.teamAName}
          </span>
          <div className="flex items-center gap-2">
            {match.sets?.map((s, i) => (
              <div
                key={i}
                className="text-center min-w-[32px]"
              >
                <div className="text-[10px] text-muted mb-0.5">
                  S{i + 1}
                </div>
                <div
                  className={`text-sm font-bold ${
                    s.a > s.b ? "text-[#1B3A5C]" : s.a < s.b ? "text-gray-400" : "text-foreground"
                  }`}
                >
                  {s.a}
                </div>
              </div>
            ))}
            {match.result && (
              <div className="text-center min-w-[32px] border-l border-gray-200 pl-2">
                <div className="text-[10px] text-muted mb-0.5">SET</div>
                <div className={`text-sm font-bold ${match.result.setsA > match.result.setsB ? "text-[#1B3A5C]" : "text-gray-400"}`}>
                  {match.result.setsA}
                </div>
              </div>
            )}
          </div>
        </div>
        <div className="flex items-center justify-between">
          <span
            className={`text-sm font-bold truncate max-w-[40%] ${
              isCompleted && match.result?.winner === match.teamBId
                ? "text-[#D32F2F]"
                : isCompleted && match.result?.winner === match.teamAId
                ? "text-gray-400"
                : "text-foreground"
            }`}
          >
            {match.teamBName}
          </span>
          <div className="flex items-center gap-2">
            {match.sets?.map((s, i) => (
              <div key={i} className="text-center min-w-[32px]">
                <div className="invisible text-[10px]">S</div>
                <div
                  className={`text-sm font-bold ${
                    s.b > s.a ? "text-[#D32F2F]" : s.b < s.a ? "text-gray-400" : "text-foreground"
                  }`}
                >
                  {s.b}
                </div>
              </div>
            ))}
            {match.result && (
              <div className="text-center min-w-[32px] border-l border-gray-200 pl-2">
                <div className="invisible text-[10px]">S</div>
                <div className={`text-sm font-bold ${match.result.setsB > match.result.setsA ? "text-[#D32F2F]" : "text-gray-400"}`}>
                  {match.result.setsB}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

interface ScoreboardProps {
  tournamentId: string;
  roundId: string;
}

export default function Scoreboard({ tournamentId, roundId }: ScoreboardProps) {
  const [matches, setMatches] = useState<Match[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(
      collection(
        db,
        "tournaments",
        tournamentId,
        "rounds",
        roundId,
        "matches"
      ),
      orderBy("courtNumber"),
      orderBy("matchOrder")
    );

    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Match[];
      setMatches(list);
      setLoading(false);
    });

    return () => unsub();
  }, [tournamentId, roundId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (matches.length === 0) {
    return (
      <div className="text-center py-12 text-muted">
        まだ試合が生成されていません
      </div>
    );
  }

  // コートごとにグルーピング
  const courts = new Map<string, Match[]>();
  for (const m of matches) {
    const key = m.courtId;
    if (!courts.has(key)) courts.set(key, []);
    courts.get(key)!.push(m);
  }

  const completedCount = matches.filter((m) => m.status === "completed").length;
  const totalCount = matches.length;

  return (
    <div>
      {/* 進行バー */}
      <div className="mb-6 bg-white rounded-lg border border-gray-200 p-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-semibold text-foreground">
            試合進行状況
          </span>
          <span className="text-sm text-muted">
            {completedCount}/{totalCount} 完了
          </span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-primary rounded-full h-2 transition-all duration-500"
            style={{
              width: `${totalCount > 0 ? (completedCount / totalCount) * 100 : 0}%`,
            }}
          />
        </div>
      </div>

      {/* コート別グリッド */}
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
        {Array.from(courts.entries())
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([courtId, courtMatches]) => (
            <div key={courtId}>
              <h3 className="text-sm font-bold text-foreground mb-3">
                {getCourtLabel(courtId)}コート
              </h3>
              <div className="space-y-3">
                {courtMatches.map((m) => (
                  <MatchCard key={m.id} match={m} />
                ))}
              </div>
            </div>
          ))}
      </div>
    </div>
  );
}
