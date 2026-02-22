"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Standing } from "@/types/firestore";

const courtLabels: Record<string, string> = {
  court_a: "A",
  court_b: "B",
  court_c: "C",
  court_d: "D",
};

const rankBadge: Record<number, string> = {
  1: "bg-yellow-400 text-yellow-900",
  2: "bg-gray-300 text-gray-800",
  3: "bg-amber-600 text-white",
};

function StandingsTable({
  courtId,
  standings,
}: {
  courtId: string;
  standings: Standing[];
}) {
  const sorted = [...standings].sort(
    (a, b) => (a.rank || 99) - (b.rank || 99)
  );
  const label = courtLabels[courtId] ?? courtId;

  return (
    <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div className="px-4 py-3 bg-gray-50 border-b border-gray-100">
        <h3 className="text-sm font-bold text-foreground">
          {label}コート 順位表
        </h3>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs text-muted border-b border-gray-100">
              <th className="px-3 py-2 text-center w-12">順位</th>
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
            {sorted.map((s) => (
              <tr
                key={s.teamId}
                className="border-b border-gray-50 hover:bg-gray-50 transition-colors"
              >
                <td className="px-3 py-2.5 text-center">
                  <span
                    className={`inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-bold ${
                      rankBadge[s.rank] ?? "bg-gray-100 text-gray-600"
                    }`}
                  >
                    {s.rank}
                  </span>
                </td>
                <td className="px-3 py-2.5 font-semibold text-foreground">
                  {s.teamName}
                </td>
                <td className="px-3 py-2.5 text-center">{s.wins}</td>
                <td className="px-3 py-2.5 text-center">{s.losses}</td>
                <td className="px-3 py-2.5 text-center">{s.draws}</td>
                <td className="px-3 py-2.5 text-center font-bold text-primary">
                  {s.matchPoints}
                </td>
                <td
                  className={`px-3 py-2.5 text-center font-medium ${
                    s.pointDiff > 0
                      ? "text-green-600"
                      : s.pointDiff < 0
                      ? "text-red-600"
                      : "text-gray-500"
                  }`}
                >
                  {s.pointDiff > 0 ? `+${s.pointDiff}` : s.pointDiff}
                </td>
                <td className="px-3 py-2.5 text-center">{s.totalPoints}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

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

  const sortedCourts = Array.from(data.entries()).sort(([a], [b]) =>
    a.localeCompare(b)
  );

  if (sortedCourts.length === 0 || sortedCourts.every(([, s]) => s.length === 0)) {
    return (
      <div className="text-center py-12 text-muted">
        まだ順位データがありません
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {sortedCourts.map(([courtId, standings]) => (
        <StandingsTable key={courtId} courtId={courtId} standings={standings} />
      ))}
    </div>
  );
}
