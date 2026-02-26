"use client";

import { useEffect, useState } from "react";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "from-blue-500 to-blue-600",
  "レディース": "from-pink-500 to-pink-600",
  "混合": "from-emerald-500 to-emerald-600",
};

const statusFilters = ["すべて", "募集中", "準備中", "開催中", "決勝中", "終了"];

export default function TournamentsPage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("すべて");
  const [typeFilter, setTypeFilter] = useState("すべて");

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
    return true;
  });

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会一覧</h1>
          <p className="text-sm text-muted mt-1">すべての大会を検索・閲覧</p>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="card-static p-5 mb-6">
        <div className="flex flex-wrap gap-4 mb-4">
          {/* Search */}
          <div className="flex-1 min-w-[280px]">
            <div className="relative">
              <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              <input
                type="search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="大会名、会場名で検索..."
                className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm bg-gray-50/50 focus:bg-white"
              />
            </div>
          </div>

          {/* Status Filter */}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-4 py-2.5 border border-gray-200 rounded-xl text-sm bg-gray-50/50 focus:bg-white"
          >
            {statusFilters.map((s) => (
              <option key={s} value={s}>{s === "すべて" ? "ステータス: すべて" : s}</option>
            ))}
          </select>

          {/* Type Filter */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-4 py-2.5 border border-gray-200 rounded-xl text-sm bg-gray-50/50 focus:bg-white"
          >
            <option value="すべて">種別: すべて</option>
            <option value="メンズ">メンズ</option>
            <option value="レディース">レディース</option>
            <option value="混合">混合</option>
          </select>
        </div>

        {/* Quick status pills */}
        <div className="flex gap-2">
          {statusFilters.map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3 py-1 rounded-lg text-xs font-medium transition-all ${
                statusFilter === s
                  ? "bg-primary text-white shadow-sm shadow-primary/20"
                  : "bg-gray-100 text-muted hover:bg-gray-200"
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {/* Results count */}
      <div className="text-sm text-muted mb-4 font-medium">
        {filtered.length}件の大会
      </div>

      {/* Tournament List */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-10 h-10 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-24 card-static animate-scale-in">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">該当する大会がありません</h3>
          <p className="text-sm text-muted">検索条件を変更してください</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((t) => (
            <Link
              key={t.id}
              href={`/tournament/${t.id}`}
              className="card flex items-center gap-6 p-5 group"
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
                <div className="flex flex-wrap gap-4 mt-1.5 text-sm text-muted">
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25" /></svg>
                    {t.date}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    {t.location}
                  </span>
                  {t.organizerName && (
                    <span className="flex items-center gap-1.5">
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0" /></svg>
                      {t.organizerName}
                    </span>
                  )}
                </div>
              </div>

              {/* Type badge */}
              <span
                className={`text-[11px] text-white px-3 py-1 rounded-lg bg-gradient-to-r flex-shrink-0 font-medium ${
                  typeColor[t.type] ?? "from-gray-500 to-gray-600"
                }`}
              >
                {t.type}
              </span>

              {/* Team count */}
              <div className="text-right flex-shrink-0">
                <div className="text-sm font-bold text-foreground">
                  {t.currentTeams ?? 0}<span className="text-muted font-normal">/{t.maxTeams}</span>
                </div>
                <div className="text-[11px] text-muted">チーム</div>
              </div>

              {/* Arrow */}
              <svg className="w-5 h-5 text-gray-300 group-hover:text-primary group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
