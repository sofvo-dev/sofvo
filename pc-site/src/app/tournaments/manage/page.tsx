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

export default function TournamentManagePage() {
  const { user, loading: authLoading } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);

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

  const activeTournaments = tournaments.filter((t) => !["終了"].includes(t.status));
  const pastTournaments = tournaments.filter((t) => t.status === "終了");

  return (
    <div className="page-container animate-fade-in">
      {/* Header */}
      <div className="rounded-2xl overflow-hidden mb-6 border border-gray-200">
        <div className="gradient-navy px-8 py-6 relative">
          <div className="absolute top-[-30px] right-[-30px] w-40 h-40 rounded-full bg-white/5" />
          <div className="relative z-10 flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-white flex items-center gap-3">
                <svg className="w-6 h-6 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" /></svg>
                大会管理
              </h1>
              <p className="text-sm text-white/50 mt-1">あなたが主催する大会を管理</p>
            </div>
            <Link href="/tournaments/create" className="flex items-center gap-2 px-5 py-2.5 bg-accent text-white rounded-xl text-sm font-medium hover:bg-[#B89B52] transition-colors shadow-lg">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              新しい大会を作成
            </Link>
          </div>
        </div>
        {/* Quick stats */}
        <div className="bg-white px-8 py-3 flex items-center gap-6 text-sm">
          <span className="text-muted">総大会数: <span className="font-bold text-foreground">{tournaments.length}</span></span>
          <span className="w-px h-4 bg-gray-200" />
          <span className="text-muted">開催中: <span className="font-bold text-success">{tournaments.filter((t) => ["開催中", "決勝中"].includes(t.status)).length}</span></span>
          <span className="w-px h-4 bg-gray-200" />
          <span className="text-muted">募集中: <span className="font-bold text-primary">{tournaments.filter((t) => t.status === "募集中").length}</span></span>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : tournaments.length === 0 ? (
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl gradient-navy flex items-center justify-center">
            <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">まだ大会がありません</h3>
          <p className="text-sm text-muted mb-6">新しい大会を作成して始めましょう</p>
          <Link href="/tournaments/create" className="btn-accent">大会を作成する</Link>
        </div>
      ) : (
        <div className="space-y-6">
          {/* Active tournaments */}
          {activeTournaments.length > 0 && (
            <section>
              <h2 className="section-title mb-4">進行中の大会</h2>
              <div className="space-y-3">
                {activeTournaments.map((t) => (
                  <TournamentRow key={t.id} tournament={t} />
                ))}
              </div>
            </section>
          )}

          {/* Past tournaments */}
          {pastTournaments.length > 0 && (
            <section>
              <h2 className="section-title mb-4">終了した大会</h2>
              <div className="space-y-3">
                {pastTournaments.map((t) => (
                  <TournamentRow key={t.id} tournament={t} />
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  );
}

function TournamentRow({ tournament: t }: { tournament: Tournament }) {
  const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
  return (
    <div className="card flex items-center gap-5 p-5 group">
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
          <span className="flex items-center gap-1">
            <span className="font-medium text-foreground">{t.currentTeams ?? 0}</span>/{t.maxTeams}チーム
          </span>
        </div>
        {/* Small progress bar */}
        <div className="mt-2 max-w-[200px]">
          <div className="progress-bar h-1">
            <div className="progress-bar-fill bg-primary" style={{ width: `${fillPct}%` }} />
          </div>
        </div>
      </div>
      <div className="flex gap-2 flex-shrink-0">
        <Link href={`/tournament/${t.id}`} className="btn-secondary text-xs px-4 py-2">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
          詳細
        </Link>
        <Link href={`/tournament/${t.id}/manage`} className="btn-primary text-xs px-4 py-2">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" /></svg>
          管理
        </Link>
      </div>
    </div>
  );
}
