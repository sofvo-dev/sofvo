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
  const isWaiting = match.status === "waiting";
  const winnerIsA = match.result?.winner === match.teamAId;
  const winnerIsB = match.result?.winner === match.teamBId;

  return (
    <div
      className={`bg-white rounded-lg border w-72 overflow-hidden ${
        isWaiting ? "border-gray-100 opacity-60" : "border-gray-200"
      }`}
    >
      {/* チームA */}
      <div
        className={`flex items-center justify-between px-3 py-2.5 border-b border-gray-100 ${
          isCompleted && winnerIsA ? "bg-blue-50" : ""
        }`}
      >
        <span
          className={`text-sm truncate max-w-[60%] ${
            isCompleted && winnerIsA
              ? "font-bold text-blue-700"
              : isWaiting && !match.teamAId
              ? "text-gray-400 italic"
              : "text-foreground"
          }`}
        >
          {match.teamAName || "TBD"}
        </span>
        <div className="flex items-center gap-2">
          {match.sets?.map((s, i) => (
            <span
              key={i}
              className={`text-sm font-bold w-6 text-center ${
                s.a > s.b ? "text-blue-600" : "text-gray-500"
              }`}
            >
              {s.a}
            </span>
          ))}
          {isCompleted && match.result && (
            <span className="text-sm font-bold text-foreground border-l border-gray-200 pl-2 w-6 text-center">
              {match.result.setsA}
            </span>
          )}
          {isWaiting && (
            <span className="text-xs text-gray-400">待機中</span>
          )}
        </div>
      </div>
      {/* チームB */}
      <div
        className={`flex items-center justify-between px-3 py-2.5 ${
          isCompleted && winnerIsB ? "bg-red-50" : ""
        }`}
      >
        <span
          className={`text-sm truncate max-w-[60%] ${
            isCompleted && winnerIsB
              ? "font-bold text-red-700"
              : isWaiting && !match.teamBId
              ? "text-gray-400 italic"
              : "text-foreground"
          }`}
        >
          {match.teamBName || "TBD"}
        </span>
        <div className="flex items-center gap-2">
          {match.sets?.map((s, i) => (
            <span
              key={i}
              className={`text-sm font-bold w-6 text-center ${
                s.b > s.a ? "text-red-600" : "text-gray-500"
              }`}
            >
              {s.b}
            </span>
          ))}
          {isCompleted && match.result && (
            <span className="text-sm font-bold text-foreground border-l border-gray-200 pl-2 w-6 text-center">
              {match.result.setsB}
            </span>
          )}
        </div>
      </div>
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
    <div className="space-y-10">
      {brackets.map((bracket) => {
        const roundGroups = groupByRound(bracket.matches);

        return (
          <div key={bracket.id} className="space-y-4">
            {/* Bracket header: リーグ名 + 順位範囲 */}
            <div className="flex items-center gap-3">
              <h3 className="text-lg font-bold text-foreground">
                {bracket.bracketName
                  ? `${bracket.bracketName}リーグ`
                  : bracket.id}
              </h3>
              {bracket.rankRange && (
                <span className="text-sm text-muted bg-gray-100 px-2 py-0.5 rounded">
                  {bracket.rankRange}
                </span>
              )}
              {bracket.teamCount && (
                <span className="text-sm text-muted">
                  {bracket.teamCount}チーム
                </span>
              )}
            </div>

            {/* Matches grouped by round */}
            <div className="space-y-4">
              {roundGroups.map((group) => (
                <div key={group.round}>
                  <h4 className="text-sm font-semibold text-muted mb-2 border-b border-gray-100 pb-1">
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
