"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  limit as fbLimit,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface HistoryEntry {
  id: string;
  tournamentId?: string;
  tournamentName?: string;
  title?: string;
  rank?: number;
  points?: number;
  date?: string;
  createdAt?: unknown;
}

interface PostSummary {
  id: string;
  text: string;
  likesCount?: number;
  commentsCount?: number;
  createdAt?: unknown;
}

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (ts instanceof Date) d = ts;
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleDateString("ja-JP", { month: "numeric", day: "numeric" });
}

export default function MyPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [posts, setPosts] = useState<PostSummary[]>([]);
  const [pointHistory, setPointHistory] = useState<HistoryEntry[]>([]);

  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, "users", user.uid, "tournamentHistory"),
      orderBy("createdAt", "desc"),
      fbLimit(20)
    );
    const unsub = onSnapshot(q, (snap) => {
      setHistory(snap.docs.map((d) => ({ id: d.id, ...d.data() } as HistoryEntry)));
    }, () => {});
    return () => unsub();
  }, [user]);

  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, "posts"),
      where("userId", "==", user.uid),
      orderBy("createdAt", "desc"),
      fbLimit(10)
    );
    const unsub = onSnapshot(q, (snap) => {
      setPosts(snap.docs.map((d) => ({ id: d.id, ...d.data() } as PostSummary)));
    }, () => {});
    return () => unsub();
  }, [user]);

  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, "users", user.uid, "pointHistory"),
      orderBy("createdAt", "desc"),
      fbLimit(20)
    );
    const unsub = onSnapshot(q, (snap) => {
      setPointHistory(snap.docs.map((d) => ({ id: d.id, ...d.data() } as HistoryEntry)));
    }, () => {});
    return () => unsub();
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
          <Link href="/login" className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Profile header */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
        <div className="gradient-navy px-8 py-8 relative">
          <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
          <div className="absolute bottom-[-30px] left-[20%] w-32 h-32 rounded-full bg-white/5" />
          <div className="flex items-start gap-5 relative z-10">
            <div className="w-24 h-24 rounded-2xl bg-white/15 flex items-center justify-center text-white font-bold text-3xl overflow-hidden ring-[3px] ring-white/30 shadow-lg flex-shrink-0">
              {profile.avatarUrl ? (
                <img src={profile.avatarUrl} alt="" className="w-24 h-24 object-cover" />
              ) : (
                profile.nickname?.charAt(0) || "U"
              )}
            </div>
            <div className="flex-1 min-w-0">
              <h1 className="text-2xl font-bold text-white truncate">{profile.nickname}</h1>
              {profile.searchId && (
                <p className="text-sm text-white/60 mt-0.5">@{profile.searchId}</p>
              )}
              {profile.bio && (
                <p className="text-sm text-white/80 mt-3 max-w-prose">{profile.bio}</p>
              )}
              <div className="flex flex-wrap gap-2 mt-4">
                {profile.area && (
                  <span className="px-2.5 py-1 bg-white/10 text-white/90 text-xs rounded-full">
                    📍 {typeof profile.area === "string" ? profile.area : ""}
                  </span>
                )}
                {profile.experience && (
                  <span className="px-2.5 py-1 bg-white/10 text-white/90 text-xs rounded-full">
                    🏸 経験 {profile.experience}
                  </span>
                )}
                {profile.gender && (
                  <span className="px-2.5 py-1 bg-white/10 text-white/90 text-xs rounded-full">
                    {profile.gender}
                  </span>
                )}
              </div>
            </div>
            <Link
              href="/settings"
              className="px-4 py-2 bg-white/10 backdrop-blur text-white rounded-lg text-sm font-medium hover:bg-white/20 transition-colors flex-shrink-0"
            >
              編集
            </Link>
          </div>
        </div>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-6">
        <StatCard label="通算Pt" value={profile.totalPoints ?? 0} color="text-primary" />
        <StatCard label="シーズンPt" value={profile.seasonPoints ?? 0} color="text-accent" />
        <StatCard label="大会参加" value={profile.stats?.tournamentsPlayed ?? 0} color="text-success" />
        <StatCard label="優勝" value={profile.stats?.championships ?? 0} color="text-amber-600" />
      </div>

      {/* Social counts */}
      <div className="grid grid-cols-3 gap-3 mb-6">
        <Link
          href={`/follows?uid=${user.uid}&tab=followers`}
          className="bg-white rounded-xl border border-gray-200 p-4 text-center hover:shadow-md hover:border-primary/20 transition-all"
        >
          <div className="text-2xl font-bold text-foreground">{profile.followersCount ?? 0}</div>
          <div className="text-xs text-muted mt-0.5">フォロワー</div>
        </Link>
        <Link
          href={`/follows?uid=${user.uid}&tab=following`}
          className="bg-white rounded-xl border border-gray-200 p-4 text-center hover:shadow-md hover:border-primary/20 transition-all"
        >
          <div className="text-2xl font-bold text-foreground">{profile.followingCount ?? 0}</div>
          <div className="text-xs text-muted mt-0.5">フォロー中</div>
        </Link>
        <Link
          href="/follows/search"
          className="bg-white rounded-xl border border-gray-200 p-4 text-center hover:shadow-md hover:border-primary/20 transition-all flex items-center justify-center gap-1.5"
        >
          <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <span className="text-sm font-semibold text-primary">ユーザーを探す</span>
        </Link>
      </div>

      {/* Action tiles */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
        <ActionTile href="/mypage/matches" label="試合履歴" bg="bg-indigo-500/10" color="text-indigo-600" />
        <ActionTile href="/mypage/posts" label="投稿履歴" bg="bg-teal-500/10" color="text-teal-600" />
        <ActionTile href="/bookmarks" label="ブックマーク" bg="bg-blue-500/10" color="text-blue-600" />
        <ActionTile href="/badges" label="バッジ" bg="bg-amber-500/10" color="text-amber-600" />
        <ActionTile href="/gadgets" label="ガジェット" bg="bg-purple-500/10" color="text-purple-600" />
        <ActionTile href="/teams" label="チーム" bg="bg-green-500/10" color="text-green-600" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
        {/* Tournament history */}
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
            <h2 className="text-sm font-bold text-foreground">大会参加履歴</h2>
          </div>
          {history.length === 0 ? (
            <div className="p-8 text-center">
              <p className="text-sm text-muted">まだ大会に参加していません</p>
              <Link href="/tournaments" className="inline-block mt-3 text-xs text-primary font-medium hover:underline">
                大会を探す
              </Link>
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {history.slice(0, 8).map((h) => (
                <li key={h.id} className="px-5 py-3 flex items-center justify-between hover:bg-gray-50 transition-colors">
                  <Link
                    href={h.tournamentId ? `/tournament/${h.tournamentId}` : "#"}
                    className="flex-1 min-w-0"
                  >
                    <div className="text-sm font-medium text-foreground truncate">
                      {h.tournamentName || h.title || "大会"}
                    </div>
                    <div className="text-xs text-muted mt-0.5">
                      {formatDate(h.createdAt)}
                      {h.rank != null && ` · ${h.rank}位`}
                    </div>
                  </Link>
                  {h.points != null && (
                    <span className="text-sm font-bold text-accent ml-3 flex-shrink-0">
                      {h.points > 0 ? "+" : ""}{h.points}pt
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Point history */}
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
            <h2 className="text-sm font-bold text-foreground">ポイント履歴</h2>
          </div>
          {pointHistory.length === 0 ? (
            <div className="p-8 text-center">
              <p className="text-sm text-muted">ポイント履歴がありません</p>
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {pointHistory.slice(0, 8).map((p) => (
                <li key={p.id} className="px-5 py-3 flex items-center justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="text-sm text-foreground truncate">
                      {p.tournamentName || p.title || "ポイント付与"}
                    </div>
                    <div className="text-xs text-muted mt-0.5">{formatDate(p.createdAt)}</div>
                  </div>
                  {p.points != null && (
                    <span className={`text-sm font-bold ml-3 ${(p.points ?? 0) > 0 ? "text-success" : "text-error"}`}>
                      {(p.points ?? 0) > 0 ? "+" : ""}{p.points}pt
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* My posts */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
          <h2 className="text-sm font-bold text-foreground">投稿履歴</h2>
          <Link href="/feed" className="text-xs text-primary font-medium hover:underline">
            タイムラインへ
          </Link>
        </div>
        {posts.length === 0 ? (
          <div className="p-8 text-center">
            <p className="text-sm text-muted">まだ投稿がありません</p>
          </div>
        ) : (
          <ul className="divide-y divide-gray-50">
            {posts.map((p) => (
              <li key={p.id} className="px-5 py-3">
                <p className="text-sm text-foreground line-clamp-2">{p.text}</p>
                <div className="flex items-center gap-4 mt-2 text-xs text-muted">
                  <span>❤️ {p.likesCount ?? 0}</span>
                  <span>💬 {p.commentsCount ?? 0}</span>
                  <span className="ml-auto">{formatDate(p.createdAt)}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 text-center">
      <div className={`text-2xl font-bold ${color}`}>{value.toLocaleString()}</div>
      <div className="text-xs text-muted mt-0.5">{label}</div>
    </div>
  );
}

function ActionTile({ href, label, bg, color }: { href: string; label: string; bg: string; color: string }) {
  return (
    <Link
      href={href}
      className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3 hover:shadow-md hover:border-primary/20 transition-all"
    >
      <div className={`w-9 h-9 rounded-xl ${bg} ${color} flex items-center justify-center flex-shrink-0`}>
        <span className="text-base">→</span>
      </div>
      <span className="text-sm font-semibold text-foreground">{label}</span>
    </Link>
  );
}
