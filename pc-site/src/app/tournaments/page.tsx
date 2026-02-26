"use client";

import { useEffect, useState } from "react";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-600",
  "レディース": "bg-pink-500",
  "混合": "bg-green-600",
};

const statusFilters = ["すべて", "募集中", "準備中", "開催中", "決勝中", "終了"];

export default function TournamentsPage() {
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("すべて");
  const [typeFilter, setTypeFilter] = useState("すべて");
  const [viewMode, setViewMode] = useState<"list" | "grid">("list");

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
    <div className="page-container animate-fade-in">
      {/* Header */}
      <div className="rounded-2xl overflow-hidden mb-6 border border-gray-200">
        <div className="gradient-navy px-8 py-6 relative">
          <div className="absolute top-[-30px] right-[-30px] w-40 h-40 rounded-full bg-white/5" />
          <div className="relative z-10 flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-white flex items-center gap-3">
                <svg className="w-6 h-6 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772" /></svg>
                大会一覧
              </h1>
              <p className="text-sm text-white/50 mt-1">すべての大会を検索・閲覧</p>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={() => setViewMode("list")} className={`p-2 rounded-lg transition-colors ${viewMode === "list" ? "bg-white/20 text-white" : "text-white/40 hover:text-white/60"}`}>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm-.375 5.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" /></svg>
              </button>
              <button onClick={() => setViewMode("grid")} className={`p-2 rounded-lg transition-colors ${viewMode === "grid" ? "bg-white/20 text-white" : "text-white/40 hover:text-white/60"}`}>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" /></svg>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Search & Filters */}
      <div className="card-static p-5 mb-6">
        <div className="flex flex-wrap gap-4 mb-4">
          <div className="flex-1 min-w-[280px]">
            <div className="relative">
              <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              <input
                type="search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="大会名、会場名で検索..."
                className="input-field pl-10"
              />
            </div>
          </div>
          <select value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)} className="px-4 py-2.5 border border-gray-300 rounded-xl text-sm bg-white">
            <option value="すべて">種別: すべて</option>
            <option value="メンズ">メンズ</option>
            <option value="レディース">レディース</option>
            <option value="混合">混合</option>
          </select>
        </div>

        <div className="flex gap-2">
          {statusFilters.map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all ${
                statusFilter === s
                  ? "bg-primary text-white shadow-sm"
                  : "bg-gray-100 text-muted hover:bg-gray-200"
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <div className="text-sm text-muted mb-4 font-medium">{filtered.length}件の大会</div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">該当する大会がありません</h3>
          <p className="text-sm text-muted">検索条件を変更してください</p>
        </div>
      ) : viewMode === "list" ? (
        <div className="space-y-3">
          {filtered.map((t) => (
            <Link key={t.id} href={`/tournament/${t.id}`} className="card flex items-center gap-5 p-4 group">
              <StatusBadge status={t.status} />
              <div className="flex-1 min-w-0">
                <h3 className="text-[15px] font-bold text-foreground group-hover:text-primary transition-colors truncate">{t.title}</h3>
                <div className="flex flex-wrap gap-4 mt-1 text-sm text-muted">
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
                    {t.date}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    {t.location}
                  </span>
                  {t.organizerName && <span>{t.organizerName}</span>}
                </div>
              </div>
              <span className={`text-[10px] text-white px-2.5 py-0.5 rounded-full font-medium flex-shrink-0 ${typeColor[t.type] ?? "bg-gray-500"}`}>{t.type}</span>
              <div className="text-right flex-shrink-0">
                <div className="text-sm font-bold text-foreground">{t.currentTeams ?? 0}<span className="text-muted font-normal">/{t.maxTeams}</span></div>
                <div className="text-[11px] text-hint">チーム</div>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((t) => {
            const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
            return (
              <Link key={t.id} href={`/tournament/${t.id}`} className="card p-5 group">
                <div className="flex items-center justify-between mb-3">
                  <StatusBadge status={t.status} />
                  <span className={`text-[10px] text-white px-2.5 py-0.5 rounded-full font-medium ${typeColor[t.type] ?? "bg-gray-500"}`}>{t.type}</span>
                </div>
                <h3 className="text-[15px] font-bold text-foreground group-hover:text-primary transition-colors truncate mb-2">{t.title}</h3>
                <div className="space-y-1.5 text-sm text-muted mb-3">
                  <div className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
                    {t.date}
                  </div>
                  <div className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    {t.location}
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <div className="flex-1 mr-3">
                    <div className="progress-bar h-1.5">
                      <div className="progress-bar-fill bg-primary" style={{ width: `${fillPct}%` }} />
                    </div>
                  </div>
                  <span className="text-xs font-bold text-foreground">{t.currentTeams ?? 0}/{t.maxTeams}</span>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
