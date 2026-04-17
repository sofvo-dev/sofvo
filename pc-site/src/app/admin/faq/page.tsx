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
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface FaqEntry {
  id: string;
  category?: string;
  question: string;
  answer: string;
  sortOrder?: number;
  createdAt?: unknown;
}

export default function AdminFaqPage() {
  const [items, setItems] = useState<FaqEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [formCategory, setFormCategory] = useState("");
  const [formQuestion, setFormQuestion] = useState("");
  const [formAnswer, setFormAnswer] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "faq"), orderBy("sortOrder", "asc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as FaqEntry)));
        setLoading(false);
      },
      () => {
        // fallback without sortOrder
        const q2 = query(collection(db, "faq"), orderBy("createdAt", "desc"));
        const unsub2 = onSnapshot(
          q2,
          (snap) => {
            setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as FaqEntry)));
            setLoading(false);
          },
          () => setLoading(false)
        );
        return unsub2;
      }
    );
    return () => unsub();
  }, []);

  const resetForm = () => {
    setEditingId(null);
    setFormCategory("");
    setFormQuestion("");
    setFormAnswer("");
    setShowForm(false);
  };

  const startEdit = (f: FaqEntry) => {
    setEditingId(f.id);
    setFormCategory(f.category ?? "");
    setFormQuestion(f.question);
    setFormAnswer(f.answer);
    setShowForm(true);
  };

  const submit = async () => {
    if (!formQuestion.trim() || !formAnswer.trim()) {
      alert("質問と回答を入力してください");
      return;
    }
    setSaving(true);
    try {
      if (editingId) {
        await updateDoc(doc(db, "faq", editingId), {
          category: formCategory.trim() || null,
          question: formQuestion.trim(),
          answer: formAnswer.trim(),
          updatedAt: serverTimestamp(),
        });
      } else {
        await addDoc(collection(db, "faq"), {
          category: formCategory.trim() || null,
          question: formQuestion.trim(),
          answer: formAnswer.trim(),
          sortOrder: items.length,
          createdAt: serverTimestamp(),
        });
      }
      resetForm();
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (f: FaqEntry) => {
    if (!confirm(`「${f.question}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "faq", f.id));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">FAQ管理</h1>
          <p className="text-sm text-muted mt-1">よくある質問の編集・追加</p>
        </div>
        <button
          onClick={() => {
            if (showForm) resetForm();
            else setShowForm(true);
          }}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規追加"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm">
          <h2 className="text-base font-bold text-foreground mb-4">
            {editingId ? "質問を編集" : "新しい質問を追加"}
          </h2>
          <div className="space-y-3">
            <input
              type="text"
              value={formCategory}
              onChange={(e) => setFormCategory(e.target.value)}
              placeholder="カテゴリ (例: アカウント)"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <input
              type="text"
              value={formQuestion}
              onChange={(e) => setFormQuestion(e.target.value)}
              placeholder="質問"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <textarea
              value={formAnswer}
              onChange={(e) => setFormAnswer(e.target.value)}
              rows={5}
              placeholder="回答"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
            />
            <div className="flex gap-2">
              <button
                onClick={submit}
                disabled={saving}
                className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {saving ? "保存中..." : "保存"}
              </button>
              <button
                onClick={resetForm}
                className="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground"
              >
                キャンセル
              </button>
            </div>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">質問がまだありません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((f) => (
            <div key={f.id} className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  {f.category && (
                    <div className="text-xs text-muted mb-1">{f.category}</div>
                  )}
                  <div className="text-sm font-semibold text-foreground">{f.question}</div>
                  <p className="text-xs text-muted mt-1 whitespace-pre-wrap line-clamp-3">
                    {f.answer}
                  </p>
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button
                    onClick={() => startEdit(f)}
                    className="text-xs text-primary hover:underline"
                  >
                    編集
                  </button>
                  <button
                    onClick={() => remove(f)}
                    className="text-xs text-error hover:underline"
                  >
                    削除
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
