"use client";

import { useEffect, useState, useMemo } from "react";
import {
  collection,
  getDocs,
  addDoc,
  serverTimestamp,
  doc,
  getDoc,
  query,
  where,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useRouter } from "next/navigation";

interface Candidate {
  uid: string;
  nickname: string;
  avatarUrl?: string;
}

type Mode = "dm" | "group";

export default function NewChatPage() {
  const router = useRouter();
  const { user, profile, loading: authLoading } = useAuth();
  const [mode, setMode] = useState<Mode>("dm");
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [selected, setSelected] = useState<Map<string, Candidate>>(new Map());
  const [search, setSearch] = useState("");
  const [groupName, setGroupName] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!user) return;
    async function load() {
      if (!user) return;
      setLoading(true);
      try {
        const snap = await getDocs(collection(db, "users", user.uid, "following"));
        const uids = snap.docs.map((d) => d.id);
        const list: Candidate[] = [];
        await Promise.all(
          uids.map(async (uid) => {
            const us = await getDoc(doc(db, "users", uid));
            if (us.exists()) {
              const d = us.data();
              list.push({
                uid,
                nickname: d.nickname || "名前なし",
                avatarUrl: d.avatarUrl,
              });
            }
          })
        );
        list.sort((a, b) => a.nickname.localeCompare(b.nickname, "ja"));
        setCandidates(list);
      } catch {
        // ignore
      }
      setLoading(false);
    }
    load();
  }, [user]);

  const filtered = useMemo(() => {
    const kw = search.trim().toLowerCase();
    if (!kw) return candidates;
    return candidates.filter((c) => c.nickname.toLowerCase().includes(kw));
  }, [candidates, search]);

  const toggleSelect = (c: Candidate) => {
    setSelected((prev) => {
      const next = new Map(prev);
      if (next.has(c.uid)) {
        next.delete(c.uid);
      } else {
        if (mode === "dm") next.clear();
        next.set(c.uid, c);
      }
      return next;
    });
  };

  const changeMode = (m: Mode) => {
    setMode(m);
    setSelected(new Map());
  };

  const submit = async () => {
    if (!user || !profile) return;
    if (selected.size === 0) {
      setError(mode === "dm" ? "相手を選択してください" : "メンバーを1人以上選択してください");
      return;
    }
    if (mode === "group" && !groupName.trim()) {
      setError("グループ名を入力してください");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      if (mode === "dm") {
        const other = Array.from(selected.values())[0];
        // check existing DM
        const existing = await getDocs(
          query(
            collection(db, "chats"),
            where("type", "==", "dm"),
            where("members", "array-contains", user.uid)
          )
        );
        let chatId: string | null = null;
        for (const d of existing.docs) {
          const members = (d.data().members as string[]) ?? [];
          if (members.length === 2 && members.includes(other.uid)) {
            chatId = d.id;
            break;
          }
        }
        if (!chatId) {
          const ref = await addDoc(collection(db, "chats"), {
            type: "dm",
            members: [user.uid, other.uid],
            memberNames: {
              [user.uid]: profile.nickname,
              [other.uid]: other.nickname,
            },
            lastMessage: "",
            lastMessageAt: serverTimestamp(),
            lastRead: { [user.uid]: serverTimestamp() },
            createdAt: serverTimestamp(),
          });
          chatId = ref.id;
        }
        router.push(`/chat/${chatId}`);
      } else {
        const members = [user.uid, ...Array.from(selected.keys())];
        const memberNames: Record<string, string> = { [user.uid]: profile.nickname };
        selected.forEach((c, uid) => { memberNames[uid] = c.nickname; });
        const ref = await addDoc(collection(db, "chats"), {
          type: "group",
          name: groupName.trim(),
          members,
          memberNames,
          ownerId: user.uid,
          lastMessage: "",
          lastMessageAt: serverTimestamp(),
          lastRead: { [user.uid]: serverTimestamp() },
          createdAt: serverTimestamp(),
        });
        router.push(`/chat/${ref.id}`);
      }
    } catch {
      setError("チャットの作成に失敗しました");
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

  if (!user || !profile) {
    return (
      <div className="p-8 max-w-[800px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ログインが必要です</p>
        <Link href="/login" className="inline-block mt-4 text-primary text-sm hover:underline">ログイン</Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[800px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/chat" className="hover:text-primary transition-colors">チャット</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">新規作成</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-5">新しいチャット</h1>

      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 mb-6">
        <button
          onClick={() => changeMode("dm")}
          className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${
            mode === "dm" ? "bg-white text-foreground shadow-sm" : "text-muted hover:text-foreground"
          }`}
        >
          ダイレクトメッセージ
        </button>
        <button
          onClick={() => changeMode("group")}
          className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${
            mode === "group" ? "bg-white text-foreground shadow-sm" : "text-muted hover:text-foreground"
          }`}
        >
          グループチャット
        </button>
      </div>

      {mode === "group" && (
        <div className="mb-4">
          <label className="block text-sm font-medium text-foreground mb-1.5">
            グループ名 <span className="text-error">*</span>
          </label>
          <input
            type="text"
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
            placeholder="例: 週末ソフバレ仲間"
            className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            maxLength={40}
          />
        </div>
      )}

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
          {error}
        </div>
      )}

      <div className="relative mb-4">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="フォロー中のユーザーを検索..."
          className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
        />
      </div>

      {selected.size > 0 && (
        <div className="mb-4">
          <p className="text-xs text-muted mb-2">
            選択中 ({selected.size}
            {mode === "dm" ? "" : "人"})
          </p>
          <div className="flex flex-wrap gap-2">
            {Array.from(selected.values()).map((c) => (
              <button
                key={c.uid}
                onClick={() => toggleSelect(c)}
                className="inline-flex items-center gap-1.5 px-3 py-1 bg-primary/10 text-primary rounded-full text-xs font-medium hover:bg-primary/20 transition-colors"
              >
                {c.nickname}
                <span className="text-xs">×</span>
              </button>
            ))}
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between">
          <h2 className="text-sm font-bold text-foreground">フォロー中</h2>
          <span className="text-xs text-muted">{filtered.length}人</span>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-10">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="p-8 text-center">
            <p className="text-sm text-muted mb-2">
              {candidates.length === 0 ? "フォロー中のユーザーがいません" : "該当するユーザーがいません"}
            </p>
            {candidates.length === 0 && (
              <Link href="/follows/search" className="text-xs text-primary font-medium hover:underline">
                ユーザーを探す
              </Link>
            )}
          </div>
        ) : (
          <ul className="divide-y divide-gray-50 max-h-[420px] overflow-y-auto">
            {filtered.map((c) => {
              const isSelected = selected.has(c.uid);
              return (
                <li key={c.uid}>
                  <button
                    onClick={() => toggleSelect(c)}
                    className={`w-full flex items-center gap-3 px-5 py-3 hover:bg-gray-50 transition-colors text-left ${isSelected ? "bg-primary/5" : ""}`}
                  >
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
                      {c.avatarUrl ? (
                        <img src={c.avatarUrl} alt="" className="w-10 h-10 object-cover" />
                      ) : (
                        c.nickname.charAt(0)
                      )}
                    </div>
                    <span className="flex-1 min-w-0 text-sm font-medium text-foreground truncate">
                      {c.nickname}
                    </span>
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 ${
                        isSelected ? "bg-primary border-primary" : "border-gray-300"
                      }`}
                    >
                      {isSelected && (
                        <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M16.704 5.292a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-3-3a1 1 0 111.414-1.414L9 11.586l6.293-6.294a1 1 0 011.411 0z" clipRule="evenodd" />
                        </svg>
                      )}
                    </div>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <div className="flex gap-3">
        <button
          onClick={submit}
          disabled={submitting || selected.size === 0}
          className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          {submitting ? "作成中..." : mode === "dm" ? "メッセージを開始" : "グループを作成"}
        </button>
        <Link
          href="/chat"
          className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
        >
          キャンセル
        </Link>
      </div>
    </div>
  );
}
