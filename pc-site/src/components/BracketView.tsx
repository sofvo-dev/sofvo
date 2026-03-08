"use client";

import { useEffect, useState } from "react";
import {
  collection,
  onSnapshot,
  getDocs,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Match } from "@/types/firestore";

/** Bracket match with round info from Firestore */
interface BracketMatchData extends Match {
  round?: string;
  matchNumber?: number;
  label?: string;
}

interface BracketInfo {
  id: string;
  bracketName?: string;
  rankRange?: string;
  teamCount?: number;
  type?: string;
  matches: BracketMatchData[];
}

/** Round key → display label mapping */
const ROUND_LABELS: Record<string, string> = {
  qf: "準々決勝",
  sf_winner: "準決勝（勝者）",
  sf_loser: "準決勝（敗者）",
  semi: "準決勝",
  final_1st: "決勝（1-2位）",
  final_3rd: "3位決定戦",
  final_5th: "5位決定戦",
  final_7th: "7位決定戦",
  final: "決勝",
  "round-robin": "総当たり",
  round1: "1回戦",
};

/** Round display order */
const ROUND_ORDER = [
  "qf",
  "sf_winner",
  "sf_loser",
  "semi",
  "final_1st",
  "final_3rd",
  "final_5th",
  "final_7th",
  "final",
  "round-robin",
  "round1",
];

function BracketMatchCard({ match }: { match: BracketMatchData }) {
  const isCompleted = match.status === "completed";
  const isWaiting = !match.teamAId && !match.teamBId;
  const winnerIsA = match.result?.winner === match.teamAId;
  const winnerIsB = match.result?.winner === match.teamBId;

  const teamRow = (
    name: string | undefined,
    teamId: string | undefined,
    sets: { a: number; b: number }[] | undefined,
    side: "a" | "b",
    isWinner: boolean,
  ) => {
    const isEmpty = !teamId;
    const displayName = name || (isEmpty ? (match.label ? match.label : "TBD") : "TBD");
    const setsWon = match.result ? (side === "a" ? match.result.setsA : match.result.setsB) : null;

    return (
      <div className={`flex items-center px-3 py-2 ${isCompleted && isWinner ? "bg-[#0F2440]/5" : ""}`}>
        {/* Winner indicator */}
        <div className="w-1 h-5 mr-2 rounded-full" style={{ background: isCompleted && isWinner ? "#C4A962" : "transparent" }} />
        {/* Team name */}
        <span className={`text-sm flex-1 truncate ${
          isEmpty ? "text-gray-300 italic text-xs" :
          isCompleted && isWinner ? "font-bold text-[#0F2440]" :
          isCompleted && !isWinner ? "text-gray-400" :
          "text-foreground font-medium"
        }`}>
          {displayName}
        </span>
        {/* Set scores */}
        {sets && sets.length > 0 && !isEmpty && (
          <div className="flex items-center gap-1 ml-2">
            {sets.map((s, i) => {
              const score = side === "a" ? s.a : s.b;
              const opponentScore = side === "a" ? s.b : s.a;
              return (
                <span key={i} className={`text-xs font-bold w-5 text-center ${
                  score > opponentScore ? "text-[#0F2440]" : "text-gray-400"
                }`}>
                  {score}
                </span>
              );
            })}
            {setsWon !== null && (
              <span className={`text-xs font-bold w-5 text-center border-l border-gray-200 pl-1 ${isWinner ? "text-[#C4A962]" : "text-gray-400"}`}>
                {setsWon}
              </span>
            )}
          </div>
        )}
        {/* Waiting badge */}
        {isWaiting && (
          <span className="text-[10px] text-gray-300 ml-auto">待機中</span>
        )}
      </div>
    );
  };

  return (
    <div className={`rounded-xl border overflow-hidden w-64 ${
      isCompleted ? "border-gray-200 bg-white" :
      isWaiting ? "border-dashed border-gray-200 bg-gray-50/50" :
      "border-gray-200 bg-white"
    }`}>
      {teamRow(match.teamAName, match.teamAId, match.sets, "a", winnerIsA)}
      <div className="border-t border-gray-100" />
      {teamRow(match.teamBName, match.teamBId, match.sets, "b", winnerIsB)}
    </div>
  );
}

