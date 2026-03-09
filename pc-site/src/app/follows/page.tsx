"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { collection, getDocs, doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface FollowUser {
  uid: string;
  nickname: string;
  avatarUrl?: string;
  area?: string;
  bio?: string;
}

export default function FollowsPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>}>
      <FollowsContent />
    </Suspense>
  );
}

function FollowsContent() {
  const { user } = useAuth();
  const searchParams = useSearchParams();
  const tab = searchParams.get("tab") || "followers";
  const userId = searchParams.get("uid") || user?.uid || "";

  const [followers, setFollowers] = useState<FollowUser[]>([]);
  const [following, setFollowing] = useState<FollowUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  useEffect(() => {
    if (!userId) return;
    async function load() {
      setLoading(true);
      const colName = tab === "following" ? "following" : "followers";
      try {
        const snap = await getDocs(collection(db, "users", userId, colName));
        const uids = snap.docs.map((d) => d.id);

        // Fetch user profiles in parallel
        const users: FollowUser[] = [];
        await Promise.all(
          uids.map(async (uid) => {
            const userSnap = await getDoc(doc(db, "users", uid));
            if (userSnap.exists()) {
              const data = userSnap.data();
              users.push({
                uid,
                nickname: data.nickname || "名前なし",
                avatarUrl: data.avatarUrl,
                area: data.area,
                bio: data.bio,
              });
            }
          })
        );

        if (tab === "following") {
          setFollowing(users);
        } else {
          setFollowers(users);
        }
      } catch {
        // collection may not exist yet
      }
      setLoading(false);
    }
    load();
  }, [userId, tab]);

  const list = tab === "following" ? following : followers;
  const filtered = search
    ? list.filter(
        (u) =>
          u.nickname.toLowerCase().includes(search.toLowerCase()) ||
          (u.area || "").toLowerCase().includes(search.toLowerCase())
      )
    : list;

  return (
    <div className="p-6 md:p-8 max-w-[700px] mx-auto animate-fade-in">
      {/* Header */}
      <div className="flex items-center gap-3 mb-5">
        <Link href="/" className="text-muted hover:text-primary transition-colors">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </Link>
        <h1 className="text-lg font-bold text-foreground">
          {tab === "following" ? "フォロー中" : "フォロワー"}
        </h1>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-4 bg-gray-100 rounded-lg p-1">
        <Link
          href={`/follows?uid=${userId}&tab=followers`}
          className={`flex-1 text-center py-2 text-sm font-medium rounded-md transition-colors ${
            tab === "followers"
              ? "bg-white text-primary shadow-sm"
              : "text-muted hover:text-foreground"
          }`}
        >
          フォロワー
        </Link>
        <Link
          href={`/follows?uid=${userId}&tab=following`}
          className={`flex-1 text-center py-2 text-sm font-medium rounded-md transition-colors ${
            tab === "following"
              ? "bg-white text-primary shadow-sm"
              : "text-muted hover:text-foreground"
          }`}
        >
          フォロー中
        </Link>
      </div>

      {/* Search */}
      <div className="relative mb-4">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          placeholder="名前・地域で検索"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
        />
      </div>

      {/* List */}
      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16">
          <svg className="w-12 h-12 text-gray-300 mx-auto mb-3" fill="currentColor" viewBox="0 0 24 24">
            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
          </svg>
          <p className="text-sm text-muted">
            {search
              ? `「${search}」に一致するユーザーが見つかりません`
              : tab === "followers"
              ? "まだフォロワーがいません"
              : "まだ誰もフォローしていません"}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map((u) => (
            <Link
              key={u.uid}
              href={`/profile/${u.uid}`}
              className="flex items-center gap-3 p-3 bg-white rounded-xl border border-gray-200 hover:shadow-md hover:border-primary/20 transition-all group"
            >
              <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-base flex-shrink-0 overflow-hidden">
                {u.avatarUrl ? (
                  <img src={u.avatarUrl} alt="" className="w-11 h-11 object-cover" />
                ) : (
                  u.nickname.charAt(0) || "?"
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">
                  {u.nickname}
                </div>
                {u.area && (
                  <div className="flex items-center gap-1 mt-0.5">
                    <svg className="w-3 h-3 text-muted flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" />
                    </svg>
                    <span className="text-xs text-muted truncate">{u.area}</span>
                  </div>
                )}
                {u.bio && (
                  <p className="text-xs text-muted mt-0.5 truncate">{u.bio}</p>
                )}
              </div>
              <svg className="w-4 h-4 text-gray-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
              </svg>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
