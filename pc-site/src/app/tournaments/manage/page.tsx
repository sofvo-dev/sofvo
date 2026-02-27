"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
} from "firebase/firestore";
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

const tabs = ["すべて", "募集中", "進行中", "終了"] as const;

export default function TournamentManagePage() {
  const { user, loading: authLoading } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<string>("すべて");

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    const q = query(
      collection(db, "tournaments"),
      where("organizerId", "==", user.uid),
      orderBy("date", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Tournament[];
      setTournaments(list);
      setLoading(false);
    });
    return () => unsub();
  }, [user]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="page-container">
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">大会管理機能を利用するにはログインしてください</p>
          <Link href="/login" className="btn-primary">ログイン</Link>
        </div>
      </div>
    );
  }

  const activeCount = tournaments.filter((t) => ["開催中", "決勝中"].includes(t.status)).length;
  const recruitingCount = tournaments.filter((t) => t.status === "募集中").length;
  const endedCount = tournaments.filter((t) => t.status === "終了").length;

  const filtered = tournaments.filter((t) => {
    if (activeTab === "すべて") return true;
    if (activeTab === "募集中") return t.status === "募集中" || t.status === "準備中";
    if (activeTab === "進行中") return ["開催中", "決勝中"].includes(t.status);
    if (activeTab === "終了") return t.status === "終了";
    return true;
  });

  return (
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会管理</h1>
          <p className="text-sm text-muted mt-1">あなたが主催する大会を管理</p>
        </div>
        <Link href="/tournaments/create" className="btn-primary">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
          新しい大会を作成
        </Link>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-4 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">総大会数</div>
          <div className="text-2xl font-bold text-foreground">{tournaments.length}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">募集中</div>
          <div className="text-2xl font-bold text-primary">{recruitingCount}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">開催中</div>
          <div className="text-2xl font-bold text-success">{activeCount}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">終了</div>
          <div className="text-2xl font-bold text-gray-400">{endedCount}</div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {tabs.map((tab) => (
          <button key={tab} onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${
              activeTab === tab
                ? "bg-primary text-white shadow-sm"
                : "bg-gray-100 text-muted hover:bg-gray-200"
            }`}>
            {tab}
          </button>
        ))}
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : tournaments.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-50 flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">まだ大会がありません</h3>
          <p className="text-sm text-muted mb-6">新しい大会を作成して始めましょう</p>
          <Link href="/tournaments/create" className="btn-primary">大会を作成する</Link>
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-muted text-sm">「{activeTab}」の大会はありません</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((t) => {
            const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
            const isFull = (t.currentTeams ?? 0) >= t.maxTeams;
            return (
              <div key={t.id} className="bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-lg hover:border-primary/20 transition-all group">
                {/* Card header */}
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
                  </div>

                  {/* Progress bar */}
                  <div className="mt-3 flex items-center gap-2">
                    <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
                      <div className={`h-full rounded-full transition-all ${isFull ? "bg-red-400" : "bg-primary"}`}
                        style={{ width: `${fillPct}%` }} />
                    </div>
                    <span className={`text-xs font-bold ${isFull ? "text-red-500" : "text-foreground"}`}>
                      {t.currentTeams ?? 0}/{t.maxTeams}
                    </span>
                  </div>
                </div>

                {/* Card actions */}
                <div className="px-5 py-3 border-t border-gray-100 bg-gray-50/50 flex gap-2">
                  <Link href={`/tournament/${t.id}`}
                    className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 text-xs font-medium text-muted bg-white border border-gray-200 rounded-lg hover:bg-gray-50 hover:text-foreground transition-colors">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                    詳細
                  </Link>
                  <Link href={`/tournament/${t.id}/manage`}
                    className="flex-1 flex items-center justify-center gap-1.5 px-3 py-2 text-xs font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" /></svg>
                    管理
                  </Link>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
