"use client";

import { use, useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  getDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Match, SetScore, MatchResult } from "@/types/firestore";
import Link from "next/link";

export default function ScoreInputPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user } = useAuth();
  const [matches, setMatches] = useState<Match[]>([]);
  const [loading, setLoading] = useState(true);
  const [tournamentTitle, setTournamentTitle] = useState("");
  const [organizerId, setOrganizerId] = useState("");
  const [activeMatchId, setActiveMatchId] = useState<string | null>(null);
  const [scores, setScores] = useState<SetScore[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    async function loadTournament() {
      const snap = await getDoc(doc(db, "tournaments", id));
      if (snap.exists()) {
        const d = snap.data();
        setTournamentTitle(d.title ?? "");
        setOrganizerId(d.organizerId ?? "");
      }
    }
    loadTournament();
  }, [id]);

  useEffect(() => {
    const q = query(collection(db, "tournaments", id, "matches"), orderBy("matchOrder", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setMatches(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Match)));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [id]);

  const startEdit = (m: Match) => {
    setActiveMatchId(m.id);
    setScores(m.sets.length > 0 ? m.sets : [{ a: 0, b: 0 }]);
  };

  const updateScore = (idx: number, side: "a" | "b", val: number) => {
    setScores((prev) => prev.map((s, i) => (i === idx ? { ...s, [side]: Math.max(0, Math.min(99, val)) } : s)));
  };

  const addSet = () => setScores((prev) => [...prev, { a: 0, b: 0 }]);
  const removeSet = (idx: number) => setScores((prev) => prev.filter((_, i) => i !== idx));

  const saveMatch = async (m: Match, status: "pending" | "completed") => {
    setSaving(true);
    try {
      let result: MatchResult | undefined;
      if (status === "completed") {
        let setsA = 0, setsB = 0, totalPointsA = 0, totalPointsB = 0;
        scores.forEach((s) => {
          totalPointsA += s.a;
          totalPointsB += s.b;
          if (s.a > s.b) setsA++;
          else if (s.b > s.a) setsB++;
        });
        const winner = setsA > setsB ? m.teamAId : setsB > setsA ? m.teamBId : "draw";
        result = { setsA, setsB, totalPointsA, totalPointsB, winner };
      }
      await updateDoc(doc(db, "tournaments", id, "matches", m.id), {
        sets: scores,
        status,
        ...(result ? { result } : {}),
        updatedAt: serverTimestamp(),
      });
      setActiveMatchId(null);
    } catch {
      alert("スコアの保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const isOrganizer = user?.uid === organizerId;

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!isOrganizer) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">主催者のみがスコア入力できます</p>
        <Link href={`/tournament/${id}`} className="inline-block mt-4 text-primary text-sm hover:underline">
          大会詳細に戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto animate-fade-in">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href={`/tournament/${id}`} className="hover:text-primary transition-colors">
          {tournamentTitle || "大会"}
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">スコア入力</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">スコア入力</h1>
      <p className="text-sm text-muted mb-6">試合ごとにセットスコアを入力して結果を確定します</p>

      {matches.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">試合がまだ組まれていません</p>
        </div>
      ) : (
        <div className="space-y-3">
          {matches.map((m) => {
            const editing = activeMatchId === m.id;
            const done = m.status === "completed";
            return (
              <div key={m.id} className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="flex items-center justify-between gap-3 mb-3">
                  <div className="text-xs text-muted">
                    第{m.matchOrder}試合 · コート{m.courtNumber}
                    {done && (
                      <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                        確定済
                      </span>
                    )}
                  </div>
                  {!editing && (
                    <button
                      onClick={() => startEdit(m)}
                      className="text-xs text-primary hover:underline"
                    >
                      {done ? "再編集" : "スコア入力"}
                    </button>
                  )}
                </div>

                <div className="grid grid-cols-[1fr_auto_1fr] items-center gap-4">
                  <div className="text-right">
                    <div className="text-sm font-bold text-foreground">{m.teamAName}</div>
                  </div>
                  <div className="text-lg font-bold text-muted">vs</div>
                  <div>
                    <div className="text-sm font-bold text-foreground">{m.teamBName}</div>
                  </div>
                </div>

                {editing ? (
                  <div className="mt-4 space-y-2">
                    {scores.map((s, i) => (
                      <div key={i} className="flex items-center gap-3 justify-center">
                        <span className="text-xs text-muted w-16">第{i + 1}セット</span>
                        <input
                          type="number"
                          min={0}
                          max={99}
                          value={s.a}
                          onChange={(e) => updateScore(i, "a", Number(e.target.value))}
                          className="w-16 px-2 py-1.5 border border-gray-300 rounded-lg text-sm text-center"
                        />
                        <span className="text-muted">-</span>
                        <input
                          type="number"
                          min={0}
                          max={99}
                          value={s.b}
                          onChange={(e) => updateScore(i, "b", Number(e.target.value))}
                          className="w-16 px-2 py-1.5 border border-gray-300 rounded-lg text-sm text-center"
                        />
                        {scores.length > 1 && (
                          <button
                            onClick={() => removeSet(i)}
                            className="text-xs text-error hover:underline"
                          >
                            削除
                          </button>
                        )}
                      </div>
                    ))}
                    <div className="flex items-center justify-center gap-3 pt-3 border-t border-gray-100 mt-3">
                      <button
                        onClick={addSet}
                        className="text-xs text-primary hover:underline"
                      >
                        + セット追加
                      </button>
                      <button
                        onClick={() => saveMatch(m, "pending")}
                        disabled={saving}
                        className="px-4 py-1.5 border border-gray-300 rounded-lg text-xs font-medium text-muted hover:text-foreground disabled:opacity-50"
                      >
                        下書き保存
                      </button>
                      <button
                        onClick={() => saveMatch(m, "completed")}
                        disabled={saving}
                        className="px-4 py-1.5 bg-primary text-white rounded-lg text-xs font-medium hover:bg-primary-dark disabled:opacity-50"
                      >
                        {saving ? "保存中..." : "結果を確定"}
                      </button>
                      <button
                        onClick={() => setActiveMatchId(null)}
                        className="text-xs text-muted hover:text-foreground"
                      >
                        キャンセル
                      </button>
                    </div>
                  </div>
                ) : m.sets.length > 0 ? (
                  <div className="mt-3 flex items-center justify-center gap-4 text-sm">
                    {m.sets.map((s, i) => (
                      <span key={i} className="text-muted">
                        <span className="font-semibold text-foreground">{s.a}</span>-
                        <span className="font-semibold text-foreground">{s.b}</span>
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
