"use client";

import { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { usePathname } from "next/navigation";

const adminNav = [
  { href: "/admin", label: "ダッシュボード" },
  { href: "/admin/stats", label: "統計・分析" },
  { href: "/admin/segments", label: "セグメント" },
  { href: "/admin/users", label: "ユーザー" },
  { href: "/admin/certification", label: "公式認証" },
  { href: "/admin/broadcast", label: "ブロードキャスト" },
  { href: "/admin/articles", label: "記事" },
  { href: "/admin/faq", label: "FAQ管理" },
  { href: "/admin/feedback", label: "フィードバック" },
  { href: "/admin/reports", label: "通報管理" },
  { href: "/admin/campaigns", label: "キャンペーン" },
  { href: "/admin/sponsors", label: "スポンサー" },
  { href: "/admin/surveys", label: "アンケート" },
  { href: "/admin/seasons", label: "シーズン" },
  { href: "/admin/reminders", label: "リマインダー" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const pathname = usePathname();
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null);

  useEffect(() => {
    let cancelled = false;
    if (!user) {
      const t = setTimeout(() => {
        if (!cancelled) setIsAdmin(false);
      }, 0);
      return () => {
        cancelled = true;
        clearTimeout(t);
      };
    }
    getDoc(doc(db, "users", user.uid))
      .then((snap) => {
        if (!cancelled) setIsAdmin(snap.exists() && snap.data()?.isAdmin === true);
      })
      .catch(() => {
        if (!cancelled) setIsAdmin(false);
      });
    return () => {
      cancelled = true;
    };
  }, [user]);

  if (loading || isAdmin === null) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <div className="text-4xl mb-4">🔒</div>
        <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
        <Link href="/login" className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">
          ログイン
        </Link>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <div className="text-4xl mb-4">🚫</div>
        <h3 className="text-lg font-bold text-foreground mb-2">権限がありません</h3>
        <p className="text-sm text-muted">このページは管理者専用です</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen">
      <aside className="w-52 border-r border-gray-200 bg-white flex-shrink-0">
        <div className="px-5 py-4 border-b border-gray-100">
          <div className="text-xs text-muted font-semibold uppercase tracking-wider">管理</div>
          <div className="text-base font-bold text-foreground mt-0.5">管理者メニュー</div>
        </div>
        <nav className="p-2 space-y-0.5">
          {adminNav.map((item) => {
            const active =
              item.href === "/admin"
                ? pathname === "/admin"
                : pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`block px-3 py-2 rounded-lg text-sm transition-colors ${
                  active
                    ? "bg-primary/10 text-primary font-semibold"
                    : "text-muted hover:bg-gray-50 hover:text-foreground"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </aside>
      <div className="flex-1 min-w-0">{children}</div>
    </div>
  );
}
