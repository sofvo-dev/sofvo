"use client";

import { useEffect, useState, useMemo } from "react";
import {
  collection,
  query,
  orderBy,
  getDocs,
  doc,
  updateDoc,
  limit as fbLimit,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface UserRow {
  uid: string;
  nickname: string;
  email?: string;
  avatarUrl?: string;
  isOfficial?: boolean;
  certifiedAt?: unknown;
}

export default function AdminCertificationPage() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [showAll, setShowAll] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const snap = await getDocs(
          query(collection(db, "users"), orderBy("createdAt", "desc"), fbLimit(500))
        );
        setUsers(snap.docs.map((d) => ({ uid: d.id, ...(d.data() as Omit<UserRow, "uid">) })));
      } catch {
        // ignore
      }
      setLoading(false);
    }
    load();
  }, []);

  const filtered = useMemo(() => {
    let list = users;
    if (!showAll) list = list.filter((u) => u.isOfficial);
    const kw = search.trim().toLowerCase();
    if (kw) {
      list = list.filter((u) => {
        const hay = `${u.nickname ?? ""} ${u.email ?? ""} ${u.uid}`.toLowerCase();
        return hay.includes(kw);
      });
    }
    return list;
  }, [users, showAll, search]);

  const toggleOfficial = async (u: UserRow) => {
    if (!confirm(u.isOfficial ? `${u.nickname} の公式認証を解除しますか？` : `${u.nickname} に公式認証を付与しますか？`)) return;
    await updateDoc(doc(db, "users", u.uid), {
      isOfficial: !u.isOfficial,
      certifiedAt: !u.isOfficial ? new Date() : null,
    });
    setUsers((prev) => prev.map((p) => (p.uid === u.uid ? { ...p, isOfficial: !u.isOfficial } : p)));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">公式認証管理</h1>
      <p className="text-sm text-muted mb-6">信頼できるユーザーに公式バッジを付与します</p>

      <div className="flex gap-3 mb-4">
        <div className="relative flex-1">
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
          </svg>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="ニックネーム・メール・UIDで検索"
            className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:border-primary"
          />
        </div>
        <label className="flex items-center gap-2 text-xs text-muted">
          <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} />
          全ユーザーを表示
        </label>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">
            {showAll ? "該当するユーザーがいません" : "認証済ユーザーがいません"}
          </p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden divide-y divide-gray-100">
          {filtered.map((u) => (
            <div key={u.uid} className="flex items-center gap-3 px-5 py-3">
              <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
                {u.avatarUrl ? (
                  <img src={u.avatarUrl} alt="" className="w-10 h-10 object-cover" />
                ) : (
                  u.nickname?.charAt(0) || "?"
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-foreground truncate flex items-center gap-2">
                  {u.nickname}
                  {u.isOfficial && (
                    <svg className="w-4 h-4 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  )}
                </div>
                {u.email && <div className="text-xs text-muted truncate">{u.email}</div>}
              </div>
              <button
                onClick={() => toggleOfficial(u)}
                className={`px-4 py-1.5 text-xs font-semibold rounded-lg transition-colors flex-shrink-0 ${
                  u.isOfficial
                    ? "bg-gray-100 text-muted hover:bg-gray-200"
                    : "bg-primary text-white hover:bg-primary-dark"
                }`}
              >
                {u.isOfficial ? "認証解除" : "認証付与"}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
