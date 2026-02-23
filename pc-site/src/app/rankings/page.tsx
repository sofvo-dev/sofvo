"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  limit,
  getDocs,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface RankedUser {
  uid: string;
  nickname: string;
  avatarUrl?: string;
  totalPoints: number;
  stats?: {
    tournamentsPlayed?: number;
    championships?: number;
  };
  area?: string;
}

const rankBadge: Record<number, { bg: string; text: string; icon: string }> = {
  1: { bg: "bg-yellow-400", text: "text-yellow-900", icon: "🥇" },
  2: { bg: "bg-gray-300", text: "text-gray-800", icon: "🥈" },
  3: { bg: "bg-amber-600", text: "text-white", icon: "🥉" },
};

export default function RankingsPage() {
  const [users, setUsers] = useState<RankedUser[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadRankings() {
      const q = query(
        collection(db, "users"),
        orderBy("totalPoints", "desc"),
        limit(100)
      );
      const snap = await getDocs(q);
      const list = snap.docs.map((doc) => ({
        uid: doc.id,
        ...doc.data(),
      })) as RankedUser[];
      setUsers(list);
      setLoading(false);
    }
    loadRankings();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1000px] mx-auto">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground">ランキング</h1>
        <p className="text-sm text-muted mt-1">総合ポイントによるランキング</p>
      </div>

      {/* Top 3 */}
      {users.length >= 3 && (
        <div className="grid grid-cols-3 gap-4 mb-8">
          {/* 2nd place */}
          <div className="bg-white rounded-xl border border-gray-200 p-6 text-center mt-8">
            <div className="text-3xl mb-2">🥈</div>
            <div className="w-14 h-14 mx-auto rounded-full bg-gray-100 flex items-center justify-center text-gray-600 font-bold text-lg mb-3 overflow-hidden">
              {users[1].avatarUrl ? (
                <img src={users[1].avatarUrl} alt="" className="w-14 h-14 object-cover" />
              ) : (
                users[1].nickname?.charAt(0) || "?"
              )}
            </div>
            <div className="text-sm font-bold text-foreground truncate">{users[1].nickname}</div>
            <div className="text-lg font-bold text-primary mt-1">{users[1].totalPoints} pt</div>
          </div>
          {/* 1st place */}
          <div className="bg-white rounded-xl border-2 border-yellow-400 p-6 text-center shadow-lg">
            <div className="text-4xl mb-2">🥇</div>
            <div className="w-16 h-16 mx-auto rounded-full bg-yellow-100 flex items-center justify-center text-yellow-800 font-bold text-xl mb-3 overflow-hidden">
              {users[0].avatarUrl ? (
                <img src={users[0].avatarUrl} alt="" className="w-16 h-16 object-cover" />
              ) : (
                users[0].nickname?.charAt(0) || "?"
              )}
            </div>
            <div className="text-base font-bold text-foreground truncate">{users[0].nickname}</div>
            <div className="text-2xl font-bold text-primary mt-1">{users[0].totalPoints} pt</div>
          </div>
          {/* 3rd place */}
          <div className="bg-white rounded-xl border border-gray-200 p-6 text-center mt-8">
            <div className="text-3xl mb-2">🥉</div>
            <div className="w-14 h-14 mx-auto rounded-full bg-amber-100 flex items-center justify-center text-amber-800 font-bold text-lg mb-3 overflow-hidden">
              {users[2].avatarUrl ? (
                <img src={users[2].avatarUrl} alt="" className="w-14 h-14 object-cover" />
              ) : (
                users[2].nickname?.charAt(0) || "?"
              )}
            </div>
            <div className="text-sm font-bold text-foreground truncate">{users[2].nickname}</div>
            <div className="text-lg font-bold text-primary mt-1">{users[2].totalPoints} pt</div>
          </div>
        </div>
      )}

      {/* Full Ranking Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="text-xs text-muted border-b border-gray-100 bg-gray-50">
              <th className="px-4 py-3 text-center w-16">順位</th>
              <th className="px-4 py-3 text-left">プレイヤー</th>
              <th className="px-4 py-3 text-center">大会参加</th>
              <th className="px-4 py-3 text-center">優勝</th>
              <th className="px-4 py-3 text-right">ポイント</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, i) => {
              const rank = i + 1;
              const badge = rankBadge[rank];
              return (
                <tr
                  key={user.uid}
                  className="border-b border-gray-50 hover:bg-gray-50 transition-colors"
                >
                  <td className="px-4 py-3 text-center">
                    {badge ? (
                      <span
                        className={`inline-flex items-center justify-center w-7 h-7 rounded-full text-xs font-bold ${badge.bg} ${badge.text}`}
                      >
                        {rank}
                      </span>
                    ) : (
                      <span className="text-sm text-muted font-medium">{rank}</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/profile/${user.uid}`}
                      className="flex items-center gap-3 hover:text-primary transition-colors"
                    >
                      <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
                        {user.avatarUrl ? (
                          <img src={user.avatarUrl} alt="" className="w-8 h-8 object-cover" />
                        ) : (
                          user.nickname?.charAt(0) || "?"
                        )}
                      </div>
                      <span className="text-sm font-semibold text-foreground">
                        {user.nickname}
                      </span>
                    </Link>
                  </td>
                  <td className="px-4 py-3 text-center text-sm text-muted">
                    {user.stats?.tournamentsPlayed ?? 0}
                  </td>
                  <td className="px-4 py-3 text-center text-sm text-muted">
                    {user.stats?.championships ?? 0}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className="text-sm font-bold text-primary">
                      {user.totalPoints} pt
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>

        {users.length === 0 && (
          <div className="text-center py-16 text-muted">
            まだランキングデータがありません
          </div>
        )}
      </div>
    </div>
  );
}
