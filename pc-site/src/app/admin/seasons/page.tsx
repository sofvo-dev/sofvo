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
  getDocs,
  writeBatch,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface Season {
  id: string;
  name: string;
  startDate?: string;
  endDate?: string;
  active?: boolean;
  createdAt?: unknown;
}

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleDateString("ja-JP");
}

export default function AdminSeasonsPage() {
  const [items, setItems] = useState<Season[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [saving, setSaving] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    const q = query(collection(db, "seasons"), orderBy("startDate", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Season)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const resetForm = () => {
    setEditingId(null);
    setName("");
    setStartDate("");
    setEndDate("");
    setShowForm(false);
  };

  const startEdit = (s: Season) => {
    setEditingId(s.id);
    setName(s.name);
    setStartDate(s.startDate ?? "");
    setEndDate(s.endDate ?? "");
    setShowForm(true);
  };

  const submit = async () => {
    if (!name.trim()) { alert("シーズン名を入力してください"); return; }
    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        startDate: startDate || null,
        endDate: endDate || null,
        updatedAt: serverTimestamp(),
      };
      if (editingId) {
        await updateDoc(doc(db, "seasons", editingId), payload);
      } else {
        await addDoc(collection(db, "seasons"), { ...payload, active: false, createdAt: serverTimestamp() });
      }
      resetForm();
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const setActive = async (s: Season) => {
    if (!confirm(`シーズン「${s.name}」をアクティブにしますか？他のシーズンはすべて非アクティブになります。`)) return;
    const batch = writeBatch(db);
    items.forEach((item) => {
      batch.update(doc(db, "seasons", item.id), { active: item.id === s.id });
    });
    await batch.commit();
  };

  const remove = async (s: Season) => {
    if (!confirm(`シーズン「${s.name}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "seasons", s.id));
  };

  const resetSeasonPoints = async () => {
    if (!confirm("全ユーザーのシーズンポイントを0にリセットしますか？\n※ 通算ポイントは変更されません")) return;
    setResetting(true);
    setMessage("");
    try {
      const snap = await getDocs(collection(db, "users"));
      const batches: ReturnType<typeof writeBatch>[] = [];
      let currentBatch = writeBatch(db);
      let count = 0;
      for (const d of snap.docs) {
        currentBatch.update(d.ref, { seasonPoints: 0 });
        count++;
        if (count % 400 === 0) {
          batches.push(currentBatch);
          currentBatch = writeBatch(db);
        }
      }
      batches.push(currentBatch);
      await Promise.all(batches.map((b) => b.commit()));
      setMessage(`${count}人のシーズンポイントをリセットしました`);
    } catch {
      setMessage("リセットに失敗しました");
    } finally {
      setResetting(false);
    }
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">シーズン管理</h1>
          <p className="text-sm text-muted mt-1">シーズン期間の設定・ポイントのリセット</p>
        </div>
        <button
          onClick={() => (showForm ? resetForm() : setShowForm(true))}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規シーズン"}
        </button>
      </div>

      {message && (
        <div className={`mb-4 p-3 border text-sm rounded-lg ${message.includes("失敗") ? "bg-red-50 border-red-200 text-error" : "bg-green-50 border-green-200 text-green-700"}`}>
          {message}
        </div>
      )}

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm space-y-3">
          <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="シーズン名 (例: 2026春シーズン)" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <div className="grid grid-cols-2 gap-3">
            <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
            <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          </div>
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
          <p className="text-sm text-muted">シーズンがありません</p>
        </div>
      ) : (
        <div className="space-y-2 mb-6">
          {items.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  {s.active && (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-success/10 text-success font-medium">
                      アクティブ
                    </span>
                  )}
                  <span className="text-sm font-semibold text-foreground">{s.name}</span>
                </div>
                <div className="text-xs text-muted mt-0.5">
                  {s.startDate ?? "-"} 〜 {s.endDate ?? "-"} · 作成 {formatDate(s.createdAt)}
                </div>
              </div>
              <div className="flex gap-2 flex-shrink-0">
                {!s.active && (
                  <button onClick={() => setActive(s)} className="text-xs text-primary hover:underline">
                    アクティブに
                  </button>
                )}
                <button onClick={() => startEdit(s)} className="text-xs text-muted hover:text-foreground hover:underline">編集</button>
                <button onClick={() => remove(s)} className="text-xs text-error hover:underline">削除</button>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="bg-white rounded-xl border border-red-200 p-6">
        <h2 className="text-base font-bold text-error mb-3">シーズンポイントリセット</h2>
        <p className="text-sm text-muted mb-4">
          全ユーザーの <code className="text-xs bg-gray-100 px-1.5 py-0.5 rounded">seasonPoints</code> を0にします。新シーズン開始時に実行してください。
        </p>
        <button
          onClick={resetSeasonPoints}
          disabled={resetting}
          className="px-5 py-2.5 bg-error text-white rounded-lg text-sm font-medium hover:bg-red-700 transition-colors disabled:opacity-50"
        >
          {resetting ? "リセット中..." : "シーズンポイントをリセット"}
        </button>
      </div>
    </div>
  );
}
