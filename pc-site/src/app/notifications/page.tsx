"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  writeBatch,
  doc,
  deleteDoc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { AppNotification } from "@/types/firestore";
import Link from "next/link";

function relativeTime(date: Date): string {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return "たった今";
  if (minutes < 60) return `${minutes}分前`;
  if (hours < 24) return `${hours}時間前`;
  if (days < 7) return `${days}日前`;
  return date.toLocaleDateString("ja-JP");
}

function getNotificationIcon(type: AppNotification["type"]): { icon: string; color: string; bg: string } {
  switch (type) {
    case "like":
      return { icon: "❤️", color: "text-red-500", bg: "bg-red-50" };
    case "comment":
      return { icon: "💬", color: "text-blue-500", bg: "bg-blue-50" };
    case "follow":
      return { icon: "👤", color: "text-pink-500", bg: "bg-pink-50" };
    case "system":
      return { icon: "🔔", color: "text-gray-500", bg: "bg-gray-50" };
    default:
      return { icon: "🔔", color: "text-gray-500", bg: "bg-gray-50" };
  }
}

export default function NotificationsPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const [loading, setLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState<"all" | AppNotification["type"]>("all");

  useEffect(() => {
    if (!user) {
      const t = setTimeout(() => setLoading(false), 0);
      return () => clearTimeout(t);
    }
    async function loadNotifications() {
      const q = query(
        collection(db, "users", user!.uid, "notifications"),
        orderBy("createdAt", "desc"),
        limit(50)
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as AppNotification)
      );
      setNotifications(list);

      // Mark all unread as read
      const unread = snap.docs.filter((d) => !d.data().read);
      if (unread.length > 0) {
        const batch = writeBatch(db);
        unread.forEach((d) => {
          batch.update(doc(db, "users", user!.uid, "notifications", d.id), {
            read: true,
          });
        });
        await batch.commit();
      }

      setLoading(false);
    }
    loadNotifications();
  }, [user]);

  const handleDelete = async (notifId: string) => {
    if (!user) return;
    await deleteDoc(doc(db, "users", user.uid, "notifications", notifId));
    setNotifications((prev) => prev.filter((n) => n.id !== notifId));
  };

  const handleDeleteAll = async () => {
    if (!user || notifications.length === 0) return;
    const batch = writeBatch(db);
    notifications.forEach((n) => {
      batch.delete(doc(db, "users", user.uid, "notifications", n.id));
    });
    await batch.commit();
    setNotifications([]);
  };

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
          <p className="text-sm text-muted mb-6">通知を表示するにはログインしてください</p>
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

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">通知</h1>
          <p className="text-sm text-muted mt-1">
            {notifications.length > 0
              ? `${notifications.length}件の通知`
              : "通知はありません"}
          </p>
        </div>
        {notifications.length > 0 && (
          <button
            onClick={handleDeleteAll}
            className="px-4 py-2 text-sm text-red-500 border border-red-200 rounded-lg hover:bg-red-50 transition-colors font-medium"
          >
            すべて削除
          </button>
        )}
      </div>

      {notifications.length > 0 && (
        <div className="flex gap-2 mb-4 flex-wrap">
          {([
            { key: "all", label: "すべて" },
            { key: "like", label: "いいね" },
            { key: "comment", label: "コメント" },
            { key: "follow", label: "フォロー" },
            { key: "system", label: "システム" },
          ] as const).map((t) => {
            const count = t.key === "all" ? notifications.length : notifications.filter((n) => n.type === t.key).length;
            return (
              <button
                key={t.key}
                onClick={() => setTypeFilter(t.key)}
                className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
                  typeFilter === t.key
                    ? "bg-primary text-white"
                    : "bg-white border border-gray-200 text-muted hover:text-foreground hover:border-gray-300"
                }`}
              >
                {t.label} <span className="ml-1 opacity-70">{count}</span>
              </button>
            );
          })}
        </div>
      )}

      {(() => {
        const visible = typeFilter === "all" ? notifications : notifications.filter((n) => n.type === typeFilter);
        return visible.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔔</div>
          <h3 className="text-base font-bold text-foreground mb-1">通知はありません</h3>
          <p className="text-sm text-muted">新しい通知が届くとここに表示されます</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden divide-y divide-gray-100">
          {visible.map((notif) => {
            const { icon, bg } = getNotificationIcon(notif.type);
            const createdAt =
              notif.createdAt && typeof notif.createdAt === "object" && "toDate" in notif.createdAt
                ? (notif.createdAt as { toDate: () => Date }).toDate()
                : new Date();

            return (
              <div
                key={notif.id}
                className="flex items-start gap-4 p-4 hover:bg-gray-50 transition-colors group"
              >
                <div
                  className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 text-lg ${bg}`}
                >
                  {icon}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      {notif.senderName && (
                        <span className="text-sm font-bold text-foreground">
                          {notif.senderName}
                        </span>
                      )}
                      <p className="text-sm text-muted mt-0.5">{notif.message}</p>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <span className="text-xs text-muted whitespace-nowrap">
                        {relativeTime(createdAt)}
                      </span>
                      <button
                        onClick={() => handleDelete(notif.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 text-gray-400 hover:text-red-500 transition-all"
                        title="削除"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                          />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      );
      })()}
    </div>
  );
}
