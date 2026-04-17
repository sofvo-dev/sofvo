"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  onSnapshot,
  addDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Team } from "@/types/firestore";
import Link from "next/link";

export default function TeamsPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [teams, setTeams] = useState<Team[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);

  // Form state
  const [formName, setFormName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState("");

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, "teams"),
      where("memberIds", "array-contains", user.uid)
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      })) as Team[];
      setTeams(list);
      setLoading(false);
    });
    return () => unsub();
  }, [user]);

  const mainTeams = teams.filter((t) => t.isMain === true);
  const tempTeams = teams.filter((t) => !t.isMain);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !profile) return;
    if (!formName.trim()) {
      setFormError("チーム名を入力してください");
      return;
    }

    setSubmitting(true);
    setFormError("");

    try {
      await addDoc(collection(db, "teams"), {
        name: formName.trim(),
        ownerId: user.uid,
        memberIds: [user.uid],
        memberNames: { [user.uid]: profile.nickname },
        memberAvatars: profile.avatarUrl
          ? { [user.uid]: profile.avatarUrl }
          : {},
        isMain: false,
        createdAt: serverTimestamp(),
      });

      setFormName("");
      setShowForm(false);
    } catch {
      setFormError("チームの作成に失敗しました");
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
            チーム管理機能を利用するにはログインしてください
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

  const renderMemberList = (team: Team) => {
    const memberEntries = Object.entries(team.memberNames || {});
    return (
      <div className="flex items-center gap-2 mt-3">
        <div className="flex -space-x-2">
          {memberEntries.slice(0, 5).map(([uid, name]) => {
            const avatarUrl = team.memberAvatars?.[uid];
            return (
              <div
                key={uid}
                className="w-8 h-8 rounded-full border-2 border-white bg-primary/10 flex items-center justify-center text-primary font-bold text-xs flex-shrink-0 overflow-hidden"
                title={name}
              >
                {avatarUrl ? (
                  <img
                    src={avatarUrl}
                    alt={name}
                    className="w-8 h-8 object-cover"
                  />
                ) : (
                  name.charAt(0)
                )}
              </div>
            );
          })}
          {memberEntries.length > 5 && (
            <div className="w-8 h-8 rounded-full border-2 border-white bg-gray-100 flex items-center justify-center text-xs text-muted font-medium flex-shrink-0">
              +{memberEntries.length - 5}
            </div>
          )}
        </div>
        <span className="text-xs text-muted ml-1">
          {memberEntries.length}人
        </span>
      </div>
    );
  };

  const renderTeamCard = (team: Team) => {
    const isOwner = team.ownerId === user.uid;
    const memberEntries = Object.entries(team.memberNames || {});

    return (
      <Link
        key={team.id}
        href={`/teams/${team.id}`}
        className="block bg-white rounded-xl border border-gray-200 p-5 shadow-sm hover:shadow-md hover:border-primary/20 transition-all"
      >
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2 min-w-0">
            <h3 className="text-base font-bold text-foreground truncate">
              {team.name}
            </h3>
            {isOwner && (
              <span className="text-xs bg-accent/10 text-accent px-2 py-0.5 rounded-full font-medium flex-shrink-0">
                オーナー
              </span>
            )}
          </div>
          <span className="text-xs text-muted flex-shrink-0">
            {isOwner ? "管理者" : "メンバー"}
          </span>
        </div>

        {/* Member names */}
        <div className="text-sm text-muted mb-1">
          {memberEntries.map(([, name]) => name).join("、")}
        </div>

        {/* Avatars row */}
        {renderMemberList(team)}
      </Link>
    );
  };

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">チーム管理</h1>
          <p className="text-sm text-muted mt-1">
            所属チームの管理・新規作成
          </p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "チーム作成"}
        </button>
      </div>

      {/* Create Form */}
      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            新規チームを作成
          </h2>

          {formError && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
              {formError}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                チーム名 <span className="text-error">*</span>
              </label>
              <input
                type="text"
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder="例: ソフバレチームA"
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>

            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {submitting ? "作成中..." : "チームを作成"}
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

      {/* Loading */}
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : teams.length === 0 ? (
        /* Empty state */
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">👥</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            チームがありません
          </h3>
          <p className="text-sm text-muted mb-6">
            最初のチームを作成して、メンバーを招待しましょう
          </p>
          <button
            onClick={() => setShowForm(true)}
            className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            チーム作成
          </button>
        </div>
      ) : (
        <div className="space-y-8">
          {/* Main Teams */}
          {mainTeams.length > 0 && (
            <section>
              <div className="flex items-center gap-2 mb-4">
                <h2 className="text-lg font-bold text-foreground">
                  メインチーム
                </h2>
                <span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                  {mainTeams.length}
                </span>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {mainTeams.map((team) => renderTeamCard(team))}
              </div>
            </section>
          )}

          {/* Temporary Teams */}
          <section>
            <div className="flex items-center gap-2 mb-4">
              <h2 className="text-lg font-bold text-foreground">
                一時チーム
              </h2>
              <span className="text-xs bg-gray-100 text-muted px-2 py-0.5 rounded-full font-medium">
                {tempTeams.length}
              </span>
            </div>
            {tempTeams.length === 0 ? (
              <div className="text-center py-12 bg-white rounded-xl border border-gray-200">
                <p className="text-sm text-muted">
                  一時チームはありません
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {tempTeams.map((team) => renderTeamCard(team))}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
