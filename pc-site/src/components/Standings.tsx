"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Standing } from "@/types/firestore";

/** court_1 → "A", court_2 → "B", ... */
function getCourtLabel(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return courtId;
  return String.fromCharCode(64 + num);
}

const courtBgColors = [
  "bg-[#1B3A5C]",
  "bg-[#D32F2F]",
  "bg-[#2E7D32]",
  "bg-[#7B1FA2]",
  "bg-[#E65100]",
  "bg-[#0277BD]",
  "bg-[#4E342E]",
  "bg-[#00695C]",
];
function getCourtBg(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return "bg-gray-500";
  return courtBgColors[(num - 1) % courtBgColors.length];
}

const rankBadge: Record<number, string> = {
  1: "bg-yellow-400 text-yellow-900",
  2: "bg-gray-300 text-gray-800",
  3: "bg-amber-600 text-white",
};

interface StandingsProps {
  tournamentId: string;
  roundId: string;
  courtIds: string[];
}

export default function Standings({
  tournamentId,
  roundId,
  courtIds,
}: StandingsProps) {
  const [data, setData] = useState<Map<string, Standing[]>>(new Map());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (courtIds.length === 0) {
      setLoading(false);
      return;
    }

    const unsubscribers: (() => void)[] = [];

    for (const courtId of courtIds) {
      const colRef = collection(
        db,
        "tournaments",
        tournamentId,
        "rounds",
        roundId,
        "standings",
        courtId,
        "teams"
      );

      const unsub = onSnapshot(colRef, (snap) => {
        const teams = snap.docs.map((doc) => ({
          teamId: doc.id,
          ...doc.data(),
        })) as Standing[];

        setData((prev) => {
          const next = new Map(prev);
          next.set(courtId, teams);
          return next;
        });
        setLoading(false);
      });

      unsubscribers.push(unsub);
    }

    return () => unsubscribers.forEach((u) => u());
  }, [tournamentId, roundId, courtIds]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Merge all courts into one list
  const allTeams: (Standing & { courtId: string })[] = [];
  for (const [courtId, standings] of data.entries()) {
    for (const s of standings) {
      allTeams.push({ ...s, courtId });
    }
  }

  if (allTeams.length === 0) {
    return (
      <div className="text-center py-12 text-muted">
        まだ順位データがありません
      </div>
    );
  }

  // Sort: matchPoints desc → pointDiff desc → totalPoints desc
  allTeams.sort((a, b) =>
    b.matchPoints - a.matchPoints ||
    b.pointDiff - a.pointDiff ||
    b.totalPoints - a.totalPoints
  );

  return (
    <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs text-muted border-b border-gray-100 bg-gray-50">
              <th className="px-3 py-2 text-center w-12">順位</th>
              <th className="px-3 py-2 text-center w-12">コート</th>
              <th className="px-3 py-2 text-left">チーム</th>
              <th className="px-3 py-2 text-center">勝</th>
              <th className="px-3 py-2 text-center">敗</th>
              <th className="px-3 py-2 text-center">分</th>
              <th className="px-3 py-2 text-center">勝点</th>
              <th className="px-3 py-2 text-center">得失差</th>
              <th className="px-3 py-2 text-center">総得点</th>
            </tr>
          </thead>
          <tbody>
            {allTeams.map((s, idx) => (
              <tr
                key={`${s.courtId}-${s.teamId}`}
                className="border-b border-gray-50 hover:bg-gray-50 transition-colors"
              >
                <td className="px-3 py-2 text-center">
                  <span
                    className={`inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-bold ${
                      rankBadge[idx + 1] ?? "bg-gray-100 text-gray-600"
                    }`}
                  >
                    {idx + 1}
                  </span>
                </td>
                <td className="px-3 py-2 text-center">
                  <span className={`inline-flex items-center justify-center w-5 h-5 rounded text-[10px] font-bold text-white ${getCourtBg(s.courtId)}`}>
                    {getCourtLabel(s.courtId)}
                  </span>
                </td>
                <td className="px-3 py-2 font-semibold text-foreground">
                  {s.teamName}
                </td>
                <td className="px-3 py-2 text-center">{s.wins}</td>
                <td className="px-3 py-2 text-center">{s.losses}</td>
                <td className="px-3 py-2 text-center">{s.draws}</td>
                <td className="px-3 py-2 text-center font-bold text-primary">
                  {s.matchPoints}
                </td>
                <td
                  className={`px-3 py-2 text-center font-medium ${
                    s.pointDiff > 0
                      ? "text-green-600"
                      : s.pointDiff < 0
                      ? "text-red-600"
                      : "text-gray-500"
                  }`}
                >
                  {s.pointDiff > 0 ? `+${s.pointDiff}` : s.pointDiff}
                </td>
                <td className="px-3 py-2 text-center">{s.totalPoints}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
