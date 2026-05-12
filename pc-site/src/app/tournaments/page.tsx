"use client";

import { useEffect, useState } from "react";
import { collection, query, orderBy, onSnapshot } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-500",
  "レディース": "bg-pink-500",
  "混合": "bg-emerald-500",
};

const statusFilters = ["すべて", "募集中", "準備中", "エントリー締切", "試合準備", "開催中", "決勝中", "終了"];

export default function TournamentsPage() {
  const { user, loading: authLoading } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("すべて");
  const [typeFilter, setTypeFilter] = useState("すべて");

  useEffect(() => {
    if (authLoading) return;
    if (!user) {
      setLoading(false);
      return;
    }
    const q = query(collection(db, "tournaments"), orderBy("date", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list = snap.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as Tournament[];
        setTournaments(list);
        setLoading(false);
      },
      () => setLoading(false)
    );
    const timeout = setTimeout(() => setLoading(false), 5000);
    return () => {
      unsub();
      clearTimeout(timeout);
    };
  }, [user, authLoading]);

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
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会一覧</h1>
          <p className="text-sm text-muted mt-1">{tournaments.length}件の大会が登録されています</p>
        </div>
        <Link href="/tournaments/create" className="btn-primary">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
          大会を作成
        </Link>
      </div>

      {/* Search & Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 mb-6">
        <div className="flex flex-wrap gap-3 items-center mb-3">
          <div className="flex-1 min-w-[260px] relative">
            <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
            <input type="search" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="大会名、会場名で検索..." className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm" />
          </div>
          <select value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)}
            className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm bg-white">
            <option value="すべて">種別: すべて</option>
            <option value="メンズ">メンズ</option>
            <option value="レディース">レディース</option>
            <option value="混合">混合</option>
          </select>
        </div>
        <div className="flex gap-2 flex-wrap">
          {statusFilters.map((s) => (
            <button key={s} onClick={() => setStatusFilter(s)}
              className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${
                statusFilter === s
                  ? "bg-primary text-white shadow-sm"
                  : "bg-gray-100 text-muted hover:bg-gray-200"
              }`}>
              {s}
            </button>
          ))}
        </div>
      </div>

      <p className="text-sm text-muted mb-4 font-medium">{filtered.length}件の大会</p>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          <h3 className="text-lg font-bold text-foreground mb-2">該当する大会がありません</h3>
          <p className="text-sm text-muted">検索条件を変更してください</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((t) => {
            const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
            const isFull = (t.currentTeams ?? 0) >= t.maxTeams;
            return (
              <Link key={t.id} href={`/tournament/${t.id}`}
                className="bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-lg hover:border-primary/20 transition-all group">
                {/* Card header with status */}
                <div className="px-5 pt-5 pb-3">
                  <div className="flex items-center justify-between mb-3">
                    <StatusBadge status={t.status} />
                    <span className={`text-[11px] text-white px-2.5 py-0.5 rounded-full font-medium ${typeColor[t.type] ?? "bg-gray-500"}`}>
                      {t.type}
                    </span>
                  </div>

                  <h3 className="text-base font-bold text-foreground group-hover:text-primary transition-colors line-clamp-2 leading-snug mb-3">
                    {t.title}
                  </h3>

                  <div className="space-y-2 text-sm text-muted">
                    <div className="flex items-center gap-2">
                      <svg className="w-4 h-4 text-primary/50 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>
                      <span className="font-medium">{t.date}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <svg className="w-4 h-4 text-primary/50 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                      <span className="truncate">{t.location}</span>
                    </div>
                    {t.organizerName && (
                      <div className="flex items-center gap-2">
                        <svg className="w-4 h-4 text-primary/50 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" /></svg>
                        <span>{t.organizerName}</span>
                      </div>
                    )}
                    {t.deadline && t.status === "募集中" && (
                      <div className="flex items-center gap-2">
                        <svg className="w-4 h-4 text-amber-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                        <span className="text-amber-600 font-medium">締切 {t.deadline}</span>
                      </div>
                    )}
                  </div>
                </div>

                {/* Card footer */}
                <div className="px-5 py-3 border-t border-gray-100 bg-gray-50/50">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2 flex-1 mr-4">
                      <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden">
                        <div className={`h-full rounded-full transition-all ${isFull ? "bg-red-400" : "bg-primary"}`}
                          style={{ width: `${fillPct}%` }} />
                      </div>
                    </div>
                    <div className="flex items-center gap-1.5 flex-shrink-0">
                      <svg className="w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" /></svg>
                      <span className={`text-sm font-bold ${isFull ? "text-red-500" : "text-foreground"}`}>
                        {t.currentTeams ?? 0}
                      </span>
                      <span className="text-sm text-muted">/ {t.maxTeams}</span>
                    </div>
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
