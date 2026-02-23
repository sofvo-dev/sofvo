"use client";

import { useEffect, useState } from "react";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-500",
  "レディース": "bg-pink-500",
  "混合": "bg-green-500",
};

const statusFilters = ["すべて", "募集中", "準備中", "開催中", "決勝中", "終了"];

export default function TournamentsPage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("すべて");
  const [typeFilter, setTypeFilter] = useState("すべて");
  const [areaFilter, setAreaFilter] = useState("");

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

  const filtered = tournaments.filter((t) => {
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      const matchesSearch =
        t.title.toLowerCase().includes(q) ||
        t.location.toLowerCase().includes(q) ||
        (t.organizerName ?? "").toLowerCase().includes(q);
      if (!matchesSearch) return false;
    }
    if (statusFilter !== "すべて") {
      if (statusFilter === "開催中") {
        if (!["開催中"].includes(t.status) && !t.status.includes("完了")) return false;
      } else if (t.status !== statusFilter) {
        return false;
      }
    }
    if (typeFilter !== "すべて" && t.type !== typeFilter) return false;
    if (areaFilter && t.area && !t.area.includes(areaFilter)) return false;
    return true;
  });

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会一覧</h1>
          <p className="text-sm text-muted mt-1">すべての大会を検索・閲覧</p>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
        <div className="flex flex-wrap gap-4">
          {/* Search */}
          <div className="flex-1 min-w-[240px]">
            <div className="relative">
              <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              <input
                type="search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="大会名、会場名で検索..."
                className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
          >
            {statusFilters.map((s) => (
              <option key={s} value={s}>{s === "すべて" ? "ステータス: すべて" : s}</option>
            ))}
          </select>

          {/* Type Filter */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
          >
            <option value="すべて">種別: すべて</option>
            <option value="メンズ">メンズ</option>
            <option value="レディース">レディース</option>
            <option value="混合">混合</option>
          </select>
        </div>
      </div>

      {/* Results count */}
      <div className="text-sm text-muted mb-4">
        {filtered.length}件の大会
      </div>

      {/* Tournament List */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔍</div>
          <h3 className="text-lg font-bold text-foreground mb-2">該当する大会がありません</h3>
          <p className="text-sm text-muted">検索条件を変更してください</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((t) => (
            <Link
              key={t.id}
              href={`/tournament/${t.id}`}
              className="flex items-center gap-6 bg-white rounded-xl border border-gray-200 p-5 hover:shadow-lg hover:border-primary/30 transition-all group"
            >
              {/* Status */}
              <div className="flex-shrink-0">
                <StatusBadge status={t.status} />
              </div>

              {/* Main info */}
              <div className="flex-1 min-w-0">
                <h3 className="text-base font-bold text-foreground group-hover:text-primary transition-colors truncate">
                  {t.title}
                </h3>
                <div className="flex flex-wrap gap-4 mt-1 text-sm text-muted">
                  <span>{t.date}</span>
                  <span>{t.location}</span>
                  {t.organizerName && <span>主催: {t.organizerName}</span>}
                </div>
              </div>

              {/* Type badge */}
              <span
                className={`text-xs text-white px-2.5 py-1 rounded-full flex-shrink-0 ${
                  typeColor[t.type] ?? "bg-gray-500"
                }`}
              >
                {t.type}
              </span>

              {/* Team count */}
              <div className="text-right flex-shrink-0">
                <div className="text-sm font-bold text-foreground">
                  {t.currentTeams ?? 0}/{t.maxTeams}
                </div>
                <div className="text-xs text-muted">チーム</div>
              </div>

              {/* Arrow */}
              <svg className="w-5 h-5 text-muted group-hover:text-primary transition-colors flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
