"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  limit,
  where,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import { useAuth } from "@/contexts/AuthContext";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-500",
  "レディース": "bg-pink-500",
  "混合": "bg-green-500",
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
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Welcome */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground">
          {profile ? `${profile.nickname}さん、こんにちは` : "ダッシュボード"}
        </h1>
        <p className="text-sm text-muted mt-1">ソフトバレーボール大会の状況を一覧で確認</p>
      </div>

      {/* Stats Cards (when logged in) */}
      {profile && (
        <div className="grid grid-cols-4 gap-4 mb-8">
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="text-sm text-muted mb-1">総合ポイント</div>
            <div className="text-2xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="text-sm text-muted mb-1">大会参加数</div>
            <div className="text-2xl font-bold text-foreground">{profile.stats?.tournamentsPlayed ?? 0}</div>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="text-sm text-muted mb-1">優勝回数</div>
            <div className="text-2xl font-bold text-accent">{profile.stats?.championships ?? 0}</div>
          </div>
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="text-sm text-muted mb-1">フォロワー</div>
            <div className="text-2xl font-bold text-foreground">{profile.followersCount ?? 0}</div>
          </div>
        </div>
      )}

      {/* Live Tournaments */}
      {liveTournaments.length > 0 && (
        <section className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-bold text-foreground flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-green-500 animate-live-pulse" />
              開催中の大会
            </h2>
            <Link href="/tournaments" className="text-sm text-primary hover:underline">
              すべて見る
            </Link>
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
            <h2 className="text-lg font-bold text-foreground">開催予定の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary hover:underline">
              すべて見る
            </Link>
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
            <h2 className="text-lg font-bold text-foreground">最近の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary hover:underline">
              すべて見る
            </Link>
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
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🏐</div>
          <h3 className="text-lg font-bold text-foreground mb-2">大会がまだありません</h3>
          <p className="text-sm text-muted mb-6">大会を作成して、ソフトバレーを始めましょう</p>
          {user && (
            <Link
              href="/tournaments/create"
              className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
            >
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
      <h3 className="text-base font-bold text-foreground mb-2 group-hover:text-primary transition-colors">
        {t.title}
      </h3>
      <div className="space-y-1 text-sm text-muted">
        <div className="flex items-center gap-2">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>
          <span>{t.date}</span>
        </div>
        <div className="flex items-center gap-2">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
          <span>{t.location}</span>
        </div>
        <div className="flex items-center gap-2">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>
          <span>{t.currentTeams ?? 0}/{t.maxTeams}チーム</span>
        </div>
      </div>
    </Link>
  );
}
