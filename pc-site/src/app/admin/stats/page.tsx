"use client";

import { useEffect, useState } from "react";
import {
  collection,
  getCountFromServer,
  query,
  where,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface StatCard {
  label: string;
  value: number;
  note?: string;
}

export default function AdminStatsPage() {
  const [userStats, setUserStats] = useState<StatCard[]>([]);
  const [tournamentStats, setTournamentStats] = useState<StatCard[]>([]);
  const [activityStats, setActivityStats] = useState<StatCard[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const now = Date.now();
      const thirtyDaysAgo = Timestamp.fromMillis(now - 30 * 86400_000);
      const sevenDaysAgo = Timestamp.fromMillis(now - 7 * 86400_000);

      try {
        const [
          totalUsers,
          activeUsers,
          newUsers7d,
          beginners,
          totalTournaments,
          ongoingTournaments,
          recentTournaments,
          totalPosts,
          recentPosts,
          totalRecruitments,
        ] = await Promise.all([
          getCountFromServer(collection(db, "users")),
          getCountFromServer(
            query(collection(db, "users"), where("lastActiveAt", ">=", thirtyDaysAgo))
          ).catch(() => null),
          getCountFromServer(
            query(collection(db, "users"), where("createdAt", ">=", sevenDaysAgo))
          ).catch(() => null),
          getCountFromServer(
            query(collection(db, "users"), where("experience", "==", "1年未満"))
          ).catch(() => null),
          getCountFromServer(collection(db, "tournaments")),
          getCountFromServer(
            query(collection(db, "tournaments"), where("status", "in", ["開催中", "決勝中"]))
          ).catch(() => null),
          getCountFromServer(
            query(collection(db, "tournaments"), where("createdAt", ">=", thirtyDaysAgo))
          ).catch(() => null),
          getCountFromServer(collection(db, "posts")),
          getCountFromServer(
            query(collection(db, "posts"), where("createdAt", ">=", sevenDaysAgo))
          ).catch(() => null),
          getCountFromServer(collection(db, "recruitments")),
        ]);

        setUserStats([
          { label: "登録ユーザー総数", value: totalUsers.data().count },
          { label: "アクティブ（30日）", value: activeUsers?.data().count ?? 0 },
          { label: "新規登録（7日）", value: newUsers7d?.data().count ?? 0 },
          { label: "初心者（1年未満）", value: beginners?.data().count ?? 0 },
        ]);
        setTournamentStats([
          { label: "大会総数", value: totalTournaments.data().count },
          { label: "開催中", value: ongoingTournaments?.data().count ?? 0 },
          { label: "直近30日作成", value: recentTournaments?.data().count ?? 0 },
        ]);
        setActivityStats([
          { label: "投稿総数", value: totalPosts.data().count },
          { label: "直近7日投稿", value: recentPosts?.data().count ?? 0 },
          { label: "募集総数", value: totalRecruitments.data().count },
        ]);
      } catch {
        // ignore
      }
      setLoading(false);
    }
    load();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1100px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">統計・分析</h1>
      <p className="text-sm text-muted mb-6">サービス全体の利用状況を把握できます</p>

      <Section title="ユーザー" stats={userStats} />
      <Section title="大会" stats={tournamentStats} />
      <Section title="アクティビティ" stats={activityStats} />
    </div>
  );
}

function Section({ title, stats }: { title: string; stats: StatCard[] }) {
  return (
    <section className="mb-8">
      <h2 className="text-sm font-bold text-foreground mb-3">{title}</h2>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {stats.map((s) => (
          <div key={s.label} className="bg-white rounded-xl border border-gray-200 p-4">
            <div className="text-xs text-muted mb-1">{s.label}</div>
            <div className="text-2xl font-bold text-foreground">{s.value.toLocaleString()}</div>
            {s.note && <div className="text-[10px] text-muted mt-1">{s.note}</div>}
          </div>
        ))}
      </div>
    </section>
  );
}
