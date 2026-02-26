"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  limit,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import { useAuth } from "@/contexts/AuthContext";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-600",
  "レディース": "bg-pink-400",
  "混合": "bg-green-600",
};

export default function DashboardPage() {
  const { user, profile } = useAuth();
  const [liveTournaments, setLiveTournaments] = useState<Tournament[]>([]);
  const [upcomingTournaments, setUpcomingTournaments] = useState<Tournament[]>([]);
  const [recentTournaments, setRecentTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, "tournaments"), orderBy("date", "desc"), limit(50));
    const unsub = onSnapshot(q, (snap) => {
      const all = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Tournament[];

      const liveStatuses = ["開催中", "決勝中"];
      setLiveTournaments(all.filter((t) => liveStatuses.includes(t.status) || t.status.includes("完了")));
      setUpcomingTournaments(all.filter((t) => t.status === "募集中" || t.status === "準備中" || t.status === "満員"));
      setRecentTournaments(all.filter((t) => t.status === "終了").slice(0, 6));
      setLoading(false);
    });
    return () => unsub();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="page-container animate-fade-in">
      {/* Hero Banner - Navy gradient like smartphone profile header */}
      <div className="gradient-navy rounded-2xl p-8 pb-10 mb-8 text-white relative overflow-hidden">
        {/* Decorative circles */}
        <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
        <div className="absolute bottom-[-30px] left-[20%] w-32 h-32 rounded-full bg-white/5" />
        <div className="absolute top-[50%] right-[30%] w-20 h-20 rounded-full bg-accent/10" />

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-1">
            <h1 className="text-2xl font-bold">
              {profile ? `${profile.nickname}さん、おかえりなさい` : "Sofvo"}
            </h1>
            {profile && (
              <span className="badge-gold text-xs">
                {profile.totalPoints ?? 0} pt
              </span>
            )}
          </div>
          <p className="text-white/60 text-sm mb-6">
            ソフトバレーボール大会管理プラットフォーム
          </p>
          <div className="flex gap-3">
            <Link href="/tournaments" className="inline-flex items-center gap-2 px-5 py-2.5 bg-white text-primary rounded-xl text-sm font-semibold hover:bg-white/90 transition-colors">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
              大会を探す
            </Link>
            {user && (
              <Link href="/tournaments/create" className="inline-flex items-center gap-2 px-5 py-2.5 bg-accent text-white rounded-xl text-sm font-semibold hover:bg-accent-light transition-colors">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
                大会を作成
              </Link>
            )}
          </div>
        </div>
      </div>

      {/* Stats Cards (when logged in) */}
      {profile && (
        <div className="grid grid-cols-4 gap-4 mb-8">
          <div className="card-static stat-navy p-5">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-9 h-9 rounded-xl bg-primary/10 flex items-center justify-center">
                <svg className="w-4.5 h-4.5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>
              </div>
              <div className="text-xs font-medium text-muted">総合ポイント</div>
            </div>
            <div className="text-2xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
          </div>
          <div className="card-static stat-green p-5">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-9 h-9 rounded-xl bg-success/10 flex items-center justify-center">
                <svg className="w-4.5 h-4.5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25" /></svg>
              </div>
              <div className="text-xs font-medium text-muted">大会参加</div>
            </div>
            <div className="text-2xl font-bold text-success">{profile.stats?.tournamentsPlayed ?? 0}</div>
          </div>
          <div className="card-static stat-gold p-5">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-9 h-9 rounded-xl bg-accent/10 flex items-center justify-center">
                <svg className="w-4.5 h-4.5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>
              </div>
              <div className="text-xs font-medium text-muted">優勝回数</div>
            </div>
            <div className="text-2xl font-bold text-accent">{profile.stats?.championships ?? 0}</div>
          </div>
          <div className="card-static stat-blue p-5">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-9 h-9 rounded-xl bg-info/10 flex items-center justify-center">
                <svg className="w-4.5 h-4.5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>
              </div>
              <div className="text-xs font-medium text-muted">フォロワー</div>
            </div>
            <div className="text-2xl font-bold text-info">{profile.followersCount ?? 0}</div>
          </div>
        </div>
      )}

      {/* Live Tournaments */}
      {liveTournaments.length > 0 && (
        <section className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">
              <span className="w-2 h-2 rounded-full bg-success animate-live-pulse" />
              開催中の大会
            </h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {liveTournaments.map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* Upcoming Tournaments */}
      {upcomingTournaments.length > 0 && (
        <section className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">開催予定の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {upcomingTournaments.slice(0, 6).map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* Recent Tournaments */}
      {recentTournaments.length > 0 && (
        <section className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">最近の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {recentTournaments.map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* Empty state */}
      {liveTournaments.length === 0 && upcomingTournaments.length === 0 && recentTournaments.length === 0 && (
        <div className="text-center py-20 card-static animate-scale-in">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl gradient-navy flex items-center justify-center">
            <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">大会がまだありません</h3>
          <p className="text-sm text-muted mb-6">大会を作成して、ソフトバレーを始めましょう</p>
          {user && (
            <Link href="/tournaments/create" className="btn-primary">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
              大会を作成する
            </Link>
          )}
        </div>
      )}
    </div>
  );
}

function TournamentCard({ tournament: t }: { tournament: Tournament }) {
  return (
    <Link
      href={`/tournament/${t.id}`}
      className="card p-0 block group overflow-hidden"
    >
      {/* Card header with navy gradient like smartphone tournament card */}
      <div className="gradient-navy px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2 text-white/70 text-xs">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25" /></svg>
          {t.date}
        </div>
        <span className={`text-[10px] text-white px-2 py-0.5 rounded-full font-medium ${typeColor[t.type] ?? "bg-gray-500"}`}>
          {t.type}
        </span>
      </div>
      {/* Card body */}
      <div className="p-4">
        <div className="flex items-start justify-between mb-3">
          <h3 className="text-[15px] font-bold text-foreground group-hover:text-primary transition-colors line-clamp-1 flex-1">
            {t.title}
          </h3>
          <StatusBadge status={t.status} />
        </div>
        <div className="space-y-1.5 text-sm text-muted">
          <div className="flex items-center gap-2">
            <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
            <span className="truncate">{t.location}</span>
          </div>
          <div className="flex items-center gap-2">
            <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493" /></svg>
            <span><span className="font-semibold text-foreground">{t.currentTeams ?? 0}</span>/{t.maxTeams}チーム</span>
          </div>
        </div>
      </div>
    </Link>
  );
}
