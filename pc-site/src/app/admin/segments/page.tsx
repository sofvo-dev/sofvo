"use client";

import { useEffect, useState } from "react";
import {
  collection,
  getDocs,
  query,
  where,
  getCountFromServer,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface Segment {
  key: string;
  label: string;
  description: string;
  count: number | null;
}

const prefectures = [
  "北海道", "東北", "関東", "中部", "近畿", "中国", "四国", "九州・沖縄",
];

export default function AdminSegmentsPage() {
  const [segments, setSegments] = useState<Segment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const now = Date.now();
      const thirtyDaysAgo = Timestamp.fromMillis(now - 30 * 86400_000);
      const sevenDaysAgo = Timestamp.fromMillis(now - 7 * 86400_000);

      const defs: { key: string; label: string; description: string; run: () => Promise<number> }[] = [
        {
          key: "all", label: "全ユーザー", description: "登録済みのすべてのユーザー",
          run: async () => (await getCountFromServer(collection(db, "users"))).data().count,
        },
        {
          key: "active", label: "アクティブ", description: "直近30日以内にログイン",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("lastActiveAt", ">=", thirtyDaysAgo)))).data().count,
        },
        {
          key: "dormant", label: "休眠", description: "30日以上ログインなし",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("lastActiveAt", "<", thirtyDaysAgo)))).data().count,
        },
        {
          key: "beginner", label: "初心者", description: "経験「1年未満」",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("experience", "==", "1年未満")))).data().count,
        },
        {
          key: "veteran", label: "ベテラン", description: "経験「10年以上」",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("experience", "==", "10年以上")))).data().count,
        },
        {
          key: "newusers", label: "新規登録", description: "直近7日以内に登録",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("createdAt", ">=", sevenDaysAgo)))).data().count,
        },
        {
          key: "high_points", label: "ハイスコアラー", description: "通算100pt以上",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("totalPoints", ">=", 100)))).data().count,
        },
        {
          key: "admins", label: "管理者", description: "isAdmin=true",
          run: async () => (await getCountFromServer(query(collection(db, "users"), where("isAdmin", "==", true)))).data().count,
        },
      ];

      const results = await Promise.all(
        defs.map(async (d) => {
          try {
            const c = await d.run();
            return { key: d.key, label: d.label, description: d.description, count: c };
          } catch {
            return { key: d.key, label: d.label, description: d.description, count: null };
          }
        })
      );
      setSegments(results);
      setLoading(false);
    }
    load();
  }, []);

  const [areaCounts, setAreaCounts] = useState<Record<string, number> | null>(null);
  const [loadingAreas, setLoadingAreas] = useState(false);

  const loadAreaBreakdown = async () => {
    setLoadingAreas(true);
    try {
      const snap = await getDocs(collection(db, "users"));
      const counts: Record<string, number> = {};
      snap.docs.forEach((d) => {
        const area = (d.data().area as string) || "未設定";
        counts[area] = (counts[area] ?? 0) + 1;
      });
      setAreaCounts(counts);
    } finally {
      setLoadingAreas(false);
    }
  };

  return (
    <div className="p-8 max-w-[1000px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">ユーザーセグメント</h1>
      <p className="text-sm text-muted mb-6">
        属性別のユーザー数を集計。ブロードキャストや施策の対象選定に使えます
      </p>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
          {segments.map((s) => (
            <div key={s.key} className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="text-xs text-muted mb-1">{s.label}</div>
              <div className="text-2xl font-bold text-foreground">
                {s.count === null ? "-" : s.count.toLocaleString()}
              </div>
              <div className="text-[10px] text-muted mt-1">{s.description}</div>
            </div>
          ))}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-bold text-foreground">地域別集計</h2>
          <button
            onClick={loadAreaBreakdown}
            disabled={loadingAreas}
            className="text-xs text-primary hover:underline disabled:opacity-50"
          >
            {loadingAreas ? "集計中..." : areaCounts ? "再集計" : "集計する"}
          </button>
        </div>
        {areaCounts ? (
          <div className="grid grid-cols-3 md:grid-cols-5 gap-2">
            {Object.entries(areaCounts)
              .sort((a, b) => b[1] - a[1])
              .slice(0, 30)
              .map(([area, count]) => (
                <div key={area} className="px-3 py-2 bg-gray-50 rounded-lg">
                  <div className="text-xs text-muted">{area}</div>
                  <div className="text-base font-bold text-foreground">{count}</div>
                </div>
              ))}
          </div>
        ) : (
          <p className="text-xs text-muted">地域別の集計はボタンを押すと実行されます（全ユーザー取得のため時間がかかります）</p>
        )}
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5 text-xs text-muted">
        <p className="font-semibold text-foreground mb-2">備考</p>
        <ul className="list-disc list-inside space-y-1">
          <li>セグメントはブロードキャスト機能の送信対象として使用されます</li>
          <li>「休眠」「アクティブ」の定義は <code className="bg-gray-100 px-1">lastActiveAt</code> フィールドに依存します</li>
          <li>都道府県グループ: {prefectures.join(" / ")}</li>
        </ul>
      </div>
    </div>
  );
}
