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
        <div className="w-10 h-10 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user || !profile) {
    return (
      <div className="page-container">
        <div className="text-center py-24 card-static animate-scale-in">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">マイページを表示するにはログインしてください</p>
          <Link href="/login" className="btn-primary">ログイン</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container">
      {/* Profile Header */}
      <div className="card-static overflow-hidden mb-6 animate-fade-in-up">
        <div className="h-24 gradient-hero relative">
          <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGNpcmNsZSBjeD0iMjAiIGN5PSIyMCIgcj0iMSIgZmlsbD0icmdiYSgyNTUsMjU1LDI1NSwwLjA1KSIvPjwvc3ZnPg==')] opacity-50" />
        </div>
        <div className="px-6 pb-6">
          <div className="flex items-end gap-5 -mt-10 relative z-10">
            <div className="w-20 h-20 rounded-2xl bg-white p-1 shadow-lg">
              <div className="w-full h-full rounded-xl bg-gradient-to-br from-primary/20 to-primary-light/20 flex items-center justify-center text-primary font-bold text-2xl overflow-hidden">
                {profile.avatarUrl ? (
                  <img src={profile.avatarUrl} alt="" className="w-full h-full object-cover rounded-xl" />
                ) : (
                  profile.nickname?.charAt(0) || "U"
                )}
              </div>
            </div>
            <div className="flex-1 pb-1">
              <h1 className="text-xl font-bold text-foreground">{profile.nickname}</h1>
              {profile.searchId && (
                <p className="text-sm text-muted">@{profile.searchId}</p>
              )}
            </div>
            <Link href="/settings" className="btn-secondary">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247" /></svg>
              設定
            </Link>
          </div>
          {profile.bio && (
            <p className="text-sm text-muted mt-4">{profile.bio}</p>
          )}
          <div className="flex gap-6 mt-4 text-sm">
            <span className="text-muted">
              <span className="font-bold text-foreground">{profile.followingCount ?? 0}</span> フォロー
            </span>
            <span className="text-muted">
              <span className="font-bold text-foreground">{profile.followersCount ?? 0}</span> フォロワー
            </span>
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mb-6 animate-fade-in-up">
        <StatCard label="総合ポイント" value={profile.totalPoints ?? 0} gradient="stat-blue" color="text-blue-700" />
        <StatCard label="大会参加数" value={profile.stats?.tournamentsPlayed ?? 0} gradient="stat-green" color="text-green-700" />
        <StatCard label="優勝回数" value={profile.stats?.championships ?? 0} gradient="stat-orange" color="text-orange-700" />
        <StatCard label="フォロワー" value={profile.followersCount ?? 0} gradient="stat-purple" color="text-purple-700" />
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-8 animate-fade-in-up">
        <QuickLink href="/tournaments/manage" icon="clipboard" label="大会管理" desc="主催大会の管理" />
        <QuickLink href="/tournaments/create" icon="plus" label="大会作成" desc="新しい大会を開催" />
        <QuickLink href="/teams" icon="users" label="チーム管理" desc="チーム編成" />
        <QuickLink href="/gadgets" icon="gadget" label="ガジェット" desc="装備管理" />
        <QuickLink href="/badges" icon="badge" label="バッジ" desc="実績コレクション" />
        <QuickLink href="/bookmarks" icon="bookmark" label="ブックマーク" desc="お気に入り" />
        <QuickLink href="/rankings" icon="ranking" label="ランキング" desc="総合順位" />
        <QuickLink href="/settings" icon="settings" label="設定" desc="プロフィール編集" />
      </div>

      {/* My Tournaments */}
      <section className="animate-fade-in-up">
        <div className="flex items-center justify-between mb-4">
          <h2 className="section-title">主催した大会</h2>
          <Link href="/tournaments/manage" className="text-sm text-primary font-medium hover:underline">
            すべて見る →
          </Link>
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
              <Link
                key={t.id}
                href={`/tournament/${t.id}`}
                className="card flex items-center gap-4 p-4 group"
              >
                <StatusBadge status={t.status} />
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">
                    {t.title}
                  </h3>
                  <span className="text-xs text-muted">{t.date} - {t.location}</span>
                </div>
                <span className="text-sm text-muted font-medium">{t.currentTeams ?? 0}/{t.maxTeams}チーム</span>
                <svg className="w-4 h-4 text-gray-300 group-hover:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" /></svg>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function StatCard({ label, value, gradient, color }: { label: string; value: number; gradient: string; color: string }) {
  return (
    <div className={`card-static ${gradient} p-5`}>
      <div className="text-xs font-medium text-muted mb-2">{label}</div>
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
    </div>
  );
}

function QuickLink({ href, icon, label, desc }: { href: string; icon: string; label: string; desc: string }) {
  return (
    <Link
      href={href}
      className="card flex items-center gap-3 p-4 group"
    >
      <div className="w-10 h-10 rounded-xl bg-primary/8 flex items-center justify-center text-primary group-hover:bg-primary group-hover:text-white transition-all flex-shrink-0">
        <QuickLinkIcon icon={icon} />
      </div>
      <div>
        <span className="text-sm font-semibold text-foreground block">{label}</span>
        <span className="text-[11px] text-muted">{desc}</span>
      </div>
    </Link>
  );
}

function QuickLinkIcon({ icon }: { icon: string }) {
  const props = { className: "w-5 h-5", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", strokeWidth: 1.5 };
  switch (icon) {
    case "clipboard": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" /></svg>;
    case "plus": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>;
    case "users": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772" /></svg>;
    case "gadget": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22" /></svg>;
    case "badge": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12" /></svg>;
    case "bookmark": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" /></svg>;
    case "ranking": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625z" /></svg>;
    case "settings": return <svg {...props}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87" /></svg>;
    default: return <svg {...props}><circle cx="12" cy="12" r="3" /></svg>;
  }
}
