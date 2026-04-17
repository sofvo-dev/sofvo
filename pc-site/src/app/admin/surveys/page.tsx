"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface Survey {
  id: string;
  title: string;
  description?: string;
  questions?: { q: string; type: "text" | "choice"; choices?: string[] }[];
  responseCount?: number;
  status?: "draft" | "open" | "closed";
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
  return d.toLocaleDateString("ja-JP");
}

const statusLabel: Record<string, string> = {
  draft: "下書き",
  open: "公開中",
  closed: "終了",
};

export default function AdminSurveysPage() {
  const [items, setItems] = useState<Survey[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [questionsText, setQuestionsText] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "surveys"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Survey)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const submit = async () => {
    if (!title.trim()) { alert("タイトルを入力してください"); return; }
    setSaving(true);
    try {
      const questions = questionsText
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean)
        .map((q) => ({ q, type: "text" as const }));
      await addDoc(collection(db, "surveys"), {
        title: title.trim(),
        description: description.trim() || null,
        questions,
        responseCount: 0,
        status: "draft",
        createdAt: serverTimestamp(),
      });
      setTitle(""); setDescription(""); setQuestionsText(""); setShowForm(false);
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const updateStatus = async (s: Survey, status: "draft" | "open" | "closed") => {
    await updateDoc(doc(db, "surveys", s.id), { status });
  };

  const remove = async (s: Survey) => {
    if (!confirm(`「${s.title}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "surveys", s.id));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">アンケート管理</h1>
          <p className="text-sm text-muted mt-1">ユーザー調査・意見収集</p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規作成"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm space-y-3">
          <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="アンケートタイトル" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} placeholder="説明" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none" />
          <textarea value={questionsText} onChange={(e) => setQuestionsText(e.target.value)} rows={6} placeholder={"設問を1行ずつ入力\n例: Sofvoで最も使っている機能は？"} className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none" />
          <div className="flex gap-2">
            <button onClick={submit} disabled={saving} className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {saving ? "保存中..." : "下書きとして保存"}
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
          <p className="text-sm text-muted">アンケートがまだありません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-gray-200 p-4 flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
                    {statusLabel[s.status ?? "draft"]}
                  </span>
                  <span className="text-sm font-semibold text-foreground">{s.title}</span>
                </div>
                {s.description && <p className="text-xs text-muted line-clamp-2">{s.description}</p>}
                <div className="text-[10px] text-muted mt-1">
                  {s.questions?.length ?? 0}問 · {s.responseCount ?? 0}件回答 · 作成 {formatDate(s.createdAt)}
                </div>
              </div>
              <div className="flex flex-col gap-1 flex-shrink-0 text-right">
                <select
                  value={s.status ?? "draft"}
                  onChange={(e) => updateStatus(s, e.target.value as "draft" | "open" | "closed")}
                  className="text-xs px-2 py-1 border border-gray-200 rounded-md bg-white"
                >
                  <option value="draft">下書き</option>
                  <option value="open">公開中</option>
                  <option value="closed">終了</option>
                </select>
                <Link href={`/admin/surveys/${s.id}`} className="text-xs text-primary hover:underline">
                  結果を見る
                </Link>
                <button onClick={() => remove(s)} className="text-xs text-error hover:underline">削除</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
