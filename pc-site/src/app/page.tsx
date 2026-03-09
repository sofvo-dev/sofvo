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

export default function HomePage() {
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
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">

      {/* Profile Header (logged in) */}
      {user && profile ? (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
          <div className="gradient-navy px-8 pt-6 pb-14 relative">
            <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
            <div className="absolute bottom-[-25px] left-[30%] w-32 h-32 rounded-full bg-white/5" />
            <div className="flex items-center justify-between relative z-10">
              <div className="flex items-center gap-5">
                <div className="w-16 h-16 rounded-2xl bg-white/15 flex items-center justify-center text-white font-bold text-2xl overflow-hidden ring-[3px] ring-white/30 shadow-lg">
                  {profile.avatarUrl ? (
                    <img src={profile.avatarUrl} alt="" className="w-16 h-16 object-cover" />
                  ) : (
                    profile.nickname?.charAt(0) || "U"
                  )}
                </div>
                <div>
                  <h1 className="text-xl font-bold text-white">{profile.nickname}さん、おかえりなさい</h1>
                  {profile.searchId && (
                    <p className="text-sm text-white/50 mt-0.5">@{profile.searchId}</p>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Stats bar */}
          <div className="bg-white px-8 py-3 -mt-8 relative z-10 mx-6 rounded-xl border border-gray-200 shadow-sm flex items-center">
            <div className="flex items-center gap-6 flex-1">
              <div className="text-center">
                <div className="text-lg font-bold text-primary">{profile.totalPoints ?? 0}</div>
                <div className="text-[11px] text-muted">ポイント</div>
              </div>
              <div className="w-px h-6 bg-gray-200" />
              <div className="text-center">
                <div className="text-lg font-bold text-success">{profile.stats?.tournamentsPlayed ?? 0}</div>
                <div className="text-[11px] text-muted">大会参加</div>
              </div>
              <div className="w-px h-6 bg-gray-200" />
              <div className="text-center">
                <div className="text-lg font-bold text-accent">{profile.stats?.championships ?? 0}</div>
                <div className="text-[11px] text-muted">優勝</div>
              </div>
              <div className="w-px h-6 bg-gray-200" />
              <div className="text-center">
                <div className="text-lg font-bold text-foreground">{profile.followersCount ?? 0}</div>
                <div className="text-[11px] text-muted">フォロワー</div>
              </div>
            </div>
            <Link href="/settings" className="text-xs text-muted hover:text-primary transition-colors flex items-center gap-1">
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
              設定
            </Link>
          </div>
          <div className="h-4" />
        </div>
      ) : (
        /* Hero Banner (not logged in) */
        <div className="gradient-navy rounded-xl p-8 pb-10 mb-6 text-white relative overflow-hidden">
          <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
          <div className="absolute bottom-[-30px] left-[20%] w-32 h-32 rounded-full bg-white/5" />
          <div className="relative z-10">
            <h1 className="text-2xl font-bold mb-1">Sofvo</h1>
            <p className="text-white/60 text-sm mb-6">ソフトバレーボール大会管理プラットフォーム</p>
            <div className="flex gap-3">
              <Link href="/tournaments" className="inline-flex items-center gap-2 px-5 py-2.5 bg-white text-primary rounded-xl text-sm font-semibold hover:bg-white/90 transition-colors">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
                大会を探す
              </Link>
              <Link href="/login" className="inline-flex items-center gap-2 px-5 py-2.5 bg-accent text-white rounded-xl text-sm font-semibold hover:bg-[#B89B52] transition-colors">
                ログイン
              </Link>
            </div>
          </div>
        </div>
      )}

      {/* Quick Links (logged in) */}
      {user && (
        <div className="grid grid-cols-4 lg:grid-cols-8 gap-2 mb-6">
          <QuickLink href="/tournaments/manage" label="大会管理" color="text-primary" bg="bg-primary/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" />} />
          <QuickLink href="/tournaments/create" label="大会作成" color="text-accent" bg="bg-accent/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />} />
          <QuickLink href="/teams" label="チーム" color="text-green-600" bg="bg-green-500/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />} />
          <QuickLink href="/gadgets" label="ガジェット" color="text-purple-600" bg="bg-purple-500/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 2.25 0 00-2.25 2.25v.894m7.5 0a48.667 48.667 0 00-7.5 0" />} />
          <QuickLink href="/badges" label="バッジ" color="text-amber-600" bg="bg-amber-500/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21a3.745 3.745 0 01-3.068-1.593 3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12a3.745 3.745 0 011.593-3.068 3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3a3.746 3.746 0 013.068 1.593 3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />} />
          <QuickLink href="/bookmarks" label="ブックマーク" color="text-blue-600" bg="bg-blue-500/8"
            icon={<path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />} />
          <QuickLink href="/rankings" label="ランキング" color="text-red-600" bg="bg-red-500/8"
            icon={<><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" /></>} />
          <QuickLink href="/settings" label="設定" color="text-gray-600" bg="bg-gray-500/8"
            icon={<><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></>} />
        </div>
      )}

      {/* Live Tournaments */}
      {liveTournaments.length > 0 && (
        <section className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-foreground flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-success animate-pulse" />
              開催中の大会
            </h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
            <h2 className="text-base font-bold text-foreground">開催予定の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
            <h2 className="text-base font-bold text-foreground">最近の大会</h2>
            <Link href="/tournaments" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {recentTournaments.map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* Empty state */}
      {liveTournaments.length === 0 && upcomingTournaments.length === 0 && recentTournaments.length === 0 && (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-50 flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">大会がまだありません</h3>
          <p className="text-sm text-muted mb-6">大会を作成して、ソフトバレーを始めましょう</p>
          {user ? (
            <Link href="/tournaments/create" className="btn-primary">大会を作成する</Link>
          ) : (
            <Link href="/login" className="btn-primary">ログインして始める</Link>
          )}
        </div>
      )}
    </div>
  );
}

function TournamentCard({ tournament: t }: { tournament: Tournament }) {
  const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
  const isFull = (t.currentTeams ?? 0) >= t.maxTeams;
  return (
    <Link href={`/tournament/${t.id}`} className="bg-white rounded-xl border border-gray-200 p-0 block group overflow-hidden hover:shadow-lg hover:border-primary/20 transition-all">
      {/* Header */}
      <div className="gradient-navy px-5 py-4 flex items-center justify-between">
        <div className="flex items-center gap-2 text-white text-sm font-medium">
          <svg className="w-4 h-4 text-white/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25" /></svg>
          {t.date}
        </div>
        <div className="flex items-center gap-2">
          <span className={`text-[11px] text-white px-2.5 py-0.5 rounded-full font-medium ${typeColor[t.type] ?? "bg-gray-500"}`}>
            {t.type}
          </span>
          <StatusBadge status={t.status} />
        </div>
      </div>
      {/* Body */}
      <div className="p-5">
        <h3 className="text-lg font-bold text-foreground group-hover:text-primary transition-colors line-clamp-2 leading-snug mb-4">
          {t.title}
        </h3>
        <div className="space-y-2.5 text-sm text-muted mb-4">
          <div className="flex items-center gap-2.5">
            <svg className="w-4 h-4 text-primary/40 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
            <span className="truncate">{t.location}</span>
          </div>
          {t.organizerName && (
            <div className="flex items-center gap-2.5">
              <svg className="w-4 h-4 text-primary/40 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" /></svg>
              <span>{t.organizerName}</span>
            </div>
          )}
        </div>
        {/* Progress */}
        <div className="flex items-center gap-3">
          <div className="flex-1 h-2.5 bg-gray-100 rounded-full overflow-hidden">
            <div className={`h-full rounded-full transition-all ${isFull ? "bg-red-400" : "bg-primary"}`}
              style={{ width: `${fillPct}%` }} />
          </div>
          <span className={`text-sm font-bold whitespace-nowrap ${isFull ? "text-red-500" : "text-foreground"}`}>
            {t.currentTeams ?? 0}/{t.maxTeams}チーム
          </span>
        </div>
      </div>
    </Link>
  );
}

function QuickLink({ href, label, color, bg, icon }: { href: string; label: string; color: string; bg: string; icon: React.ReactNode }) {
  return (
    <Link href={href} className="bg-white rounded-xl border border-gray-200 flex flex-col items-center gap-2 p-3 group hover:shadow-md hover:border-primary/20 transition-all">
      <div className={`w-9 h-9 rounded-xl ${bg} flex items-center justify-center ${color} group-hover:scale-110 transition-transform`}>
        <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          {icon}
        </svg>
      </div>
      <span className="text-[11px] font-semibold text-foreground">{label}</span>
    </Link>
  );
}
