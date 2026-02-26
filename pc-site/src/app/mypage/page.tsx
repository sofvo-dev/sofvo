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
      {/* Profile Header - Gradient like smartphone */}
      <div className="card-static overflow-hidden mb-6">
        <div className="profile-gradient px-6 pt-6 pb-16 relative">
          <div className="absolute top-[-30px] right-[-30px] w-40 h-40 rounded-full bg-white/5" />
          <div className="absolute bottom-[-20px] left-[30%] w-24 h-24 rounded-full bg-white/5" />
          <div className="flex items-start justify-between relative z-10">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 rounded-full bg-white/15 flex items-center justify-center text-white font-bold text-2xl overflow-hidden ring-[2.5px] ring-white/30">
                {profile.avatarUrl ? (
                  <img src={profile.avatarUrl} alt="" className="w-16 h-16 object-cover" />
                ) : (
                  profile.nickname?.charAt(0) || "U"
                )}
              </div>
              <div>
                <h1 className="text-xl font-bold text-white">{profile.nickname}</h1>
                {profile.searchId && (
                  <p className="text-sm text-white/50">@{profile.searchId}</p>
                )}
              </div>
            </div>
            <Link href="/settings" className="px-4 py-2 bg-white/15 text-white rounded-xl text-sm font-medium hover:bg-white/25 transition-colors border border-white/20">
              <svg className="w-4 h-4 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281" /></svg>
              設定
            </Link>
          </div>
          {profile.bio && (
            <p className="text-sm text-white/60 mt-3 leading-relaxed relative z-10">{profile.bio}</p>
          )}
          {/* Follow stats with divider like smartphone */}
          <div className="flex items-center gap-0 mt-4 relative z-10">
            <div className="text-center pr-6">
              <div className="text-lg font-bold text-white">{profile.followingCount ?? 0}</div>
              <div className="text-[11px] text-white/40">フォロー</div>
            </div>
            <div className="w-px h-8 bg-white/20" />
            <div className="text-center pl-6">
              <div className="text-lg font-bold text-white">{profile.followersCount ?? 0}</div>
              <div className="text-[11px] text-white/40">フォロワー</div>
            </div>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <div className="card-static stat-navy p-4">
          <div className="text-xs font-medium text-muted mb-1">総合ポイント</div>
          <div className="text-2xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
        </div>
        <div className="card-static stat-green p-4">
          <div className="text-xs font-medium text-muted mb-1">大会参加数</div>
          <div className="text-2xl font-bold text-success">{profile.stats?.tournamentsPlayed ?? 0}</div>
        </div>
        <div className="card-static stat-gold p-4">
          <div className="text-xs font-medium text-muted mb-1">優勝回数</div>
          <div className="text-2xl font-bold text-accent">{profile.stats?.championships ?? 0}</div>
        </div>
        <div className="card-static stat-blue p-4">
          <div className="text-xs font-medium text-muted mb-1">フォロワー</div>
          <div className="text-2xl font-bold text-info">{profile.followersCount ?? 0}</div>
        </div>
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
        <QuickLink href="/tournaments/manage" label="大会管理" icon="clipboard" />
        <QuickLink href="/tournaments/create" label="大会作成" icon="plus" />
        <QuickLink href="/teams" label="チーム管理" icon="users" />
        <QuickLink href="/gadgets" label="ガジェット" icon="gadget" />
        <QuickLink href="/badges" label="バッジ" icon="badge" />
        <QuickLink href="/bookmarks" label="ブックマーク" icon="bookmark" />
        <QuickLink href="/rankings" label="ランキング" icon="ranking" />
        <QuickLink href="/settings" label="設定" icon="settings" />
      </div>

      {/* My Tournaments */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="section-title">主催した大会</h2>
          <Link href="/tournaments/manage" className="text-sm text-primary font-medium hover:underline">すべて見る</Link>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : myTournaments.length === 0 ? (
          <div className="text-center py-12 card-static text-muted text-sm">
            まだ大会を主催していません
          </div>
        ) : (
          <div className="space-y-3">
            {myTournaments.map((t) => (
              <Link key={t.id} href={`/tournament/${t.id}`} className="card flex items-center gap-4 p-4 group">
                <StatusBadge status={t.status} />
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">{t.title}</h3>
                  <span className="text-xs text-muted">{t.date} - {t.location}</span>
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

function QuickLink({ href, label, icon }: { href: string; label: string; icon: string }) {
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
      <div className="w-10 h-10 rounded-xl bg-primary/8 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-white transition-all flex-shrink-0">
        {iconMap[icon] || <div className="w-5 h-5" />}
      </div>
      <span className="text-sm font-semibold text-foreground">{label}</span>
    </Link>
  );
}
