"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  getDocs,
  deleteDoc,
  doc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Bookmark } from "@/types/firestore";
import Link from "next/link";

type TabType = "tournament" | "recruitment";

function getStatusColor(status?: string): string {
  switch (status) {
    case "募集中":
      return "bg-green-100 text-green-700";
    case "エントリー締切":
      return "bg-amber-100 text-amber-800";
    case "試合準備中":
    case "試合準備":
      return "bg-sky-100 text-sky-800";
    case "開催中":
      return "bg-blue-100 text-blue-700";
    case "終了":
      return "bg-gray-100 text-gray-500";
    default:
      return "bg-gray-100 text-gray-500";
  }
}

function getAlertStyle(alert: string): string {
  switch (alert) {
    case "締切間近":
      return "bg-orange-100 text-orange-700";
    case "残りわずか":
      return "bg-red-100 text-red-700";
    default:
      return "bg-gray-100 text-gray-500";
  }
}

export default function BookmarksPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<TabType>("tournament");

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    async function loadBookmarks() {
      const q = query(
        collection(db, "users", user!.uid, "bookmarks"),
        orderBy("createdAt", "desc")
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as Bookmark)
      );
      setBookmarks(list);
      setLoading(false);
    }
    loadBookmarks();
  }, [user]);

  const handleDelete = async (bookmarkId: string) => {
    if (!user) return;
    await deleteDoc(doc(db, "users", user.uid, "bookmarks", bookmarkId));
    setBookmarks((prev) => prev.filter((b) => b.id !== bookmarkId));
  };

  const filtered = bookmarks.filter((b) => b.type === activeTab);

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
          <p className="text-sm text-muted mb-6">ブックマークを表示するにはログインしてください</p>
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
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">ブックマーク</h1>
        <p className="text-sm text-muted mt-1">保存した大会・募集を管理</p>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 mb-6">
        <button
          onClick={() => setActiveTab("tournament")}
          className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
            activeTab === "tournament"
              ? "border-primary text-primary"
              : "border-transparent text-muted hover:text-foreground"
          }`}
        >
          大会
          <span className="ml-2 text-xs bg-gray-100 text-muted px-2 py-0.5 rounded-full">
            {bookmarks.filter((b) => b.type === "tournament").length}
          </span>
        </button>
        <button
          onClick={() => setActiveTab("recruitment")}
          className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
            activeTab === "recruitment"
              ? "border-primary text-primary"
              : "border-transparent text-muted hover:text-foreground"
          }`}
        >
          募集
          <span className="ml-2 text-xs bg-gray-100 text-muted px-2 py-0.5 rounded-full">
            {bookmarks.filter((b) => b.type === "recruitment").length}
          </span>
        </button>
      </div>

      {/* Bookmark List */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">📑</div>
          <h3 className="text-base font-bold text-foreground mb-1">
            {activeTab === "tournament" ? "保存した大会はありません" : "保存した募集はありません"}
          </h3>
          <p className="text-sm text-muted">
            {activeTab === "tournament"
              ? "大会をブックマークするとここに表示されます"
              : "募集をブックマークするとここに表示されます"}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((bookmark) => (
            <div
              key={bookmark.id}
              className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-md hover:border-primary/30 transition-all group"
            >
              <div className="flex items-start gap-4">
                <div className="flex-1 min-w-0">
                  <Link
                    href={
                      bookmark.type === "tournament"
                        ? `/tournament/${bookmark.targetId}`
                        : `/recruitment/${bookmark.targetId}`
                    }
                    className="block"
                  >
                    <h3 className="text-base font-bold text-foreground group-hover:text-primary transition-colors truncate">
                      {bookmark.title}
                    </h3>
                    <div className="flex flex-wrap items-center gap-3 mt-2">
                      {bookmark.date && (
                        <span className="flex items-center gap-1 text-sm text-muted">
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={1.5}
                              d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
                            />
                          </svg>
                          {bookmark.date}
                        </span>
                      )}
                      {bookmark.location && (
                        <span className="flex items-center gap-1 text-sm text-muted">
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={1.5}
                              d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
                            />
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              strokeWidth={1.5}
                              d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
                            />
                          </svg>
                          {bookmark.location}
                        </span>
                      )}
                    </div>
                  </Link>

                  {/* Badges */}
                  <div className="flex flex-wrap items-center gap-2 mt-3">
                    {bookmark.status && (
                      <span
                        className={`text-xs font-medium px-2.5 py-1 rounded-full ${getStatusColor(
                          bookmark.status
                        )}`}
                      >
                        {bookmark.status}
                      </span>
                    )}
                    {bookmark.alerts?.map((alert) => (
                      <span
                        key={alert}
                        className={`text-xs font-medium px-2.5 py-1 rounded-full ${getAlertStyle(alert)}`}
                      >
                        {alert}
                      </span>
                    ))}
                  </div>
                </div>

                {/* Delete button */}
                <button
                  onClick={() => handleDelete(bookmark.id)}
                  className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all opacity-0 group-hover:opacity-100 flex-shrink-0"
                  title="ブックマークを削除"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
          ))}
        </div>
      )}
    </div>
  );
}
