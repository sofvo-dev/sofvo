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

interface Campaign {
  id: string;
  title: string;
  description?: string;
  startDate?: string;
  endDate?: string;
  bannerUrl?: string;
  active?: boolean;
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

export default function AdminCampaignsPage() {
  const [items, setItems] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [bannerUrl, setBannerUrl] = useState("");
  const [active, setActive] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "campaigns"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Campaign)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const resetForm = () => {
    setEditingId(null);
    setTitle("");
    setDescription("");
    setStartDate("");
    setEndDate("");
    setBannerUrl("");
    setActive(true);
    setShowForm(false);
  };

  const startEdit = (c: Campaign) => {
    setEditingId(c.id);
    setTitle(c.title);
    setDescription(c.description ?? "");
    setStartDate(c.startDate ?? "");
    setEndDate(c.endDate ?? "");
    setBannerUrl(c.bannerUrl ?? "");
    setActive(c.active ?? true);
    setShowForm(true);
  };

  const submit = async () => {
    if (!title.trim()) { alert("タイトルを入力してください"); return; }
    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        description: description.trim() || null,
        startDate: startDate || null,
        endDate: endDate || null,
        bannerUrl: bannerUrl.trim() || null,
        active,
        updatedAt: serverTimestamp(),
      };
      if (editingId) {
        await updateDoc(doc(db, "campaigns", editingId), payload);
      } else {
        await addDoc(collection(db, "campaigns"), { ...payload, createdAt: serverTimestamp() });
      }
      resetForm();
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (c: Campaign) => {
    if (!confirm(`「${c.title}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "campaigns", c.id));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">キャンペーン管理</h1>
          <p className="text-sm text-muted mt-1">開催中のキャンペーン・告知</p>
        </div>
        <button
          onClick={() => (showForm ? resetForm() : setShowForm(true))}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規作成"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm space-y-3">
          <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="タイトル" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4} placeholder="説明" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none" />
          <div className="grid grid-cols-2 gap-3">
            <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
            <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          </div>
          <input type="text" value={bannerUrl} onChange={(e) => setBannerUrl(e.target.value)} placeholder="バナー画像URL (任意)" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
            掲載する
          </label>
          <div className="flex gap-2">
            <button onClick={submit} disabled={saving} className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {saving ? "保存中..." : "保存"}
            </button>
            <button onClick={resetForm} className="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground">キャンセル</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">キャンペーンがありません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((c) => (
            <div key={c.id} className="bg-white rounded-xl border border-gray-200 p-4 flex items-start justify-between gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  {c.active ? (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">掲載中</span>
                  ) : (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-muted font-medium">非掲載</span>
                  )}
                  <span className="text-sm font-semibold text-foreground">{c.title}</span>
                </div>
                {c.description && <p className="text-xs text-muted mt-1 line-clamp-2">{c.description}</p>}
                <div className="text-[10px] text-muted mt-1">
                  {c.startDate ?? "-"} → {c.endDate ?? "-"} · 作成 {formatDate(c.createdAt)}
                </div>
              </div>
              <div className="flex gap-2 flex-shrink-0">
                <button onClick={() => startEdit(c)} className="text-xs text-primary hover:underline">編集</button>
                <button onClick={() => remove(c)} className="text-xs text-error hover:underline">削除</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
