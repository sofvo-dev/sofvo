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
import Link from "next/link";

interface Report {
  id: string;
  reporterId?: string;
  reporterName?: string;
  targetType?: string;
  targetId?: string;
  targetUserId?: string;
  targetUserName?: string;
  reason?: string;
  detail?: string;
  status?: string;
  handled?: boolean;
  createdAt?: unknown;
}

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleString("ja-JP");
}

export default function AdminReportsPage() {
  const [items, setItems] = useState<Report[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<"all" | "open" | "handled">("open");

  useEffect(() => {
    const q = query(collection(db, "reports"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Report)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const filtered = items.filter((r) => {
    if (filter === "open") return !r.handled;
    if (filter === "handled") return !!r.handled;
    return true;
  });

  const toggleHandled = async (r: Report) => {
    await updateDoc(doc(db, "reports", r.id), { handled: !r.handled });
  };

  const remove = async (r: Report) => {
    if (!confirm("この通報を削除しますか？")) return;
    await deleteDoc(doc(db, "reports", r.id));
  };

  return (
    <div className="p-8 max-w-[1000px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">通報管理</h1>
      <p className="text-sm text-muted mb-6">ユーザーからの不適切コンテンツ通報の対応</p>

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
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">通報はありません</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((r) => (
            <div key={r.id} className="bg-white rounded-xl border border-gray-200 p-5">
              <div className="flex items-start justify-between gap-3 mb-2">
                <div className="flex items-center gap-2 flex-wrap">
                  {r.targetType && (
                    <span className="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
                      {r.targetType === "post" ? "投稿" : r.targetType === "user" ? "ユーザー" : r.targetType}
                    </span>
                  )}
                  {r.handled ? (
                    <span className="text-xs px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                      対応済
                    </span>
                  ) : (
                    <span className="text-xs px-2 py-0.5 rounded-full bg-red-100 text-red-700 font-medium">
                      未対応
                    </span>
                  )}
                  {r.reason && (
                    <span className="text-sm font-semibold text-foreground">{r.reason}</span>
                  )}
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button
                    onClick={() => toggleHandled(r)}
                    className="text-xs px-3 py-1 border border-gray-300 rounded-lg font-medium text-muted hover:text-foreground hover:border-gray-400"
                  >
                    {r.handled ? "未対応に戻す" : "対応済みにする"}
                  </button>
                  <button onClick={() => remove(r)} className="text-xs px-3 py-1 text-error hover:underline">
                    削除
                  </button>
                </div>
              </div>

              <div className="text-xs text-muted mb-2">
                通報者: {r.reporterName ?? "匿名"} · {formatDate(r.createdAt)}
              </div>

              {r.targetUserName && (
                <div className="text-xs mb-1">
                  対象ユーザー:{" "}
                  <Link href={`/profile/${r.targetUserId}`} className="text-primary hover:underline">
                    {r.targetUserName}
                  </Link>
                </div>
              )}

              {r.detail && (
                <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed mt-2 pt-2 border-t border-gray-100">
                  {r.detail}
                </p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
