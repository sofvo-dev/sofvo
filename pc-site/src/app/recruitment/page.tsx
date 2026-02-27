"use client";

import { useEffect, useState } from "react";
import {
  collection, query, orderBy, onSnapshot, addDoc, updateDoc, doc,
  serverTimestamp, getDocs,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Recruitment, Tournament } from "@/types/firestore";

const experienceLevels = ["初心者歓迎", "初級", "中級", "上級", "レベル問わず"];

const statusStyle: Record<string, { bg: string; text: string; dot: string }> = {
  "募集中": { bg: "bg-green-50 border-green-200", text: "text-green-700", dot: "bg-green-500" },
  "締切": { bg: "bg-orange-50 border-orange-200", text: "text-orange-700", dot: "bg-orange-500" },
  "終了": { bg: "bg-gray-50 border-gray-200", text: "text-gray-500", dot: "bg-gray-400" },
};

export default function RecruitmentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [recruitments, setRecruitments] = useState<Recruitment[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"browse" | "mine">("browse");
  const [statusFilter, setStatusFilter] = useState("すべて");
  const [showForm, setShowForm] = useState(false);

  // Tournament selection for form
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loadingTournaments, setLoadingTournaments] = useState(false);

  // Form state
  const [formTournamentId, setFormTournamentId] = useState("");
  const [formTournamentName, setFormTournamentName] = useState("");
  const [formTournamentDate, setFormTournamentDate] = useState("");
  const [formNeeded, setFormNeeded] = useState(1);
  const [formExperience, setFormExperience] = useState("レベル問わず");
  const [formComment, setFormComment] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  // Detail modal
  const [selectedRecruit, setSelectedRecruit] = useState<Recruitment | null>(null);

  useEffect(() => {
    const q = query(collection(db, "recruitments"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({ id: d.id, ...d.data() })) as Recruitment[];
      setRecruitments(list);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  // Load tournaments when form is opened
  useEffect(() => {
    if (!showForm) return;
    setLoadingTournaments(true);
    const q = query(collection(db, "tournaments"), orderBy("date", "desc"));
    getDocs(q).then((snap) => {
      setTournaments(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Tournament)));
      setLoadingTournaments(false);
    });
  }, [showForm]);

  const mine = recruitments.filter((r) => r.userId === user?.uid);
  const activeList = tab === "mine" ? mine : recruitments;
  const filtered = activeList.filter((r) => {
    if (statusFilter !== "すべて" && r.status !== statusFilter) return false;
    return true;
  });

  const selectTournament = (t: Tournament) => {
    setFormTournamentId(t.id);
    setFormTournamentName(t.title);
    setFormTournamentDate(t.date);
  };

  const resetForm = () => {
    setFormTournamentId(""); setFormTournamentName(""); setFormTournamentDate("");
    setFormNeeded(1); setFormExperience("レベル問わず"); setFormComment(""); setFormError("");
    setShowForm(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !profile) return;
    if (!formTournamentName.trim()) {
      setFormError("大会を選択してください");
      return;
    }
    setSubmitting(true);
    setFormError("");
    try {
      await addDoc(collection(db, "recruitments"), {
        userId: user.uid,
        userNickname: profile.nickname || "",
        avatarUrl: profile.avatarUrl || "",
        title: `${formTournamentName} メンバー募集`,
        tournament: formTournamentName,
        tournamentId: formTournamentId || null,
        tournamentDate: formTournamentDate || null,
        needed: formNeeded,
        experienceLevel: formExperience,
        text: formComment.trim() || null,
        status: "募集中",
        approvedCount: 0,
        pendingCount: 0,
        createdAt: serverTimestamp(),
      });
      resetForm();
    } catch {
      setFormError("募集の作成に失敗しました");
    } finally {
      setSubmitting(false);
    }
  };

  const handleCloseRecruitment = async (r: Recruitment) => {
    if (!user || r.userId !== user.uid) return;
    await updateDoc(doc(db, "recruitments", r.id), { status: "締切" });
    setSelectedRecruit(null);
  };

  if (authLoading) {
    return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  }

  return (
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">メンバー募集</h1>
          <p className="text-sm text-muted mt-1">大会のチームメンバーを募集・検索</p>
        </div>
        {user && profile && (
          <button onClick={() => setShowForm(!showForm)} className="btn-primary">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
            募集を作成
          </button>
        )}
      </div>

      {/* ===== Create Form Modal ===== */}
      {showForm && user && profile && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={resetForm}>
          <div className="bg-white rounded-2xl w-full max-w-[560px] max-h-[85vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between rounded-t-2xl z-10">
              <h2 className="text-lg font-bold text-foreground">メンバー募集を作成</h2>
              <button onClick={resetForm} className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-5">
              {formError && (
                <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">{formError}</div>
              )}

              {/* Tournament selection */}
              <div>
                <label className="block text-sm font-bold text-foreground mb-2">
                  大会を選択 <span className="text-red-500">*</span>
                </label>
                {formTournamentId ? (
                  <div className="flex items-center justify-between p-3 bg-primary/5 border border-primary/20 rounded-xl">
                    <div>
                      <p className="text-sm font-medium text-foreground">{formTournamentName}</p>
                      <p className="text-xs text-muted mt-0.5">{formTournamentDate}</p>
                    </div>
                    <button type="button" onClick={() => { setFormTournamentId(""); setFormTournamentName(""); setFormTournamentDate(""); }}
                      className="text-xs text-primary hover:underline">変更</button>
                  </div>
                ) : (
                  <div className="border border-gray-200 rounded-xl max-h-48 overflow-y-auto">
                    {loadingTournaments ? (
                      <div className="p-4 text-center text-sm text-muted">読み込み中...</div>
                    ) : tournaments.length === 0 ? (
                      <div className="p-4 text-center text-sm text-muted">登録済みの大会がありません</div>
                    ) : (
                      tournaments.filter((t) => t.status === "募集中" || t.status === "準備中").map((t) => (
                        <button key={t.id} type="button" onClick={() => selectTournament(t)}
                          className="w-full text-left px-4 py-3 hover:bg-primary/5 transition-colors border-b border-gray-50 last:border-b-0">
                          <p className="text-sm font-medium text-foreground">{t.title}</p>
                          <p className="text-xs text-muted mt-0.5">{t.date} ・ {t.location}</p>
                        </button>
                      ))
                    )}
                  </div>
                )}
                <p className="text-xs text-muted mt-1.5">大会名を直接入力することもできます</p>
                {!formTournamentId && (
                  <input type="text" value={formTournamentName} onChange={(e) => setFormTournamentName(e.target.value)}
                    className="input-field mt-2" placeholder="大会名を入力..." />
                )}
              </div>

              {/* Needed & Experience */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-bold text-foreground mb-2">募集人数</label>
                  <div className="flex items-center gap-3">
                    <button type="button" onClick={() => setFormNeeded(Math.max(1, formNeeded - 1))}
                      className="w-10 h-10 rounded-xl border border-gray-200 flex items-center justify-center text-lg hover:bg-gray-50">−</button>
                    <span className="text-xl font-bold text-foreground w-8 text-center">{formNeeded}</span>
                    <button type="button" onClick={() => setFormNeeded(Math.min(20, formNeeded + 1))}
                      className="w-10 h-10 rounded-xl border border-gray-200 flex items-center justify-center text-lg hover:bg-gray-50">+</button>
                    <span className="text-sm text-muted">人</span>
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-bold text-foreground mb-2">経験レベル</label>
                  <select value={formExperience} onChange={(e) => setFormExperience(e.target.value)}
                    className="input-field bg-white">
                    {experienceLevels.map((l) => <option key={l} value={l}>{l}</option>)}
                  </select>
                </div>
              </div>

              {/* Comment */}
              <div>
                <label className="block text-sm font-bold text-foreground mb-2">コメント</label>
                <textarea value={formComment} onChange={(e) => setFormComment(e.target.value)} rows={3}
                  className="input-field resize-none" placeholder="募集の詳細や条件など..." />
              </div>

              {/* Submit */}
              <div className="flex gap-3 pt-2">
                <button type="submit" disabled={submitting} className="btn-primary flex-1 py-3 justify-center">
                  {submitting ? "作成中..." : "募集を作成"}
                </button>
                <button type="button" onClick={resetForm}
                  className="px-6 py-3 border border-gray-200 rounded-xl text-sm font-medium text-muted hover:text-foreground transition-colors">
                  キャンセル
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ===== Detail Modal ===== */}
      {selectedRecruit && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setSelectedRecruit(null)}>
          <div className="bg-white rounded-2xl w-full max-w-[480px] max-h-[85vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between rounded-t-2xl">
              <h2 className="text-lg font-bold text-foreground">募集詳細</h2>
              <button onClick={() => setSelectedRecruit(null)} className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            <div className="p-6 space-y-5">
              {/* Status */}
              {(() => {
                const s = statusStyle[selectedRecruit.status] ?? statusStyle["終了"];
                return (
                  <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium border ${s.bg} ${s.text}`}>
                    <span className={`w-2 h-2 rounded-full ${s.dot}`} />
                    {selectedRecruit.status}
                  </div>
                );
              })()}

              {/* Tournament info */}
              {selectedRecruit.tournament && (
                <div className="p-4 bg-gray-50 rounded-xl">
                  <p className="text-xs text-muted mb-1">大会</p>
                  <p className="text-sm font-bold text-foreground">{selectedRecruit.tournament}</p>
                  {selectedRecruit.tournamentId && (
                    <a href={`/tournament/${selectedRecruit.tournamentId}`} className="text-xs text-primary hover:underline mt-1 inline-block">大会ページへ →</a>
                  )}
                </div>
              )}

              {/* Details */}
              <div className="grid grid-cols-2 gap-4">
                <InfoBox label="募集人数" value={`${selectedRecruit.needed ?? "?"}人`} />
                <InfoBox label="経験レベル" value={selectedRecruit.experienceLevel || "指定なし"} />
                <InfoBox label="承認済み" value={`${selectedRecruit.approvedCount ?? 0}人`} color="text-green-600" />
                <InfoBox label="申請中" value={`${selectedRecruit.pendingCount ?? 0}人`} color="text-orange-500" />
              </div>

              {selectedRecruit.text && (
                <div>
                  <p className="text-xs text-muted mb-1">コメント</p>
                  <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed bg-gray-50 p-3 rounded-xl">{selectedRecruit.text}</p>
                </div>
              )}

              <div className="text-xs text-muted">投稿者: {selectedRecruit.userNickname || "不明"}</div>

              {/* Action buttons */}
              <div className="pt-2 space-y-2">
                {selectedRecruit.status === "募集中" && user && selectedRecruit.userId === user.uid && (
                  <button onClick={() => handleCloseRecruitment(selectedRecruit)}
                    className="w-full py-3 border-2 border-orange-300 text-orange-600 rounded-xl text-sm font-bold hover:bg-orange-50 transition-colors">
                    募集を締め切る
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ===== Tabs & Filters ===== */}
      {user && (
        <div className="flex items-center gap-1 bg-gray-100 rounded-xl p-1 mb-4 w-fit">
          <button onClick={() => setTab("browse")}
            className={`px-5 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === "browse" ? "bg-white text-foreground shadow-sm" : "text-muted hover:text-foreground"
            }`}>
            すべての募集
          </button>
          <button onClick={() => setTab("mine")}
            className={`px-5 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === "mine" ? "bg-white text-foreground shadow-sm" : "text-muted hover:text-foreground"
            }`}>
            自分の募集 {mine.length > 0 && <span className="ml-1 text-xs bg-primary/10 text-primary px-1.5 py-0.5 rounded-full">{mine.length}</span>}
          </button>
        </div>
      )}

      <div className="flex gap-2 mb-4 flex-wrap">
        {(["すべて", "募集中", "締切", "終了"] as const).map((s) => (
          <button key={s} onClick={() => setStatusFilter(s)}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${
              statusFilter === s
                ? "bg-primary text-white shadow-sm"
                : "bg-gray-100 text-muted hover:bg-gray-200"
            }`}>
            {s}
          </button>
        ))}
      </div>

      <p className="text-sm text-muted mb-4">{filtered.length}件の募集</p>

      {/* ===== Card List ===== */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" /></svg>
          <h3 className="text-lg font-bold text-foreground mb-2">募集がありません</h3>
          <p className="text-sm text-muted mb-4">
            {tab === "mine" ? "まだ募集を作成していません" : "新しい募集を作成してみましょう"}
          </p>
          {user && profile && (
            <button onClick={() => setShowForm(true)} className="btn-primary">募集を作成</button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((r) => {
            const st = statusStyle[r.status] ?? statusStyle["終了"];
            const progress = (r.needed ?? 1) > 0 ? Math.min(100, ((r.approvedCount ?? 0) / (r.needed ?? 1)) * 100) : 0;
            return (
              <div key={r.id}
                className="bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-lg hover:border-primary/20 transition-all cursor-pointer group"
                onClick={() => setSelectedRecruit(r)}>
                <div className="p-5">
                  {/* Status & Experience */}
                  <div className="flex items-center justify-between mb-3">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold border ${st.bg} ${st.text}`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${st.dot}`} />
                      {r.status}
                    </span>
                    {r.experienceLevel && (
                      <span className="text-xs bg-primary/8 text-primary px-2.5 py-1 rounded-lg font-medium">{r.experienceLevel}</span>
                    )}
                  </div>

                  {/* Tournament name */}
                  {r.tournament && (
                    <p className="text-base font-bold text-foreground group-hover:text-primary transition-colors line-clamp-2 leading-snug mb-2">
                      {r.tournament}
                    </p>
                  )}
                  {!r.tournament && r.title && (
                    <p className="text-base font-bold text-foreground group-hover:text-primary transition-colors line-clamp-2 leading-snug mb-2">
                      {r.title}
                    </p>
                  )}

                  {/* Comment preview */}
                  {r.text && (
                    <p className="text-sm text-muted line-clamp-2 mb-3">{r.text}</p>
                  )}

                  {/* Recruiter */}
                  <div className="flex items-center gap-2 text-xs text-muted">
                    <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0" /></svg>
                    <span>{r.userNickname || "不明"}</span>
                  </div>
                </div>

                {/* Footer: progress */}
                <div className="px-5 py-3 border-t border-gray-100 bg-gray-50/50">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-xs text-muted">募集状況</span>
                    <span className="text-xs font-bold text-foreground">{r.approvedCount ?? 0} / {r.needed ?? "?"} 人</span>
                  </div>
                  <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${progress}%` }} />
                  </div>
                  {(r.pendingCount ?? 0) > 0 && (
                    <p className="text-xs text-orange-500 mt-1.5 font-medium">{r.pendingCount}件の申請あり</p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function InfoBox({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <div className="p-3 bg-gray-50 rounded-xl">
      <p className="text-xs text-muted mb-0.5">{label}</p>
      <p className={`text-sm font-bold ${color || "text-foreground"}`}>{value}</p>
    </div>
  );
}
