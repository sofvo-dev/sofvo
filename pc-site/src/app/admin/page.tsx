"use client";

import { useEffect, useState } from "react";
import { collection, getCountFromServer } from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface Stat {
  label: string;
  value: number | string;
  href?: string;
}

export default function AdminDashboard() {
  const [stats, setStats] = useState<Stat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      try {
        const [users, tournaments, posts, recruitments, venues, feedback] = await Promise.all([
          getCountFromServer(collection(db, "users")),
          getCountFromServer(collection(db, "tournaments")),
          getCountFromServer(collection(db, "posts")),
          getCountFromServer(collection(db, "recruitments")),
          getCountFromServer(collection(db, "venues")),
          getCountFromServer(collection(db, "feedback")).catch(() => null),
        ]);
        setStats([
          { label: "登録ユーザー", value: users.data().count, href: "/admin/users" },
          { label: "大会数", value: tournaments.data().count, href: "/tournaments" },
          { label: "投稿数", value: posts.data().count },
          { label: "募集数", value: recruitments.data().count },
          { label: "会場数", value: venues.data().count, href: "/venues" },
          { label: "フィードバック", value: feedback?.data().count ?? 0, href: "/admin/feedback" },
        ]);
      } catch {
        // ignore
      }
      setLoading(false);
    }
    load();
  }, []);

  return (
    <div className="p-8 max-w-[1100px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">管理ダッシュボード</h1>
      <p className="text-sm text-muted mb-6">
        管理者専用の運営ツールとサービス全体の統計を確認できます
      </p>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-8">
          {stats.map((s) => {
            const card = (
              <div className="bg-white rounded-xl border border-gray-200 p-5">
                <div className="text-xs text-muted mb-1">{s.label}</div>
                <div className="text-2xl font-bold text-foreground">
                  {typeof s.value === "number" ? s.value.toLocaleString() : s.value}
                </div>
              </div>
            );
            return s.href ? (
              <Link key={s.label} href={s.href} className="hover:shadow-md transition-shadow">
                {card}
              </Link>
            ) : (
              <div key={s.label}>{card}</div>
            );
          })}
        </div>
      )}

      <h2 className="text-base font-bold text-foreground mb-3">クイックアクセス</h2>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        <AdminTile href="/admin/broadcast" title="ブロードキャスト" desc="ユーザーへ一斉メッセージ" />
        <AdminTile href="/admin/articles" title="記事管理" desc="お知らせ・記事の投稿" />
        <AdminTile href="/admin/faq" title="FAQ管理" desc="よくある質問の編集" />
        <AdminTile href="/admin/feedback" title="フィードバック" desc="ユーザー投稿を確認" />
        <AdminTile href="/admin/reports" title="通報管理" desc="不適切コンテンツ対応" />
        <AdminTile href="/admin/campaigns" title="キャンペーン" desc="開催中のキャンペーン" />
        <AdminTile href="/admin/sponsors" title="スポンサー" desc="スポンサー枠の管理" />
        <AdminTile href="/admin/surveys" title="アンケート" desc="ユーザー調査の実施" />
        <AdminTile href="/admin/users" title="ユーザー" desc="ユーザー一覧・検索" />
        <AdminTile href="/admin/certification" title="公式認証" desc="公式バッジの付与" />
        <AdminTile href="/admin/segments" title="セグメント" desc="属性別ユーザー集計" />
        <AdminTile href="/admin/seasons" title="シーズン" desc="シーズン期間・ポイント管理" />
        <AdminTile href="/admin/reminders" title="リマインダー" desc="自動通知の設定" />
        <AdminTile href="/admin/stats" title="統計・分析" desc="利用状況の詳細" />
      </div>
    </div>
  );
}

function AdminTile({ href, title, desc }: { href: string; title: string; desc: string }) {
  return (
    <Link
      href={href}
      className="block bg-white rounded-xl border border-gray-200 p-4 hover:shadow-md hover:border-primary/20 transition-all"
    >
      <div className="text-sm font-bold text-foreground">{title}</div>
      <div className="text-xs text-muted mt-1">{desc}</div>
    </Link>
  );
}
