"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface MatchHistory {
  id: string;
  tournamentId?: string;
  tournamentName?: string;
  opponentName?: string;
  rank?: number;
  points?: number;
  result?: string;
  date?: string;
  createdAt?: unknown;
}

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleDateString("ja-JP");
}

export default function MatchHistoryPage() {
  const { user } = useAuth();
  const [items, setItems] = useState<MatchHistory[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, "users", user.uid, "tournamentHistory"),
      orderBy("createdAt", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as MatchHistory)));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [user]);

  const championships = items.filter((i) => i.rank === 1).length;
  const totalPoints = items.reduce((s, i) => s + (i.points ?? 0), 0);

  if (!user) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ログインが必要です</p>
        <Link href="/login" className="inline-block mt-4 text-primary text-sm hover:underline">ログイン</Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto animate-fade-in">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/mypage" className="hover:text-primary transition-colors">マイページ</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">試合履歴</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">試合・大会履歴</h1>
      <p className="text-sm text-muted mb-6">参加した大会の結果と獲得ポイントの履歴</p>

      <div className="grid grid-cols-3 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-200 p-4 text-center">
          <div className="text-2xl font-bold text-foreground">{items.length}</div>
          <div className="text-xs text-muted mt-0.5">参加大会</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4 text-center">
          <div className="text-2xl font-bold text-amber-600">{championships}</div>
          <div className="text-xs text-muted mt-0.5">優勝</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4 text-center">
          <div className="text-2xl font-bold text-accent">{totalPoints.toLocaleString()}</div>
          <div className="text-xs text-muted mt-0.5">通算Pt</div>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted mb-2">まだ大会に参加していません</p>
          <Link href="/tournaments" className="inline-block text-xs text-primary font-medium hover:underline">
            大会を探す
          </Link>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50/50 border-b border-gray-200">
              <tr>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">大会</th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">日付</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">順位</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">Pt</th>
              </tr>
            </thead>
            <tbody>
              {items.map((m) => (
                <tr key={m.id} className="border-b border-gray-100 hover:bg-gray-50/50">
                  <td className="px-5 py-3">
                    {m.tournamentId ? (
                      <Link href={`/tournament/${m.tournamentId}`} className="text-sm font-medium text-foreground hover:text-primary">
                        {m.tournamentName}
                      </Link>
                    ) : (
                      <span className="text-sm text-foreground">{m.tournamentName ?? "-"}</span>
                    )}
                  </td>
                  <td className="px-5 py-3 text-xs text-muted">{m.date || formatDate(m.createdAt)}</td>
                  <td className="px-5 py-3 text-right">
                    {m.rank ? (
                      <span className={`text-sm font-bold ${m.rank === 1 ? "text-amber-600" : "text-foreground"}`}>
                        {m.rank}位
                      </span>
                    ) : (
                      "-"
                    )}
                  </td>
                  <td className="px-5 py-3 text-right text-sm font-semibold text-accent">
                    {m.points != null ? `+${m.points}` : "-"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
