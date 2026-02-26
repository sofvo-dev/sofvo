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
      // 主催大会を取得
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
      <div className="p-8 max-w-[1200px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">マイページを表示するにはログインしてください</p>
          <Link
            href="/login"
            className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Profile Header */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <div className="flex items-center gap-6">
          <div className="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-2xl flex-shrink-0 overflow-hidden">
            {profile.avatarUrl ? (
              <img src={profile.avatarUrl} alt="" className="w-20 h-20 object-cover" />
            ) : (
              profile.nickname?.charAt(0) || "U"
            )}
          </div>
          <div className="flex-1">
            <h1 className="text-xl font-bold text-foreground">{profile.nickname}</h1>
            {profile.searchId && (
              <p className="text-sm text-muted">@{profile.searchId}</p>
            )}
            {profile.bio && (
              <p className="text-sm text-muted mt-1">{profile.bio}</p>
            )}
            <div className="flex gap-6 mt-3 text-sm">
              <span className="text-muted">
                <span className="font-bold text-foreground">{profile.followingCount ?? 0}</span> フォロー
              </span>
              <span className="text-muted">
                <span className="font-bold text-foreground">{profile.followersCount ?? 0}</span> フォロワー
              </span>
            </div>
          </div>
          <Link
            href="/settings"
            className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
          >
            設定
          </Link>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-4 mb-6">
        <StatCard label="総合ポイント" value={profile.totalPoints ?? 0} color="text-primary" />
        <StatCard label="大会参加数" value={profile.stats?.tournamentsPlayed ?? 0} color="text-foreground" />
        <StatCard label="優勝回数" value={profile.stats?.championships ?? 0} color="text-accent" />
        <StatCard label="フォロワー" value={profile.followersCount ?? 0} color="text-foreground" />
      </div>

      {/* Quick Links */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <QuickLink href="/tournaments/manage" icon="📋" label="大会管理" />
        <QuickLink href="/tournaments/create" icon="➕" label="大会作成" />
        <QuickLink href="/teams" icon="👥" label="チーム管理" />
        <QuickLink href="/gadgets" icon="🎒" label="ガジェット" />
        <QuickLink href="/badges" icon="🏅" label="バッジ" />
        <QuickLink href="/bookmarks" icon="🔖" label="ブックマーク" />
        <QuickLink href="/rankings" icon="🏆" label="ランキング" />
        <QuickLink href="/settings" icon="⚙️" label="設定" />
      </div>

      {/* My Tournaments */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-foreground">主催した大会</h2>
          <Link href="/tournaments/manage" className="text-sm text-primary hover:underline">
            すべて見る
          </Link>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : myTournaments.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-xl border border-gray-200 text-muted text-sm">
            まだ大会を主催していません
          </div>
        ) : (
          <div className="space-y-3">
            {myTournaments.map((t) => (
              <Link
                key={t.id}
                href={`/tournament/${t.id}`}
                className="flex items-center gap-4 bg-white rounded-xl border border-gray-200 p-4 hover:shadow-lg hover:border-primary/30 transition-all group"
              >
                <StatusBadge status={t.status} />
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">
                    {t.title}
                  </h3>
                  <span className="text-xs text-muted">{t.date} - {t.location}</span>
                </div>
                <span className="text-sm text-muted">{t.currentTeams ?? 0}/{t.maxTeams}チーム</span>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5">
      <div className="text-sm text-muted mb-1">{label}</div>
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
    </div>
  );
}

function QuickLink({ href, icon, label }: { href: string; icon: string; label: string }) {
  return (
    <Link
      href={href}
      className="flex items-center gap-3 bg-white rounded-xl border border-gray-200 p-4 hover:shadow-md hover:border-primary/30 transition-all"
    >
      <span className="text-xl">{icon}</span>
      <span className="text-sm font-medium text-foreground">{label}</span>
    </Link>
  );
}
