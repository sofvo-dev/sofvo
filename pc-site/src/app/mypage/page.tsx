"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  getDocs,
  limit,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

export default function MyPagePage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [myTournaments, setMyTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    async function loadData() {
      const q = query(
        collection(db, "tournaments"),
        where("organizerId", "==", user!.uid),
        orderBy("date", "desc"),
        limit(10)
      );
      const snap = await getDocs(q);
      setMyTournaments(
        snap.docs.map((doc) => ({ id: doc.id, ...doc.data() } as Tournament))
      );
      setLoading(false);
    }
    loadData();
  }, [user]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user || !profile) {
    return (
      <div className="page-container">
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">マイページを表示するにはログインしてください</p>
          <Link href="/login" className="btn-primary">ログイン</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container animate-fade-in">
      {/* Profile Header */}
      <div className="card-static overflow-hidden mb-6">
        <div className="profile-gradient px-8 pt-8 pb-20 relative">
          <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
          <div className="absolute bottom-[-25px] left-[30%] w-32 h-32 rounded-full bg-white/5" />
          <div className="absolute top-[20%] right-[20%] w-16 h-16 rounded-full bg-white/3" />
          <div className="flex items-start justify-between relative z-10">
            <div className="flex items-center gap-5">
              <div className="w-20 h-20 rounded-2xl bg-white/15 flex items-center justify-center text-white font-bold text-3xl overflow-hidden ring-[3px] ring-white/30 shadow-lg">
                {profile.avatarUrl ? (
                  <img src={profile.avatarUrl} alt="" className="w-20 h-20 object-cover" />
                ) : (
                  profile.nickname?.charAt(0) || "U"
                )}
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">{profile.nickname}</h1>
                {profile.searchId && (
                  <p className="text-sm text-white/50 mt-0.5">@{profile.searchId}</p>
                )}
                {profile.bio && (
                  <p className="text-sm text-white/60 mt-2 leading-relaxed max-w-md">{profile.bio}</p>
                )}
              </div>
            </div>
            <Link href="/settings" className="px-5 py-2.5 bg-white/15 text-white rounded-xl text-sm font-medium hover:bg-white/25 transition-colors border border-white/20 flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281" /></svg>
              設定
            </Link>
          </div>
        </div>

        {/* Follow stats bar */}
        <div className="bg-white px-8 py-4 -mt-8 relative z-10 mx-6 rounded-xl border border-gray-200 shadow-sm flex items-center">
          <div className="flex items-center gap-8 flex-1">
            <div className="text-center">
              <div className="text-xl font-bold text-foreground">{profile.followingCount ?? 0}</div>
              <div className="text-[11px] text-muted mt-0.5">フォロー</div>
            </div>
            <div className="w-px h-8 bg-gray-200" />
            <div className="text-center">
              <div className="text-xl font-bold text-foreground">{profile.followersCount ?? 0}</div>
              <div className="text-[11px] text-muted mt-0.5">フォロワー</div>
            </div>
            <div className="w-px h-8 bg-gray-200" />
            <div className="text-center">
              <div className="text-xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
              <div className="text-[11px] text-muted mt-0.5">ポイント</div>
            </div>
          </div>
        </div>
        <div className="h-4" />
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="card-static stat-navy p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <svg className="w-5 h-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>
            </div>
          </div>
          <div className="text-2xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
          <div className="text-xs font-medium text-muted mt-1">総合ポイント</div>
        </div>
        <div className="card-static stat-green p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center">
              <svg className="w-5 h-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>
            </div>
          </div>
          <div className="text-2xl font-bold text-success">{profile.stats?.tournamentsPlayed ?? 0}</div>
          <div className="text-xs font-medium text-muted mt-1">大会参加数</div>
        </div>
        <div className="card-static stat-gold p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-accent/10 flex items-center justify-center">
              <svg className="w-5 h-5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772" /></svg>
            </div>
          </div>
          <div className="text-2xl font-bold text-accent">{profile.stats?.championships ?? 0}</div>
          <div className="text-xs font-medium text-muted mt-1">優勝回数</div>
        </div>
        <div className="card-static stat-blue p-5">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-info/10 flex items-center justify-center">
              <svg className="w-5 h-5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>
            </div>
          </div>
          <div className="text-2xl font-bold text-info">{profile.followersCount ?? 0}</div>
          <div className="text-xs font-medium text-muted mt-1">フォロワー</div>
        </div>
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
        <QuickLink href="/tournaments/manage" label="大会管理" icon="clipboard" color="text-primary" bg="bg-primary/8" />
        <QuickLink href="/tournaments/create" label="大会作成" icon="plus" color="text-accent" bg="bg-accent/8" />
        <QuickLink href="/teams" label="チーム管理" icon="users" color="text-green-600" bg="bg-green-500/8" />
        <QuickLink href="/gadgets" label="ガジェット" icon="gadget" color="text-purple-600" bg="bg-purple-500/8" />
        <QuickLink href="/badges" label="バッジ" icon="badge" color="text-amber-600" bg="bg-amber-500/8" />
        <QuickLink href="/bookmarks" label="ブックマーク" icon="bookmark" color="text-blue-600" bg="bg-blue-500/8" />
        <QuickLink href="/rankings" label="ランキング" icon="ranking" color="text-red-600" bg="bg-red-500/8" />
        <QuickLink href="/settings" label="設定" icon="settings" color="text-gray-600" bg="bg-gray-500/8" />
      </div>

      {/* My Tournaments */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="section-title">主催した大会</h2>
          <Link href="/tournaments/manage" className="text-sm text-primary font-medium hover:underline flex items-center gap-1">
            すべて見る
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" /></svg>
          </Link>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : myTournaments.length === 0 ? (
          <div className="text-center py-12 card-static">
            <div className="w-12 h-12 mx-auto mb-3 rounded-xl gradient-navy flex items-center justify-center">
              <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>
            </div>
            <p className="text-muted text-sm">まだ大会を主催していません</p>
            <Link href="/tournaments/create" className="btn-primary mt-4 text-xs px-4 py-2">大会を作成する</Link>
          </div>
        ) : (
          <div className="space-y-3">
            {myTournaments.map((t) => (
              <Link key={t.id} href={`/tournament/${t.id}`} className="card flex items-center gap-4 p-4 group">
                <StatusBadge status={t.status} />
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">{t.title}</h3>
                  <div className="flex items-center gap-3 mt-1">
                    <span className="text-xs text-muted flex items-center gap-1">
                      <svg className="w-3 h-3 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
                      {t.date}
                    </span>
                    <span className="text-xs text-muted flex items-center gap-1">
                      <svg className="w-3 h-3 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                      {t.location}
                    </span>
                  </div>
                </div>
                <span className="text-sm text-muted font-medium">{t.currentTeams ?? 0}/{t.maxTeams}チーム</span>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function QuickLink({ href, label, icon, color, bg }: { href: string; label: string; icon: string; color: string; bg: string }) {
  const iconMap: Record<string, React.ReactNode> = {
    clipboard: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" /></svg>,
    plus: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>,
    users: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>,
    gadget: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25" /></svg>,
    badge: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21" /></svg>,
    bookmark: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" /></svg>,
    ranking: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75z" /></svg>,
    settings: <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87" /></svg>,
  };

  return (
    <Link href={href} className="card flex items-center gap-3 p-4 group">
      <div className={`w-10 h-10 rounded-xl ${bg} flex items-center justify-center ${color} group-hover:scale-110 transition-transform flex-shrink-0`}>
        {iconMap[icon] || <div className="w-5 h-5" />}
      </div>
      <span className="text-sm font-semibold text-foreground">{label}</span>
    </Link>
  );
}
