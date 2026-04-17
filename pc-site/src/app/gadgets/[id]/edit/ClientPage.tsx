"use client";

import { useEffect, useState } from "react";
import { doc, onSnapshot, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";

const categories = [
  "カテゴリなし",
  "ラケット",
  "シューズ",
  "ボール",
  "ウェア",
  "サポーター",
  "バッグ",
  "プロテクター",
  "トレーニング用品",
  "その他",
];

export default function GadgetEditPage() {
  const params = useParams<{ id: string }>();
  const id = (params?.id ?? "") as string;
  const router = useRouter();
  const { user, loading: authLoading } = useAuth();

  const [name, setName] = useState("");
  const [category, setCategory] = useState("カテゴリなし");
  const [memo, setMemo] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    if (!user) return;
    const unsub = onSnapshot(
      doc(db, "users", user.uid, "gadgets", id),
      (snap) => {
        if (!snap.exists()) {
          setNotFound(true);
          setLoading(false);
          return;
        }
        const d = snap.data();
        setName(d.name ?? "");
        setCategory(d.category ?? "カテゴリなし");
        setMemo(d.memo ?? "");
        setImageUrl(d.imageUrl ?? "");
        setLoading(false);
      },
      () => {
        setNotFound(true);
        setLoading(false);
      }
    );
    return () => unsub();
  }, [id, user]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    if (!name.trim()) {
      setError("商品名を入力してください");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await updateDoc(doc(db, "users", user.uid, "gadgets", id), {
        name: name.trim(),
        category,
        memo: memo.trim() || null,
      });
      router.push("/gadgets");
    } catch {
      setError("ガジェットの更新に失敗しました");
      setSaving(false);
    }
  };

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-8 max-w-[800px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ログインが必要です</p>
        <Link href="/login" className="inline-block mt-4 text-primary text-sm hover:underline">ログイン</Link>
      </div>
    );
  }

  if (notFound) {
    return (
      <div className="p-8 max-w-[800px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ガジェットが見つかりません</p>
        <Link href="/gadgets" className="inline-block mt-4 text-primary text-sm hover:underline">ガジェット一覧へ</Link>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/gadgets" className="hover:text-primary transition-colors">ガジェット</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">編集</span>
      </nav>

      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">ガジェットを編集</h1>
      </div>

      {imageUrl && (
        <div className="flex justify-center mb-6">
          <div className="w-28 h-28 rounded-xl border border-gray-200 bg-white overflow-hidden">
            <img src={imageUrl} alt="" className="w-full h-full object-contain" />
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
        {error && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              商品名 <span className="text-error">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">カテゴリ</label>
            <div className="flex flex-wrap gap-2">
              {categories.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setCategory(c)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                    category === c ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"
                  }`}
                >
                  {c}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">メモ</label>
            <textarea
              value={memo}
              onChange={(e) => setMemo(e.target.value)}
              rows={3}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
              placeholder="使用感や気に入っているポイントなど..."
            />
          </div>

          <div className="flex gap-3 pt-4 border-t border-gray-100">
            <button
              type="submit"
              disabled={saving}
              className="px-8 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {saving ? "保存中..." : "変更を保存"}
            </button>
            <Link
              href="/gadgets"
              className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
            >
              キャンセル
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}
