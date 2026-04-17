"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  deleteDoc,
  doc,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface Post {
  id: string;
  text: string;
  images?: string[];
  likesCount?: number;
  commentsCount?: number;
  createdAt?: unknown;
}

function relativeTime(ts: unknown): string {
  if (!ts) return "";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "";
  const diff = Math.floor((Date.now() - d.getTime()) / 1000);
  if (diff < 60) return "たった今";
  if (diff < 3600) return `${Math.floor(diff / 60)}分前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}時間前`;
  if (diff < 2592000) return `${Math.floor(diff / 86400)}日前`;
  return d.toLocaleDateString("ja-JP");
}

export default function MyPostsPage() {
  const { user } = useAuth();
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) return;
    const q = query(
      collection(db, "posts"),
      where("userId", "==", user.uid),
      orderBy("createdAt", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setPosts(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Post)));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [user]);

  const remove = async (p: Post) => {
    if (!confirm("この投稿を削除しますか？")) return;
    await deleteDoc(doc(db, "posts", p.id));
  };

  if (!user) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ログインが必要です</p>
        <Link href="/login" className="inline-block mt-4 text-primary text-sm hover:underline">ログイン</Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[800px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/mypage" className="hover:text-primary transition-colors">マイページ</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">投稿履歴</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">自分の投稿</h1>
      <p className="text-sm text-muted mb-6">{posts.length}件の投稿</p>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : posts.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted mb-2">まだ投稿がありません</p>
          <Link href="/feed" className="inline-block text-xs text-primary font-medium hover:underline">
            投稿してみる
          </Link>
        </div>
      ) : (
        <div className="space-y-3">
          {posts.map((p) => (
            <div key={p.id} className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-start justify-between gap-3 mb-2">
                <span className="text-xs text-muted">{relativeTime(p.createdAt)}</span>
                <button
                  onClick={() => remove(p)}
                  className="text-xs text-muted hover:text-error"
                >
                  削除
                </button>
              </div>
              <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed mb-3">{p.text}</p>
              {p.images && p.images.length > 0 && (
                <div className={`${p.images.length > 1 ? "grid grid-cols-2 gap-2" : ""} mb-3`}>
                  {p.images.map((img, i) => (
                    <img
                      key={i}
                      src={img}
                      alt=""
                      className="rounded-lg max-h-60 w-full object-cover border border-gray-100"
                    />
                  ))}
                </div>
              )}
              <div className="flex items-center gap-4 pt-3 border-t border-gray-100 text-xs text-muted">
                <span>❤️ {p.likesCount ?? 0}</span>
                <span>💬 {p.commentsCount ?? 0}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
