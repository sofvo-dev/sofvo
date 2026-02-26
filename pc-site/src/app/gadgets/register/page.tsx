"use client";

import { useState } from "react";
import {
  collection,
  addDoc,
  doc,
  updateDoc,
  increment,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useRouter } from "next/navigation";

const categories = [
  "ラケット",
  "シューズ",
  "ウェア",
  "ボール",
  "サポーター",
  "その他",
];

export default function GadgetRegisterPage() {
  const router = useRouter();
  const { user, profile, loading: authLoading } = useAuth();

  const [name, setName] = useState("");
  const [category, setCategory] = useState("ラケット");
  const [description, setDescription] = useState("");
  const [memo, setMemo] = useState("");
  const [url, setUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    if (!name.trim()) {
      setError("名前を入力してください");
      return;
    }

    setSubmitting(true);
    setError("");

    try {
      // Add gadget to subcollection
      await addDoc(collection(db, "users", user.uid, "gadgets"), {
        name: name.trim(),
        category,
        description: description.trim() || null,
        memo: memo.trim() || null,
        url: url.trim() || null,
        createdAt: serverTimestamp(),
      });

      // Increment gadgetCount on the user document
      await updateDoc(doc(db, "users", user.uid), {
        gadgetCount: increment(1),
      });

      // Redirect to gadgets list
      router.push("/gadgets");
    } catch {
      setError("ガジェットの登録に失敗しました");
      setSubmitting(false);
    }
  };

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Login required guard
  if (!user || !profile) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            ログインが必要です
          </h3>
          <p className="text-sm text-muted mb-6">
            ガジェット登録にはログインが必要です
          </p>
          <Link
            href="/login"
            className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      {/* Breadcrumb */}
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link
          href="/gadgets"
          className="hover:text-primary transition-colors"
        >
          ガジェット
        </Link>
        <svg
          className="w-4 h-4 text-gray-300"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M9 5l7 7-7 7"
          />
        </svg>
        <span className="text-foreground font-medium">登録</span>
      </nav>

      {/* Page Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">
          ガジェット登録
        </h1>
        <p className="text-sm text-muted mt-1">
          使用している用具・装備を登録します
        </p>
      </div>

      {/* Form */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
        {error && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Name */}
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              名前 <span className="text-error">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例: ヨネックス ナノフレア700"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
              required
            />
            <p className="text-xs text-muted mt-1">
              商品名やモデル名を入力してください
            </p>
          </div>

          {/* Category */}
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              カテゴリ <span className="text-error">*</span>
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
            >
              {categories.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              説明
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={4}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
              placeholder="スペックや特徴、使用感など..."
            />
          </div>

          {/* Memo */}
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              メモ
            </label>
            <textarea
              value={memo}
              onChange={(e) => setMemo(e.target.value)}
              rows={2}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
              placeholder="購入日やカスタマイズ情報など..."
            />
          </div>

          {/* URL */}
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              URL
            </label>
            <input
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://example.com/product"
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
            <p className="text-xs text-muted mt-1">
              商品ページや参考リンクがあれば入力してください
            </p>
          </div>

          {/* Buttons */}
          <div className="flex gap-3 pt-4 border-t border-gray-100">
            <button
              type="submit"
              disabled={submitting}
              className="px-8 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {submitting ? "登録中..." : "ガジェットを登録"}
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
