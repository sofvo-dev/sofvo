"use client";

import { useEffect, useState } from "react";
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
import type { Recruitment } from "@/types/firestore";

const statusFilters = ["すべて", "募集中", "締切", "終了"] as const;

const statusColor: Record<string, string> = {
  募集中: "bg-green-500",
  締切: "bg-orange-500",
  終了: "bg-gray-400",
};

const statusBorderColor: Record<string, string> = {
  募集中: "border-green-200 bg-green-50",
  締切: "border-orange-200 bg-orange-50",
  終了: "border-gray-200 bg-gray-50",
};

const experienceLevels = ["初心者歓迎", "初級", "中級", "上級", "レベル問わず"];

export default function RecruitmentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [recruitments, setRecruitments] = useState<Recruitment[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>("すべて");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);

  // Form state
  const [formTitle, setFormTitle] = useState("");
  const [formTournament, setFormTournament] = useState("");
  const [formNeeded, setFormNeeded] = useState(1);
  const [formExperience, setFormExperience] = useState("");
  const [formText, setFormText] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => {
    const q = query(
      collection(db, "recruitments"),
      orderBy("createdAt", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      })) as Recruitment[];
      setRecruitments(list);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const filtered = recruitments.filter((r) => {
    if (statusFilter !== "すべて" && r.status !== statusFilter) return false;
    return true;
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !profile) return;
    if (!formTitle.trim()) {
      setFormError("タイトルを入力してください");
      return;
    }

    setSubmitting(true);
    setFormError("");

    try {
      await addDoc(collection(db, "recruitments"), {
        userId: user.uid,
        userNickname: profile.nickname,
        title: formTitle.trim(),
        tournament: formTournament.trim() || null,
        needed: formNeeded,
        experienceLevel: formExperience || null,
        text: formText.trim() || null,
        status: "募集中",
        approvedCount: 0,
        pendingCount: 0,
        createdAt: serverTimestamp(),
      });

      // Reset form
      setFormTitle("");
      setFormTournament("");
      setFormNeeded(1);
      setFormExperience("");
      setFormText("");
      setShowForm(false);
    } catch {
      setFormError("募集の作成に失敗しました");
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

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">メンバー募集</h1>
          <p className="text-sm text-muted mt-1">
            チームメンバーを募集・応募
          </p>
        </div>
        {user && profile && (
          <button
            onClick={() => setShowForm(!showForm)}
            className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            {showForm ? "閉じる" : "募集を作成"}
          </button>
        )}
      </div>

      {/* Create Form */}
      {showForm && user && profile && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            新規募集を作成
          </h2>

          {formError && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
              {formError}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                タイトル <span className="text-error">*</span>
              </label>
              <input
                type="text"
                value={formTitle}
                onChange={(e) => setFormTitle(e.target.value)}
                placeholder="例: 日曜の大会メンバー募集"
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  大会名
                </label>
                <input
                  type="text"
                  value={formTournament}
                  onChange={(e) => setFormTournament(e.target.value)}
                  placeholder="大会名（任意）"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  募集人数
                </label>
                <input
                  type="number"
                  value={formNeeded}
                  onChange={(e) => setFormNeeded(Number(e.target.value))}
                  min={1}
                  max={20}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  経験レベル
                </label>
                <select
                  value={formExperience}
                  onChange={(e) => setFormExperience(e.target.value)}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
                >
                  <option value="">指定なし</option>
                  {experienceLevels.map((l) => (
                    <option key={l} value={l}>
                      {l}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                詳細テキスト
              </label>
              <textarea
                value={formText}
                onChange={(e) => setFormText(e.target.value)}
                rows={3}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
                placeholder="募集の詳細や条件など..."
              />
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {submitting ? "作成中..." : "募集を作成"}
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

      {/* Status Filter */}
      <div className="flex gap-2 mb-6">
        {statusFilters.map((s) => (
          <button
            key={s}
            onClick={() => setStatusFilter(s)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              statusFilter === s
                ? "bg-primary text-white"
                : "bg-white border border-gray-200 text-muted hover:text-foreground hover:border-gray-300"
            }`}
          >
            {s}
          </button>
        ))}
      </div>

      {/* Results count */}
      <div className="text-sm text-muted mb-4">{filtered.length}件の募集</div>

      {/* Recruitment List */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">📢</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            募集がありません
          </h3>
          <p className="text-sm text-muted mb-6">
            {statusFilter !== "すべて"
              ? "フィルター条件を変更するか、新しく募集を作成してください"
              : "最初の募集を作成してみましょう"}
          </p>
          {user && profile && (
            <button
              onClick={() => setShowForm(true)}
              className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
            >
              募集を作成
            </button>
          )}
        </div>
      ) : (
        <div className="space-y-3">
          {filtered.map((r) => (
            <div
              key={r.id}
              className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm"
            >
              {/* Card header */}
              <button
                onClick={() =>
                  setExpandedId(expandedId === r.id ? null : r.id)
                }
                className="w-full flex items-center gap-5 p-5 text-left hover:bg-gray-50/50 transition-colors"
              >
                {/* Status badge */}
                <span
                  className={`text-xs text-white px-2.5 py-1 rounded-full flex-shrink-0 font-medium ${
                    statusColor[r.status] ?? "bg-gray-400"
                  }`}
                >
                  {r.status}
                </span>

                {/* Main info */}
                <div className="flex-1 min-w-0">
                  <h3 className="text-base font-bold text-foreground truncate">
                    {r.title}
                  </h3>
                  <div className="flex flex-wrap gap-4 mt-1 text-sm text-muted">
                    {r.tournament && <span>{r.tournament}</span>}
                    {r.userNickname && <span>by {r.userNickname}</span>}
                  </div>
                </div>

                {/* Counts */}
                <div className="flex items-center gap-4 flex-shrink-0">
                  {r.experienceLevel && (
                    <span className="text-xs bg-primary/10 text-primary px-2.5 py-1 rounded-full font-medium">
                      {r.experienceLevel}
                    </span>
                  )}
                  <div className="text-right">
                    <div className="text-sm font-bold text-foreground">
                      募集{r.needed ?? "?"}人
                    </div>
                    <div className="flex gap-2 text-xs text-muted mt-0.5">
                      <span className="text-success">
                        承認 {r.approvedCount ?? 0}
                      </span>
                      <span className="text-warning">
                        申請 {r.pendingCount ?? 0}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Expand icon */}
                <svg
                  className={`w-5 h-5 text-muted flex-shrink-0 transition-transform ${
                    expandedId === r.id ? "rotate-180" : ""
                  }`}
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                  />
                </svg>
              </button>

              {/* Expanded detail */}
              {expandedId === r.id && (
                <div className="px-5 pb-5 border-t border-gray-100">
                  <div className="pt-4 space-y-3">
                    {/* Status highlight bar */}
                    <div
                      className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium border ${
                        statusBorderColor[r.status] ?? "border-gray-200 bg-gray-50"
                      }`}
                    >
                      <span
                        className={`w-2 h-2 rounded-full ${
                          statusColor[r.status] ?? "bg-gray-400"
                        }`}
                      />
                      ステータス: {r.status}
                    </div>

                    {r.text && (
                      <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed">
                        {r.text}
                      </p>
                    )}

                    <div className="flex flex-wrap gap-6 text-sm text-muted">
                      {r.tournament && (
                        <div>
                          <span className="font-medium text-foreground">
                            大会:
                          </span>{" "}
                          {r.tournament}
                        </div>
                      )}
                      <div>
                        <span className="font-medium text-foreground">
                          募集人数:
                        </span>{" "}
                        {r.needed ?? "-"}人
                      </div>
                      <div>
                        <span className="font-medium text-foreground">
                          承認済み:
                        </span>{" "}
                        <span className="text-success">
                          {r.approvedCount ?? 0}人
                        </span>
                      </div>
                      <div>
                        <span className="font-medium text-foreground">
                          申請中:
                        </span>{" "}
                        <span className="text-warning">
                          {r.pendingCount ?? 0}人
                        </span>
                      </div>
                      {r.experienceLevel && (
                        <div>
                          <span className="font-medium text-foreground">
                            レベル:
                          </span>{" "}
                          {r.experienceLevel}
                        </div>
                      )}
                    </div>

                    <div className="text-xs text-muted pt-1">
                      投稿者: {r.userNickname ?? "不明"}
                    </div>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
