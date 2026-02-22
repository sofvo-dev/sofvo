"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import Header from "@/components/Header";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-500",
  "レディース": "bg-pink-500",
  "混合": "bg-green-500",
};

export default function HomePage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "live">("live");

  useEffect(() => {
    const q = query(collection(db, "tournaments"), orderBy("date", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Tournament[];
      setTournaments(list);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const liveStatuses = ["開催中", "決勝中"];
  const filtered =
    filter === "live"
      ? tournaments.filter(
          (t) =>
            liveStatuses.includes(t.status) || t.status.includes("完了")
        )
      : tournaments;

  return (
    <div className="min-h-screen">
      <Header />
      <main className="max-w-[1400px] mx-auto px-6 py-8">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-foreground mb-1">大会一覧</h1>
          <p className="text-sm text-muted">
            大会を選択してリアルタイムスコアボードを表示
          </p>
        </div>

        {/* フィルター */}
        <div className="flex gap-2 mb-6">
          <button
            onClick={() => setFilter("live")}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
              filter === "live"
                ? "bg-primary text-white"
                : "bg-white text-muted hover:bg-gray-100"
            }`}
          >
            開催中の大会
          </button>
          <button
            onClick={() => setFilter("all")}
            className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
              filter === "all"
                ? "bg-primary text-white"
                : "bg-white text-muted hover:bg-gray-100"
            }`}
          >
            すべて
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-20 text-muted">
            {filter === "live"
              ? "現在開催中の大会はありません"
              : "大会が見つかりません"}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filtered.map((t) => (
              <Link
                key={t.id}
                href={`/tournament/${t.id}`}
                className="block bg-white rounded-xl border border-gray-200 p-5 hover:shadow-lg hover:border-primary/30 transition-all group"
              >
                <div className="flex items-start justify-between mb-3">
                  <StatusBadge status={t.status} />
                  <span
                    className={`text-xs text-white px-2 py-0.5 rounded ${
                      typeColor[t.type] ?? "bg-gray-500"
                    }`}
                  >
                    {t.type}
                  </span>
                </div>
                <h2 className="text-lg font-bold text-foreground mb-2 group-hover:text-primary transition-colors">
                  {t.title}
                </h2>
                <div className="space-y-1 text-sm text-muted">
                  <div className="flex items-center gap-2">
                    <span>📅</span>
                    <span>{t.date}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span>📍</span>
                    <span>{t.location}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <span>👥</span>
                    <span>
                      {t.currentTeams ?? 0}/{t.maxTeams}チーム
                    </span>
                  </div>
                  {t.courts > 0 && (
                    <div className="flex items-center gap-2">
                      <span>🏐</span>
                      <span>{t.courts}コート</span>
                    </div>
                  )}
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
