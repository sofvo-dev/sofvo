"use client";

import { use, useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface TournamentNotice {
  id: string;
  title: string;
  body: string;
  scheduledAt?: unknown;
  createdAt?: unknown;
  delivered?: boolean;
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

export default function TournamentNoticesPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user } = useAuth();
  const [organizerId, setOrganizerId] = useState("");
  const [tournamentTitle, setTournamentTitle] = useState("");
  const [items, setItems] = useState<TournamentNotice[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scheduledAt, setScheduledAt] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    async function loadTournament() {
      const snap = await getDoc(doc(db, "tournaments", id));
      if (snap.exists()) {
        setOrganizerId(snap.data().organizerId ?? "");
        setTournamentTitle(snap.data().title ?? "");
      }
    }
    loadTournament();
  }, [id]);

  useEffect(() => {
    const q = query(collection(db, "tournaments", id, "notices"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as TournamentNotice)));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [id]);

  const isOrganizer = user?.uid === organizerId;

  const submit = async () => {
    if (!title.trim() || !body.trim()) {
      setError("タイトルと本文を入力してください");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await addDoc(collection(db, "tournaments", id, "notices"), {
        title: title.trim(),
        body: body.trim(),
        scheduledAt: scheduledAt ? Timestamp.fromDate(new Date(scheduledAt)) : null,
        delivered: !scheduledAt,
        createdAt: serverTimestamp(),
      });
      setTitle(""); setBody(""); setScheduledAt(""); setShowForm(false);
    } catch {
      setError("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (n: TournamentNotice) => {
    if (!confirm(`「${n.title}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "tournaments", id, "notices", n.id));
  };

  if (!isOrganizer) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">主催者のみがお知らせを配信できます</p>
        <Link href={`/tournament/${id}`} className="inline-block mt-4 text-primary text-sm hover:underline">
          大会詳細に戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href={`/tournament/${id}`} className="hover:text-primary transition-colors">
          {tournamentTitle || "大会"}
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">お知らせ配信</span>
      </nav>

      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">お知らせ配信</h1>
          <p className="text-sm text-muted mt-1">大会参加者へのお知らせ（予約配信対応）</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規配信"}
        </button>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
          {error}
        </div>
      )}

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm space-y-3">
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="タイトル"
            className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
          />
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            rows={6}
            placeholder="本文"
            className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
          />
          <div>
            <label className="block text-xs text-muted mb-1">予約配信（任意）</label>
            <input
              type="datetime-local"
              value={scheduledAt}
              onChange={(e) => setScheduledAt(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
            />
          </div>
          <div className="flex gap-2">
            <button
              onClick={submit}
              disabled={saving}
              className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {saving ? "配信中..." : scheduledAt ? "予約配信" : "即時配信"}
            </button>
            <button onClick={() => setShowForm(false)} className="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground">キャンセル</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">お知らせがまだありません</p>
        </div>
      ) : (
        <div className="space-y-3">
          {items.map((n) => (
            <div key={n.id} className="bg-white rounded-xl border border-gray-200 p-4 flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  {n.delivered ? (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                      配信済
                    </span>
                  ) : (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-100 text-amber-700 font-medium">
                      予約中
                    </span>
                  )}
                  <span className="text-sm font-semibold text-foreground">{n.title}</span>
                </div>
                <p className="text-xs text-muted whitespace-pre-wrap line-clamp-3">{n.body}</p>
                <div className="text-[10px] text-muted mt-1">
                  {n.scheduledAt ? `予約: ${formatDate(n.scheduledAt)} · ` : ""}作成 {formatDate(n.createdAt)}
                </div>
              </div>
              <button
                onClick={() => remove(n)}
                className="text-xs text-error hover:underline flex-shrink-0"
              >
                削除
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
