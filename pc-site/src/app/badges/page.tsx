"use client";

import { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { BadgeDefinition } from "@/types/firestore";
import Link from "next/link";

interface UserStats {
  tournamentsPlayed: number;
  championships: number;
  totalPoints: number;
  gadgetCount: number;
  followersCount: number;
  postsCount: number;
}

const BADGE_DEFINITIONS: Omit<BadgeDefinition, "currentValue">[] = [
  { id: "tournament-1", name: "初参加", description: "大会に1回参加", icon: "🏐", color: "blue", threshold: 1 },
  { id: "tournament-5", name: "5大会参加", description: "大会に5回参加", icon: "🏐", color: "blue", threshold: 5 },
  { id: "tournament-10", name: "10大会参加", description: "大会に10回参加", icon: "🏟️", color: "blue", threshold: 10 },
  { id: "tournament-20", name: "20大会参加", description: "大会に20回参加", icon: "🌟", color: "blue", threshold: 20 },
  { id: "championship-1", name: "初優勝", description: "大会で1回優勝", icon: "🏆", color: "yellow", threshold: 1 },
  { id: "championship-3", name: "3回優勝", description: "大会で3回優勝", icon: "🏆", color: "yellow", threshold: 3 },
  { id: "championship-5", name: "5回優勝", description: "大会で5回優勝", icon: "👑", color: "yellow", threshold: 5 },
  { id: "points-100", name: "100Pt達成", description: "総合ポイント100達成", icon: "💎", color: "green", threshold: 100 },
  { id: "points-500", name: "500Pt達成", description: "総合ポイント500達成", icon: "💎", color: "green", threshold: 500 },
  { id: "points-1000", name: "1000Pt達成", description: "総合ポイント1000達成", icon: "💎", color: "green", threshold: 1000 },
  { id: "gadget-5", name: "ガジェット5個", description: "ガジェットを5個登録", icon: "🎒", color: "purple", threshold: 5 },
  { id: "followers-10", name: "フォロワー10", description: "フォロワー10人達成", icon: "👥", color: "pink", threshold: 10 },
  { id: "followers-50", name: "フォロワー50", description: "フォロワー50人達成", icon: "👥", color: "pink", threshold: 50 },
  { id: "posts-10", name: "投稿10件", description: "投稿を10件作成", icon: "📝", color: "pink", threshold: 10 },
];

function getStatValue(stats: UserStats, badgeId: string): number {
  if (badgeId.startsWith("tournament-")) return stats.tournamentsPlayed;
  if (badgeId.startsWith("championship-")) return stats.championships;
  if (badgeId.startsWith("points-")) return stats.totalPoints;
  if (badgeId.startsWith("gadget-")) return stats.gadgetCount;
  if (badgeId.startsWith("followers-")) return stats.followersCount;
  if (badgeId.startsWith("posts-")) return stats.postsCount;
  return 0;
}

const colorMap: Record<string, { border: string; bg: string; ring: string; text: string; progressBg: string; progressBar: string }> = {
  blue: {
    border: "border-blue-400",
    bg: "bg-blue-50",
    ring: "ring-blue-200",
    text: "text-blue-600",
    progressBg: "bg-blue-100",
    progressBar: "bg-blue-500",
  },
  yellow: {
    border: "border-yellow-400",
    bg: "bg-yellow-50",
    ring: "ring-yellow-200",
    text: "text-yellow-600",
    progressBg: "bg-yellow-100",
    progressBar: "bg-yellow-500",
  },
  green: {
    border: "border-green-400",
    bg: "bg-green-50",
    ring: "ring-green-200",
    text: "text-green-600",
    progressBg: "bg-green-100",
    progressBar: "bg-green-500",
  },
  pink: {
    border: "border-pink-400",
    bg: "bg-pink-50",
    ring: "ring-pink-200",
    text: "text-pink-600",
    progressBg: "bg-pink-100",
    progressBar: "bg-pink-500",
  },
  purple: {
    border: "border-purple-400",
    bg: "bg-purple-50",
    ring: "ring-purple-200",
    text: "text-purple-600",
    progressBg: "bg-purple-100",
    progressBar: "bg-purple-500",
  },
};

export default function BadgesPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [stats, setStats] = useState<UserStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    async function loadStats() {
      const snap = await getDoc(doc(db, "users", user!.uid));
      if (snap.exists()) {
        const data = snap.data();
        setStats({
          tournamentsPlayed: data.stats?.tournamentsPlayed ?? 0,
          championships: data.stats?.championships ?? 0,
          totalPoints: data.totalPoints ?? 0,
          gadgetCount: data.gadgetCount ?? 0,
          followersCount: data.followersCount ?? 0,
          postsCount: data.postsCount ?? 0,
        });
      }
      setLoading(false);
    }
    loadStats();
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
          <p className="text-sm text-muted mb-6">バッジコレクションを表示するにはログインしてください</p>
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

  if (loading || !stats) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const earnedCount = BADGE_DEFINITIONS.filter(
    (b) => getStatValue(stats, b.id) >= b.threshold
  ).length;

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground">バッジコレクション</h1>
        <p className="text-sm text-muted mt-1">大会参加や活動に応じてバッジを獲得できます</p>
      </div>

      {/* Progress Card */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-8">
        <div className="flex items-center gap-6">
          <div className="flex items-center justify-center w-16 h-16 rounded-full bg-primary/10">
            <span className="text-3xl">🎖️</span>
          </div>
          <div className="flex-1">
            <div className="text-lg font-bold text-foreground mb-2">
              {earnedCount} / {BADGE_DEFINITIONS.length} バッジ獲得
            </div>
            <div className="w-full bg-gray-100 rounded-full h-3">
              <div
                className="bg-primary rounded-full h-3 transition-all duration-500"
                style={{ width: `${(earnedCount / BADGE_DEFINITIONS.length) * 100}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Badge Grid */}
      <div className="grid grid-cols-3 gap-4">
        {BADGE_DEFINITIONS.map((badge) => {
          const current = getStatValue(stats, badge.id);
          const earned = current >= badge.threshold;
          const progress = Math.min(current / badge.threshold, 1);
          const colors = colorMap[badge.color] ?? colorMap.blue;

          return (
            <div
              key={badge.id}
              className={`rounded-xl border-2 p-5 transition-all ${
                earned
                  ? `${colors.border} ${colors.bg} shadow-sm`
                  : "border-gray-200 bg-white opacity-60"
              }`}
            >
              <div className="flex items-start gap-4">
                <div
                  className={`w-12 h-12 rounded-full flex items-center justify-center text-2xl flex-shrink-0 ${
                    earned ? `${colors.bg} ring-2 ${colors.ring}` : "bg-gray-100"
                  }`}
                >
                  {earned ? badge.icon : "🔒"}
                </div>
                <div className="flex-1 min-w-0">
                  <h3
                    className={`text-sm font-bold mb-0.5 ${
                      earned ? colors.text : "text-gray-400"
                    }`}
                  >
                    {badge.name}
                  </h3>
                  <p className={`text-xs ${earned ? "text-muted" : "text-gray-400"}`}>
                    {badge.description}
                  </p>
                </div>
              </div>

              {!earned && (
                <div className="mt-3">
                  <div className="flex items-center justify-between text-xs mb-1">
                    <span className="text-gray-400">進捗</span>
                    <span className="text-gray-500 font-medium">
                      {current} / {badge.threshold}
                    </span>
                  </div>
                  <div className={`w-full ${colors.progressBg} rounded-full h-2`}>
                    <div
                      className={`${colors.progressBar} rounded-full h-2 transition-all duration-500`}
                      style={{ width: `${progress * 100}%` }}
                    />
                  </div>
                </div>
              )}

              {earned && (
                <div className="mt-3 flex items-center gap-1.5">
                  <svg className={`w-4 h-4 ${colors.text}`} fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fillRule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clipRule="evenodd"
                    />
                  </svg>
                  <span className={`text-xs font-medium ${colors.text}`}>獲得済み</span>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
