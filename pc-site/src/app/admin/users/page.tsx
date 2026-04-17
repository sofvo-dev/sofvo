"use client";

import { useEffect, useState, useMemo } from "react";
import {
  collection,
  query,
  orderBy,
  getDocs,
  limit as fbLimit,
  Timestamp,
  doc,
  updateDoc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface UserRow {
  uid: string;
  nickname: string;
  email?: string;
  area?: string;
  experience?: string;
  gender?: string;
  totalPoints?: number;
  isAdmin?: boolean;
  lastActiveAt?: unknown;
  createdAt?: unknown;
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

export default function AdminUsersPage() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

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
    const kw = search.trim().toLowerCase();
    if (!kw) return users;
    return users.filter((u) => {
      const hay = `${u.nickname ?? ""} ${u.email ?? ""} ${u.area ?? ""} ${u.uid}`.toLowerCase();
      return hay.includes(kw);
    });
  }, [users, search]);

  const toggleAdmin = async (u: UserRow) => {
    if (!confirm(u.isAdmin ? `${u.nickname} の管理者権限を解除しますか？` : `${u.nickname} を管理者にしますか？`)) return;
    await updateDoc(doc(db, "users", u.uid), { isAdmin: !u.isAdmin });
    setUsers((prev) => prev.map((p) => (p.uid === u.uid ? { ...p, isAdmin: !u.isAdmin } : p)));
  };

  return (
    <div className="p-8 max-w-[1100px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">ユーザー管理</h1>
      <p className="text-sm text-muted mb-6">全ユーザーの検索・管理者権限の付与</p>

      <div className="relative mb-4">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="ニックネーム・メール・UIDで検索"
          className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
        />
      </div>

      <div className="text-xs text-muted mb-3">{filtered.length}人</div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50/50 border-b border-gray-200">
              <tr>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">ユーザー</th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">エリア</th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">経験</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">Pt</th>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">登録日</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">操作</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u) => (
                <tr key={u.uid} className="border-b border-gray-100 hover:bg-gray-50/50">
                  <td className="px-5 py-3">
                    <Link href={`/profile/${u.uid}`} className="hover:text-primary">
                      <div className="text-sm font-medium text-foreground truncate">
                        {u.nickname}
                        {u.isAdmin && (
                          <span className="ml-2 text-[10px] px-1.5 py-0.5 bg-accent/10 text-accent rounded-full font-medium">
                            Admin
                          </span>
                        )}
                      </div>
                      {u.email && <div className="text-xs text-muted truncate">{u.email}</div>}
                    </Link>
                  </td>
                  <td className="px-5 py-3 text-xs text-muted">{u.area ?? "-"}</td>
                  <td className="px-5 py-3 text-xs text-muted">{u.experience ?? "-"}</td>
                  <td className="px-5 py-3 text-sm text-right text-foreground">
                    {(u.totalPoints ?? 0).toLocaleString()}
                  </td>
                  <td className="px-5 py-3 text-xs text-muted">{formatDate(u.createdAt)}</td>
                  <td className="px-5 py-3 text-right">
                    <button
                      onClick={() => toggleAdmin(u)}
                      className="text-xs text-primary hover:underline"
                    >
                      {u.isAdmin ? "管理者解除" : "管理者に"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && (
            <div className="py-16 text-center text-sm text-muted">該当するユーザーがいません</div>
          )}
        </div>
      )}
    </div>
  );
}