/** Group matches by round and return sorted groups */
function groupByRound(matches: BracketMatchData[]) {
  const groups = new Map<string, BracketMatchData[]>();

  for (const m of matches) {
    const round = m.round ?? "unknown";
    if (!groups.has(round)) groups.set(round, []);
    groups.get(round)!.push(m);
  }

  // Sort groups by ROUND_ORDER
  const sortedKeys = [...groups.keys()].sort((a, b) => {
    const ia = ROUND_ORDER.indexOf(a);
    const ib = ROUND_ORDER.indexOf(b);
    return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib);
  });

  // Sort matches within each group by matchNumber
  return sortedKeys.map((key) => ({
    round: key,
    label: ROUND_LABELS[key] ?? key,
    matches: groups.get(key)!.sort(
      (a, b) => (a.matchNumber ?? 0) - (b.matchNumber ?? 0)
    ),
  }));
}

interface BracketViewProps {
  tournamentId: string;
}

export default function BracketView({ tournamentId }: BracketViewProps) {
  const [brackets, setBrackets] = useState<BracketInfo[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function loadBrackets() {
      let bracketsSnap;
      try {
        bracketsSnap = await getDocs(
          collection(db, "tournaments", tournamentId, "brackets")
        );
      } catch {
        setLoading(false);
        return;
      }

      if (cancelled) return;

      const unsubscribers: (() => void)[] = [];

      for (const bracketDoc of bracketsSnap.docs) {
        const bracketId = bracketDoc.id;
        const bracketData = bracketDoc.data();

        const unsub = onSnapshot(
          collection(
            db,
            "tournaments",
            tournamentId,
            "brackets",
            bracketId,
            "matches"
          ),
          (snap) => {
            const matches = snap.docs.map((d) => ({
              id: d.id,
              ...d.data(),
            })) as BracketMatchData[];

            setBrackets((prev) => {
              const next = prev.filter((b) => b.id !== bracketId);
              next.push({
                id: bracketId,
                bracketName: bracketData.bracketName,
                rankRange: bracketData.rankRange,
                teamCount: bracketData.teamCount,
                type: bracketData.type,
                matches,
              });
              return next.sort((a, b) => a.id.localeCompare(b.id));
            });
            setLoading(false);
          }
        );

        unsubscribers.push(unsub);
      }

      if (bracketsSnap.empty) {
        setLoading(false);
      }

      return () => {
        cancelled = true;
        unsubscribers.forEach((u) => u());
      };
    }

    const cleanupPromise = loadBrackets();
    return () => {
      cancelled = true;
      cleanupPromise.then((cleanup) => cleanup?.());
    };
  }, [tournamentId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (brackets.length === 0) {
    return (
      <div className="text-center py-12 text-muted">
        決勝トーナメントはまだ生成されていません
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {brackets.map((bracket) => {
        const roundGroups = groupByRound(bracket.matches);
        const completedCount = bracket.matches.filter(m => m.status === "completed").length;
        const totalCount = bracket.matches.length;

        return (
          <div key={bracket.id} className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
            {/* Bracket header */}
            <div className="gradient-navy px-5 py-3 flex items-center gap-3">
              <svg className="w-4 h-4 text-white/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-4.5A3.375 3.375 0 0012.75 10.5h-.75m-6 8.25a3 3 0 01-3-3V6.75m0 0A2.25 2.25 0 015.25 4.5h13.5A2.25 2.25 0 0121 6.75m-18 0v10.5" /></svg>
              <h3 className="text-sm font-bold text-white">
                {bracket.bracketName
                  ? `${bracket.bracketName}リーグ`
                  : bracket.id}
              </h3>
              {bracket.rankRange && (
                <span className="text-xs text-white/50 bg-white/10 px-2 py-0.5 rounded">
                  {bracket.rankRange}
                </span>
              )}
              {bracket.teamCount && (
                <span className="text-xs text-white/50">
                  {bracket.teamCount}チーム
                </span>
              )}
              <span className="text-xs text-white/40 ml-auto">
                {completedCount}/{totalCount} 完了
              </span>
            </div>

            {/* Rounds */}
            <div className="p-4 space-y-4">
              {roundGroups.map((group) => (
                <div key={group.round}>
                  <h4 className="text-xs font-bold text-muted mb-2 flex items-center gap-2">
                    <span className="w-1 h-3 rounded-full bg-[#C4A962]" />
                    {group.label}
                  </h4>
                  <div className="flex flex-wrap gap-3">
                    {group.matches.map((m) => (
                      <BracketMatchCard key={m.id} match={m} />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}
