"use client";

import { useEffect, useState, useMemo } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Gadget } from "@/types/firestore";
import Link from "next/link";
import { Timestamp } from "firebase/firestore";

type ViewMode = "card" | "list";
type SortKey = "category" | "name" | "date";

const categories = [
  "ラケット",
  "シューズ",
  "ウェア",
  "ボール",
  "サポーター",
  "その他",
];

const categoryColor: Record<string, string> = {
  ラケット: "bg-blue-100 text-blue-700",
  シューズ: "bg-green-100 text-green-700",
  ウェア: "bg-purple-100 text-purple-700",
  ボール: "bg-orange-100 text-orange-700",
  サポーター: "bg-pink-100 text-pink-700",
  その他: "bg-gray-100 text-gray-600",
};

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let date: Date;
  if (ts instanceof Timestamp) {
    date = ts.toDate();
  } else if (ts instanceof Date) {
    date = ts;
  } else if (typeof ts === "object" && ts !== null && "seconds" in ts) {
    date = new Date((ts as { seconds: number }).seconds * 1000);
  } else {
    return "-";
  }
  return date.toLocaleDateString("ja-JP");
}

export default function GadgetsPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [gadgets, setGadgets] = useState<Gadget[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewMode, setViewMode] = useState<ViewMode>("card");
  const [sortKey, setSortKey] = useState<SortKey>("date");
  const [categoryFilter, setCategoryFilter] = useState<string>("すべて");
  const [showForm, setShowForm] = useState(false);

  // Form state
  const [formName, setFormName] = useState("");
  const [formCategory, setFormCategory] = useState("ラケット");
  const [formDescription, setFormDescription] = useState("");
  const [formMemo, setFormMemo] = useState("");
  const [formUrl, setFormUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, "users", user.uid, "gadgets"),
      orderBy("createdAt", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      })) as Gadget[];
      setGadgets(list);
      setLoading(false);
    });
    return () => unsub();
  }, [user]);

  // Unique categories from gadgets
  const availableCategories = useMemo(() => {
    const cats = new Set(gadgets.map((g) => g.category));
    return ["すべて", ...Array.from(cats)];
  }, [gadgets]);

  // Filtered and sorted gadgets
  const displayGadgets = useMemo(() => {
    let filtered = gadgets;
    if (categoryFilter !== "すべて") {
      filtered = filtered.filter((g) => g.category === categoryFilter);
    }

    const sorted = [...filtered].sort((a, b) => {
      switch (sortKey) {
        case "category":
          return a.category.localeCompare(b.category, "ja");
        case "name":
          return a.name.localeCompare(b.name, "ja");
        case "date":
        default: {
          const getTime = (ts: unknown): number => {
            if (!ts) return 0;
            if (ts instanceof Timestamp) return ts.toMillis();
            if (ts instanceof Date) return ts.getTime();
            if (typeof ts === "object" && ts !== null && "seconds" in ts) {
              return (ts as { seconds: number }).seconds * 1000;
            }
            return 0;
          };
          return getTime(b.createdAt) - getTime(a.createdAt);
        }
      }
    });

    return sorted;
  }, [gadgets, categoryFilter, sortKey]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    if (!formName.trim()) {
      setFormError("名前を入力してください");
      return;
    }

    setSubmitting(true);
    setFormError("");

    try {
      await addDoc(collection(db, "users", user.uid, "gadgets"), {
        name: formName.trim(),
        category: formCategory,
        description: formDescription.trim() || null,
        memo: formMemo.trim() || null,
        url: formUrl.trim() || null,
        createdAt: serverTimestamp(),
      });

      // Reset form
      setFormName("");
      setFormCategory("ラケット");
      setFormDescription("");
      setFormMemo("");
      setFormUrl("");
      setShowForm(false);
    } catch {
      setFormError("ガジェットの登録に失敗しました");
    } finally {
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
      <div className="p-8 max-w-[1200px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            ログインが必要です
          </h3>
          <p className="text-sm text-muted mb-6">
            ガジェット管理機能を利用するにはログインしてください
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
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">ガジェット管理</h1>
          <p className="text-sm text-muted mt-1">
            自分が使っているものを登録してみよう
          </p>
          <p className="text-xs text-muted mt-0.5">
            シューズやラケットなど、普段使っている用具・装備を登録して管理できます。
          </p>
        </div>
        <div className="flex gap-2">
          <Link
            href="/gadgets/register"
            className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ガジェット登録
          </Link>
          <button
            onClick={() => setShowForm(!showForm)}
            className="px-5 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
          >
            {showForm ? "閉じる" : "クイック登録"}
          </button>
        </div>
      </div>

      {/* Quick Create Form */}
      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            クイック登録
          </h2>

          {formError && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
              {formError}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  名前 <span className="text-error">*</span>
                </label>
                <input
                  type="text"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="例: ヨネックス ナノフレア700"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  カテゴリ
                </label>
                <select
                  value={formCategory}
                  onChange={(e) => setFormCategory(e.target.value)}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
                >
                  {categories.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                説明
              </label>
              <textarea
                value={formDescription}
                onChange={(e) => setFormDescription(e.target.value)}
                rows={2}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
                placeholder="用具の説明..."
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  メモ
                </label>
                <input
                  type="text"
                  value={formMemo}
                  onChange={(e) => setFormMemo(e.target.value)}
                  placeholder="メモ（任意）"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  URL
                </label>
                <input
                  type="text"
                  value={formUrl}
                  onChange={(e) => setFormUrl(e.target.value)}
                  placeholder="商品ページURL（任意）"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                />
              </div>
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {submitting ? "登録中..." : "登録する"}
              </button>
              <button
                type="button"
                onClick={() => setShowForm(false)}
                className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
              >
                キャンセル
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Controls: View mode, Sort, Filter */}
      <div className="flex items-center justify-between mb-6 flex-wrap gap-4">
        {/* Category filter */}
        <div className="flex gap-2 flex-wrap">
          {availableCategories.map((cat) => (
            <button
              key={cat}
              onClick={() => setCategoryFilter(cat)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                categoryFilter === cat
                  ? "bg-primary text-white"
                  : "bg-white border border-gray-200 text-muted hover:text-foreground hover:border-gray-300"
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-3">
          {/* Sort */}
          <select
            value={sortKey}
            onChange={(e) => setSortKey(e.target.value as SortKey)}
            className="px-3 py-1.5 border border-gray-300 rounded-lg text-xs bg-white text-foreground"
          >
            <option value="date">登録日順</option>
            <option value="name">名前順</option>
            <option value="category">カテゴリ順</option>
          </select>

          {/* View mode toggle */}
          <div className="flex bg-gray-100 rounded-lg p-0.5">
            <button
              onClick={() => setViewMode("card")}
              className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                viewMode === "card"
                  ? "bg-white text-foreground shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              カード
            </button>
            <button
              onClick={() => setViewMode("list")}
              className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${
                viewMode === "list"
                  ? "bg-white text-foreground shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              リスト
            </button>
          </div>
        </div>
      </div>

      {/* Results count */}
      <div className="text-sm text-muted mb-4">
        {displayGadgets.length}件のガジェット
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : displayGadgets.length === 0 && gadgets.length === 0 ? (
        /* Empty state */
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🏸</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            ガジェットが登録されていません
          </h3>
          <p className="text-sm text-muted mb-6">
            使用している用具を登録して管理しましょう
          </p>
          <div className="flex gap-3 justify-center">
            <Link
              href="/gadgets/register"
              className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
            >
              ガジェット登録
            </Link>
            <button
              onClick={() => setShowForm(true)}
              className="inline-flex px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
            >
              クイック登録
            </button>
          </div>
        </div>
      ) : displayGadgets.length === 0 ? (
        /* Filter empty state */
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">
            該当するガジェットがありません。フィルターを変更してください。
          </p>
        </div>
      ) : viewMode === "card" ? (
        /* Card View */
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {displayGadgets.map((g) => (
            <div
              key={g.id}
              className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm hover:shadow-md transition-shadow"
            >
              {/* Image area */}
              {g.imageUrl ? (
                <div className="aspect-video bg-gray-100 overflow-hidden">
                  <img
                    src={g.imageUrl}
                    alt={g.name}
                    className="w-full h-full object-cover"
                  />
                </div>
              ) : (
                <div className="aspect-video bg-gray-50 flex items-center justify-center">
                  <svg
                    className="w-12 h-12 text-gray-200"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={1}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z"
                    />
                  </svg>
                </div>
              )}

              <div className="p-4">
                <div className="flex items-start justify-between gap-2 mb-2">
                  <h3 className="text-sm font-bold text-foreground truncate">
                    {g.name}
                  </h3>
                  <span
                    className={`text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0 ${
                      categoryColor[g.category] ?? "bg-gray-100 text-gray-600"
                    }`}
                  >
                    {g.category}
                  </span>
                </div>

                {g.memo && (
                  <p className="text-xs text-muted line-clamp-2 mb-2">
                    {g.memo}
                  </p>
                )}

                <div className="flex items-center justify-between text-xs text-muted pt-2 border-t border-gray-100">
                  <span>{formatDate(g.createdAt)}</span>
                  {g.url && (
                    <a
                      href={g.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-primary hover:text-primary-dark transition-colors"
                    >
                      詳細リンク
                    </a>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        /* List View */
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-200 bg-gray-50/50">
                <th className="text-left text-xs font-medium text-muted px-5 py-3">
                  名前
                </th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">
                  カテゴリ
                </th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">
                  説明
                </th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">
                  登録日
                </th>
              </tr>
            </thead>
            <tbody>
              {displayGadgets.map((g, idx) => (
                <tr
                  key={g.id}
                  className={`border-b border-gray-100 hover:bg-gray-50/50 transition-colors ${
                    idx === displayGadgets.length - 1 ? "border-b-0" : ""
                  }`}
                >
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-3">
                      {g.imageUrl ? (
                        <img
                          src={g.imageUrl}
                          alt={g.name}
                          className="w-8 h-8 rounded object-cover flex-shrink-0"
                        />
                      ) : (
                        <div className="w-8 h-8 rounded bg-gray-100 flex items-center justify-center flex-shrink-0">
                          <svg
                            className="w-4 h-4 text-gray-300"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            strokeWidth={1.5}
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z"
                            />
                          </svg>
                        </div>
                      )}
                      <div className="min-w-0">
                        <span className="text-sm font-medium text-foreground truncate block">
                          {g.name}
                        </span>
                        {g.url && (
                          <a
                            href={g.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-xs text-primary hover:text-primary-dark transition-colors"
                          >
                            リンク
                          </a>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-5 py-3.5">
                    <span
                      className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                        categoryColor[g.category] ??
                        "bg-gray-100 text-gray-600"
                      }`}
                    >
                      {g.category}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <span className="text-sm text-muted line-clamp-1">
                      {g.description || g.memo || "-"}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <span className="text-sm text-muted">
                      {formatDate(g.createdAt)}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
