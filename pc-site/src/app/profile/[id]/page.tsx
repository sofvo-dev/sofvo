"use client";

import { useEffect, useState, use } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface UserProfile {
  uid: string;
  nickname: string;
  avatarUrl?: string;
  bio?: string;
  searchId?: string;
  experience?: string;
  area?: string;
  gender?: string;
  totalPoints?: number;
  followersCount?: number;
  followingCount?: number;
  stats?: {
    tournamentsPlayed?: number;
    championships?: number;
  };
}

export default function ProfilePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: userId } = use(params);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadProfile() {
      const snap = await getDoc(doc(db, "users", userId));
      if (snap.exists()) {
        setProfile({ uid: snap.id, ...snap.data() } as UserProfile);
      }
      setLoading(false);
    }
    loadProfile();
  }, [userId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="p-8 max-w-[1200px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔍</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ユーザーが見つかりません</h3>
          <Link href="/" className="text-sm text-primary hover:underline">
            ホームに戻る
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      {/* Profile Header */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <div className="flex items-center gap-6">
          <div className="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-2xl flex-shrink-0 overflow-hidden">
            {profile.avatarUrl ? (
              <img src={profile.avatarUrl} alt="" className="w-20 h-20 object-cover" />
            ) : (
              profile.nickname?.charAt(0) || "?"
            )}
          </div>
          <div className="flex-1">
            <h1 className="text-xl font-bold text-foreground">{profile.nickname}</h1>
            {profile.searchId && (
              <p className="text-sm text-muted">@{profile.searchId}</p>
            )}
            {profile.bio && (
              <p className="text-sm text-muted mt-2">{profile.bio}</p>
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
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-white rounded-xl border border-gray-200 p-5 text-center">
          <div className="text-2xl font-bold text-primary">{profile.totalPoints ?? 0}</div>
          <div className="text-sm text-muted mt-1">総合ポイント</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5 text-center">
          <div className="text-2xl font-bold text-foreground">{profile.stats?.tournamentsPlayed ?? 0}</div>
          <div className="text-sm text-muted mt-1">大会参加数</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-5 text-center">
          <div className="text-2xl font-bold text-accent">{profile.stats?.championships ?? 0}</div>
          <div className="text-sm text-muted mt-1">優勝回数</div>
        </div>
      </div>

      {/* Details */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-5 py-4 bg-gray-50 border-b border-gray-100">
          <h3 className="text-sm font-bold text-foreground">プロフィール情報</h3>
        </div>
        <div className="p-5 space-y-4">
          {profile.experience && (
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-muted">経験年数</span>
              <span className="text-sm font-medium text-foreground">{profile.experience}</span>
            </div>
          )}
          {profile.area && (
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-muted">エリア</span>
              <span className="text-sm font-medium text-foreground">
                {typeof profile.area === "string" ? profile.area : ""}
              </span>
            </div>
          )}
          {profile.gender && (
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-muted">性別</span>
              <span className="text-sm font-medium text-foreground">{profile.gender}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
