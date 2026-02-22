"use client";

import { useEffect, useState } from "react";
import {
  collection,
  onSnapshot,
  getDocs,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Match } from "@/types/firestore";

interface BracketInfo {
  id: string;
  type?: string;
  matches: Match[];
}

function BracketMatchCard({ match }: { match: Match }) {
  const isCompleted = match.status === "completed";
  const winnerIsA = match.result?.winner === match.teamAId;
  const winnerIsB = match.result?.winner === match.teamBId;

  return (
    <div className="bg-white rounded-lg border border-gray-200 w-72 overflow-hidden">
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

interface BracketViewProps {
  tournamentId: string;
}

export default function BracketView({ tournamentId }: BracketViewProps) {
  const [brackets, setBrackets] = useState<BracketInfo[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function loadBrackets() {
      const bracketsSnap = await getDocs(
        collection(db, "tournaments", tournamentId, "brackets")
      );

      if (cancelled) return;

      const bracketList: BracketInfo[] = [];
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
            })) as Match[];

            setBrackets((prev) => {
              const next = prev.filter((b) => b.id !== bracketId);
              next.push({
                id: bracketId,
                type: bracketData.type,
                matches,
              });
              return next.sort((a, b) => a.id.localeCompare(b.id));
            });
            setLoading(false);
          }
        );

        unsubscribers.push(unsub);
        bracketList.push({
          id: bracketId,
          type: bracketData.type,
          matches: [],
        });
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
      {brackets.map((bracket) => (
        <div key={bracket.id}>
          <h3 className="text-sm font-bold text-muted mb-4 uppercase">
            {bracket.type === "upper"
              ? "上位トーナメント"
              : bracket.type === "lower"
              ? "下位トーナメント"
              : bracket.id}
          </h3>
          <div className="flex flex-wrap gap-4">
            {bracket.matches
              .sort((a, b) => (a.matchOrder ?? 0) - (b.matchOrder ?? 0))
              .map((m) => (
                <BracketMatchCard key={m.id} match={m} />
              ))}
          </div>
        </div>
      ))}
    </div>
  );
}
