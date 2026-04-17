"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  deleteDoc,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface FeedbackEntry {
  id: string;
  userId?: string;
  userNickname?: string;
  userEmail?: string;
  type?: string;
  subject?: string;
  message: string;
  status?: string;
  handled?: boolean;
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
  return d.toLocaleString("ja-JP");
}

export default function AdminFeedbackPage() {
  const [items, setItems] = useState<FeedbackEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "open" | "handled">("open");

  useEffect(() => {
    const q = query(collection(db, "feedback"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as FeedbackEntry)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const filtered = items.filter((f) => {
    if (filter === "open") return !f.handled;
    if (filter === "handled") return !!f.handled;
    return true;
  });

  const toggleHandled = async (f: FeedbackEntry) => {
    await updateDoc(doc(db, "feedback", f.id), { handled: !f.handled });
  };

  const remove = async (f: FeedbackEntry) => {
    if (!confirm("このフィードバックを削除しますか？")) return;
    await deleteDoc(doc(db, "feedback", f.id));
  };

  return (
    <div className="p-8 max-w-[1000px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">フィードバック</h1>
      <p className="text-sm text-muted mb-6">ユーザーから寄せられた意見・不具合報告の一覧</p>

      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 mb-4 w-fit">
        {[
          { key: "open", label: "未対応" },
          { key: "handled", label: "対応済み" },
          { key: "all", label: "すべて" },
        ].map((t) => (
          <button
            key={t.key}
            onClick={() => setFilter(t.key as "all" | "open" | "handled")}
            className={`px-4 py-1.5 text-xs font-medium rounded-md transition-colors ${
              filter === t.key ? "bg-white text-foreground shadow-sm" : "text-muted hover:text-foreground"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">
            {filter === "open"
              ? "未対応のフィードバックはありません"
              : "フィードバックはありません"}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((f) => (
            <div key={f.id} className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-start justify-between gap-3 mb-2">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    {f.type && (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
                        {f.type}
                      </span>
                    )}
                    {f.handled ? (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                        対応済み
                      </span>
                    ) : (
                      <span className="text-xs px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 font-medium">
                        未対応
                      </span>
                    )}
                    {f.subject && (
                      <span className="text-sm font-semibold text-foreground">{f.subject}</span>
                    )}
                  </div>
                  <div className="text-xs text-muted mt-1">
                    {f.userNickname || f.userEmail || "匿名"} · {formatDate(f.createdAt)}
                  </div>
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button
                    onClick={() => toggleHandled(f)}
                    className="text-xs px-3 py-1 border border-gray-300 rounded-lg font-medium text-muted hover:text-foreground hover:border-gray-400"
                  >
                    {f.handled ? "未対応に戻す" : "対応済みにする"}
                  </button>
                  <button
                    onClick={() => remove(f)}
                    className="text-xs px-3 py-1 text-error hover:underline"
                  >
                    削除
                  </button>
                </div>
              </div>
              <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed">
                {f.message}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
