"use client";

import { useEffect, useState, useMemo } from "react";
import {
  collection,
  getDocs,
  doc,
  setDoc,
  deleteDoc,
  serverTimestamp,
  query,
  limit as fbLimit,
  orderBy,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

interface SearchableUser {
  uid: string;
  nickname: string;
  searchId?: string;
  avatarUrl?: string;
  area?: string;
  bio?: string;
  experience?: string;
  isOfficial?: boolean;
}

export default function FollowSearchPage() {
  const { user, profile } = useAuth();
  const [keyword, setKeyword] = useState("");
  const [users, setUsers] = useState<SearchableUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [followingIds, setFollowingIds] = useState<Set<string>>(new Set());
  const [areaFilter, setAreaFilter] = useState("");
  const [experienceFilter, setExperienceFilter] = useState("");

  useEffect(() => {
    async function loadUsers() {
      setLoading(true);
      try {
        const snap = await getDocs(
          query(collection(db, "users"), orderBy("createdAt", "desc"), fbLimit(200))
        );
        const list: SearchableUser[] = snap.docs
          .filter((d) => d.id !== user?.uid)
          .map((d) => ({ uid: d.id, ...(d.data() as Omit<SearchableUser, "uid">) }));
        setUsers(list);
      } catch {
        // ignore
      }
      setLoading(false);
    }
    loadUsers();
  }, [user?.uid]);

  useEffect(() => {
    if (!user) return;
    async function loadFollowing() {
      if (!user) return;
      try {
        const snap = await getDocs(collection(db, "users", user.uid, "following"));
        setFollowingIds(new Set(snap.docs.map((d) => d.id)));
      } catch {
        // ignore
      }
    }
    loadFollowing();
  }, [user]);

  const filtered = useMemo(() => {
    const kw = keyword.trim().toLowerCase();
    return users.filter((u) => {
      if (kw) {
        const hay = `${u.nickname} ${u.searchId ?? ""} ${u.bio ?? ""}`.toLowerCase();
        if (!hay.includes(kw)) return false;
      }
      if (areaFilter && u.area !== areaFilter) return false;
      if (experienceFilter && u.experience !== experienceFilter) return false;
      return true;
    });
  }, [users, keyword, areaFilter, experienceFilter]);

  const toggleFollow = async (target: SearchableUser) => {
    if (!user || !profile) return;
    const isFollowing = followingIds.has(target.uid);
    const myRef = doc(db, "users", user.uid, "following", target.uid);
    const theirRef = doc(db, "users", target.uid, "followers", user.uid);

    if (isFollowing) {
      await deleteDoc(myRef);
      await deleteDoc(theirRef);
      setFollowingIds((prev) => {
        const next = new Set(prev);
        next.delete(target.uid);
        return next;
      });
    } else {
      await setDoc(myRef, {
        nickname: target.nickname,
        avatarUrl: target.avatarUrl ?? null,
        createdAt: serverTimestamp(),
      });
      await setDoc(theirRef, {
        nickname: profile.nickname,
        avatarUrl: profile.avatarUrl ?? null,
        createdAt: serverTimestamp(),
      });
      setFollowingIds((prev) => new Set(prev).add(target.uid));
    }
  };

  const areas = useMemo(() => {
    const s = new Set<string>();
    users.forEach((u) => u.area && s.add(u.area));
    return Array.from(s).sort();
  }, [users]);

  const experiences = ["1年未満", "1〜3年", "3〜5年", "5〜10年", "10年以上"];

  if (!user) {
    return (
      <div className="p-8 max-w-[900px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <Link href="/login" className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto animate-fade-in">
      <div className="flex items-center gap-3 mb-5">
        <Link href="/follows" className="text-muted hover:text-primary transition-colors">
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </Link>
        <h1 className="text-lg font-bold text-foreground">ユーザーを探す</h1>
      </div>

      <div className="relative mb-4">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          placeholder="ニックネーム・ID・自己紹介で検索"
          className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
        />
      </div>

      <div className="flex gap-2 mb-6 flex-wrap">
        <select
          value={areaFilter}
          onChange={(e) => setAreaFilter(e.target.value)}
          className="px-3 py-1.5 text-xs bg-white border border-gray-200 rounded-lg focus:outline-none focus:border-primary"
        >
          <option value="">エリア：すべて</option>
          {areas.map((a) => (
            <option key={a} value={a}>{a}</option>
          ))}
        </select>
        <select
          value={experienceFilter}
          onChange={(e) => setExperienceFilter(e.target.value)}
          className="px-3 py-1.5 text-xs bg-white border border-gray-200 rounded-lg focus:outline-none focus:border-primary"
        >
          <option value="">経験：すべて</option>
          {experiences.map((x) => (
            <option key={x} value={x}>{x}</option>
          ))}
        </select>
        {(areaFilter || experienceFilter) && (
          <button
            onClick={() => { setAreaFilter(""); setExperienceFilter(""); }}
            className="px-3 py-1.5 text-xs text-muted hover:text-primary"
          >
            条件をクリア
          </button>
        )}
      </div>

      <div className="text-xs text-muted mb-3">{filtered.length}人</div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">該当するユーザーが見つかりません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map((u) => {
            const isFollowing = followingIds.has(u.uid);
            return (
              <div
                key={u.uid}
                className="flex items-center gap-3 p-3 bg-white rounded-xl border border-gray-200 hover:shadow-md hover:border-primary/20 transition-all"
              >
                <Link href={`/profile/${u.uid}`} className="flex items-center gap-3 flex-1 min-w-0">
                  <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-base flex-shrink-0 overflow-hidden">
                    {u.avatarUrl ? (
                      <img src={u.avatarUrl} alt="" className="w-11 h-11 object-cover" />
                    ) : (
                      u.nickname.charAt(0) || "?"
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-bold text-foreground truncate">
                      {u.nickname}
                    </div>
                    {u.searchId && (
                      <div className="text-xs text-muted truncate">@{u.searchId}</div>
                    )}
                    <div className="flex items-center gap-2 mt-0.5 text-xs text-muted">
                      {u.area && <span>{u.area}</span>}
                      {u.experience && <span>• {u.experience}</span>}
                    </div>
                  </div>
                </Link>
                <button
                  onClick={() => toggleFollow(u)}
                  className={`px-4 py-1.5 text-xs font-semibold rounded-lg transition-colors flex-shrink-0 ${
                    isFollowing
                      ? "bg-gray-100 text-muted hover:bg-gray-200"
                      : "bg-primary text-white hover:bg-primary-dark"
                  }`}
                >
                  {isFollowing ? "フォロー中" : "フォロー"}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
