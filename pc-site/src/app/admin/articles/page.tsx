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

interface Article {
  id: string;
  title: string;
  body: string;
  excerpt?: string;
  coverImageUrl?: string;
  published?: boolean;
  authorName?: string;
  createdAt?: unknown;
  updatedAt?: unknown;
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

export default function AdminArticlesPage() {
  const [items, setItems] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [excerpt, setExcerpt] = useState("");
  const [coverImageUrl, setCoverImageUrl] = useState("");
  const [published, setPublished] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "articles"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Article)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, []);

  const resetForm = () => {
    setEditingId(null);
    setTitle("");
    setBody("");
    setExcerpt("");
    setCoverImageUrl("");
    setPublished(false);
    setShowForm(false);
  };

  const startEdit = (a: Article) => {
    setEditingId(a.id);
    setTitle(a.title);
    setBody(a.body);
    setExcerpt(a.excerpt ?? "");
    setCoverImageUrl(a.coverImageUrl ?? "");
    setPublished(a.published ?? false);
    setShowForm(true);
  };

  const submit = async () => {
    if (!title.trim() || !body.trim()) {
      alert("タイトルと本文を入力してください");
      return;
    }
    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        body: body.trim(),
        excerpt: excerpt.trim() || null,
        coverImageUrl: coverImageUrl.trim() || null,
        published,
        updatedAt: serverTimestamp(),
      };
      if (editingId) {
        await updateDoc(doc(db, "articles", editingId), payload);
      } else {
        await addDoc(collection(db, "articles"), {
          ...payload,
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

  const remove = async (a: Article) => {
    if (!confirm(`「${a.title}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "articles", a.id));
  };

  const togglePublish = async (a: Article) => {
    await updateDoc(doc(db, "articles", a.id), {
      published: !a.published,
      updatedAt: serverTimestamp(),
    });
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">記事管理</h1>
          <p className="text-sm text-muted mt-1">お知らせ・記事の投稿と編集</p>
        </div>
        <button
          onClick={() => {
            if (showForm) resetForm();
            else setShowForm(true);
          }}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規作成"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm">
          <h2 className="text-base font-bold text-foreground mb-4">
            {editingId ? "記事を編集" : "新しい記事を作成"}
          </h2>
          <div className="space-y-3">
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="タイトル"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <input
              type="text"
              value={excerpt}
              onChange={(e) => setExcerpt(e.target.value)}
              placeholder="概要 (一覧表示用)"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <input
              type="text"
              value={coverImageUrl}
              onChange={(e) => setCoverImageUrl(e.target.value)}
              placeholder="カバー画像URL (任意)"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={12}
              placeholder="本文 (Markdown対応)"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-y"
            />
            <label className="flex items-center gap-2 text-sm text-foreground">
              <input
                type="checkbox"
                checked={published}
                onChange={(e) => setPublished(e.target.checked)}
              />
              公開する
            </label>
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
          <p className="text-sm text-muted">記事がまだありません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((a) => (
            <div key={a.id} className="bg-white rounded-xl border border-gray-200 p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    {a.published ? (
                      <span className="text-[10px] px-2 py-0.5 rounded-full bg-green-100 text-green-700 font-medium">
                        公開中
                      </span>
                    ) : (
                      <span className="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-muted font-medium">
                        下書き
                      </span>
                    )}
                    <span className="text-xs text-muted">{formatDate(a.createdAt)}</span>
                  </div>
                  <div className="text-sm font-semibold text-foreground">{a.title}</div>
                  {a.excerpt && <p className="text-xs text-muted mt-1 line-clamp-2">{a.excerpt}</p>}
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button
                    onClick={() => togglePublish(a)}
                    className="text-xs text-muted hover:text-foreground hover:underline"
                  >
                    {a.published ? "非公開" : "公開"}
                  </button>
                  <button
                    onClick={() => startEdit(a)}
                    className="text-xs text-primary hover:underline"
                  >
                    編集
                  </button>
                  <button
                    onClick={() => remove(a)}
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
