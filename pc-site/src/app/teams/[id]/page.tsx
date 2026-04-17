"use client";

import { use, useEffect, useState } from "react";
import {
  doc,
  onSnapshot,
  updateDoc,
  deleteDoc,
  arrayRemove,
  arrayUnion,
  deleteField,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Team } from "@/types/firestore";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function TeamDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { user } = useAuth();
  const [team, setTeam] = useState<Team | null>(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, "teams", id),
      (snap) => {
        if (!snap.exists()) {
          setNotFound(true);
          setLoading(false);
          return;
        }
        const t = { id: snap.id, ...snap.data() } as Team;
        setTeam(t);
        setName(t.name);
        setLoading(false);
      },
      () => {
        setNotFound(true);
        setLoading(false);
      }
    );
    return () => unsub();
  }, [id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (notFound || !team) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">チームが見つかりません</p>
        <Link href="/teams" className="inline-block mt-4 text-primary text-sm hover:underline">
          チーム一覧に戻る
        </Link>
      </div>
    );
  }

  const isOwner = team.ownerId === user?.uid;
  const members = Object.entries(team.memberNames || {});

  const saveName = async () => {
    if (!name.trim()) return;
    setSaving(true);
    setError("");
    try {
      await updateDoc(doc(db, "teams", id), { name: name.trim() });
      setEditing(false);
    } catch {
      setError("チーム名の変更に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const toggleMain = async () => {
    if (!isOwner) return;
    await updateDoc(doc(db, "teams", id), { isMain: !team.isMain });
  };

  const removeMember = async (uid: string) => {
    if (!isOwner || uid === team.ownerId) return;
    if (!confirm("このメンバーをチームから外しますか？")) return;
    await updateDoc(doc(db, "teams", id), {
      memberIds: arrayRemove(uid),
      [`memberNames.${uid}`]: deleteField(),
      [`memberAvatars.${uid}`]: deleteField(),
    });
  };

  const leaveTeam = async () => {
    if (!user || isOwner) return;
    if (!confirm("このチームから脱退しますか？")) return;
    await updateDoc(doc(db, "teams", id), {
      memberIds: arrayRemove(user.uid),
      [`memberNames.${user.uid}`]: deleteField(),
      [`memberAvatars.${user.uid}`]: deleteField(),
    });
    router.push("/teams");
  };

  const deleteTeam = async () => {
    if (!isOwner) return;
    if (!confirm("このチームを削除しますか？この操作は取り消せません。")) return;
    await deleteDoc(doc(db, "teams", id));
    router.push("/teams");
  };

  const joinTeam = async () => {
    if (!user) return;
    await updateDoc(doc(db, "teams", id), {
      memberIds: arrayUnion(user.uid),
    });
  };

  const isMember = user && team.memberIds?.includes(user.uid);

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto animate-fade-in">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/teams" className="hover:text-primary transition-colors">
          チーム
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium truncate">{team.name}</span>
      </nav>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
          {error}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <div className="flex items-start justify-between gap-4 mb-4">
          <div className="flex-1 min-w-0">
            {editing ? (
              <div className="flex gap-2">
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm"
                  autoFocus
                />
                <button
                  onClick={saveName}
                  disabled={saving}
                  className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
                >
                  保存
                </button>
                <button
                  onClick={() => { setEditing(false); setName(team.name); }}
                  className="px-4 py-2 border border-gray-300 rounded-lg text-sm text-muted hover:text-foreground"
                >
                  キャンセル
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-2xl font-bold text-foreground">{team.name}</h1>
                {team.isMain && (
                  <span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                    メインチーム
                  </span>
                )}
                {isOwner && (
                  <span className="text-xs bg-accent/10 text-accent px-2 py-0.5 rounded-full font-medium">
                    オーナー
                  </span>
                )}
              </div>
            )}
            <p className="text-sm text-muted mt-2">メンバー {members.length}人</p>
          </div>

          {isOwner && !editing && (
            <div className="flex gap-2 flex-shrink-0">
              <button
                onClick={() => setEditing(true)}
                className="px-3 py-1.5 border border-gray-300 rounded-lg text-xs font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
              >
                名前編集
              </button>
              <button
                onClick={toggleMain}
                className="px-3 py-1.5 border border-gray-300 rounded-lg text-xs font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
              >
                {team.isMain ? "メイン解除" : "メインに設定"}
              </button>
            </div>
          )}
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-gray-100">
          <h2 className="text-sm font-bold text-foreground">メンバー</h2>
        </div>
        <ul className="divide-y divide-gray-50">
          {members.map(([uid, nickname]) => {
            const avatarUrl = team.memberAvatars?.[uid];
            const isThisOwner = uid === team.ownerId;
            return (
              <li key={uid} className="px-5 py-3 flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
                  {avatarUrl ? (
                    <img src={avatarUrl} alt={nickname} className="w-10 h-10 object-cover" />
                  ) : (
                    nickname.charAt(0)
                  )}
                </div>
                <Link href={`/profile/${uid}`} className="flex-1 min-w-0 hover:text-primary">
                  <div className="text-sm font-medium text-foreground truncate">
                    {nickname}
                    {isThisOwner && (
                      <span className="ml-2 text-xs text-accent">オーナー</span>
                    )}
                  </div>
                </Link>
                {isOwner && !isThisOwner && (
                  <button
                    onClick={() => removeMember(uid)}
                    className="text-xs text-error hover:underline flex-shrink-0"
                  >
                    外す
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="text-sm font-bold text-foreground mb-3">アクション</h2>
        <div className="flex flex-wrap gap-2">
          {!isMember && user && (
            <button
              onClick={joinTeam}
              className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
            >
              参加する
            </button>
          )}
          {isMember && !isOwner && (
            <button
              onClick={leaveTeam}
              className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
            >
              脱退する
            </button>
          )}
          {isOwner && (
            <button
              onClick={deleteTeam}
              className="px-4 py-2 bg-red-50 text-error rounded-lg text-sm font-medium hover:bg-red-100 transition-colors"
            >
              チームを削除
            </button>
          )}
          <Link
            href="/teams"
            className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
          >
            チーム一覧へ
          </Link>
        </div>
      </div>
    </div>
  );
}
