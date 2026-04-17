"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  deleteDoc,
  doc,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { TournamentTemplate } from "@/types/firestore";
import Link from "next/link";

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleDateString("ja-JP");
}

export default function TournamentTemplatesPage() {
  const { user } = useAuth();
  const [templates, setTemplates] = useState<(TournamentTemplate & { ownerId?: string })[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      const t = setTimeout(() => setLoading(false), 0);
      return () => clearTimeout(t);
    }
    const q = query(
      collection(db, "tournamentTemplates"),
      where("ownerId", "==", user.uid),
      orderBy("updatedAt", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      setTemplates(snap.docs.map((d) => {
        const data = d.data() as Omit<TournamentTemplate, "id"> & { ownerId?: string };
        return { ...data, id: d.id };
      }));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [user]);

  const remove = async (t: TournamentTemplate) => {
    if (!confirm(`「${t.name}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "tournamentTemplates", t.id));
  };

  if (!user) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">ログインが必要です</p>
        <Link href="/login" className="inline-block mt-4 text-primary text-sm hover:underline">ログイン</Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[1000px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors">大会管理</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">テンプレート</span>
      </nav>

      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会テンプレート</h1>
          <p className="text-sm text-muted mt-1">過去の大会設定を保存して再利用できます</p>
        </div>
        <Link
          href="/tournaments/create"
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          大会を作成
        </Link>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : templates.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted mb-2">テンプレートがありません</p>
          <p className="text-xs text-muted">大会作成画面から「テンプレートとして保存」で登録できます</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {templates.map((t) => (
            <div key={t.id} className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-bold text-foreground truncate">{t.name}</div>
                  <div className="text-xs text-muted mt-0.5">{formatDate(t.updatedAt || t.createdAt)} 更新</div>
                </div>
                <button onClick={() => remove(t)} className="text-xs text-error hover:underline">削除</button>
              </div>
              <div className="grid grid-cols-2 gap-2 text-xs text-muted">
                {t.type && <div>カテゴリ: <span className="text-foreground font-medium">{t.type}</span></div>}
                {t.maxTeams && <div>最大チーム: <span className="text-foreground font-medium">{t.maxTeams}</span></div>}
                {t.courts && <div>コート数: <span className="text-foreground font-medium">{t.courts}</span></div>}
                {t.location && <div>会場: <span className="text-foreground font-medium truncate">{t.location}</span></div>}
              </div>
              {t.memo && (
                <p className="text-xs text-muted mt-3 line-clamp-2 pt-3 border-t border-gray-100">{t.memo}</p>
              )}
              <Link
                href={`/tournaments/create?template=${t.id}`}
                className="block w-full mt-4 px-4 py-2 bg-primary/10 text-primary rounded-lg text-xs font-semibold hover:bg-primary/20 transition-colors text-center"
              >
                このテンプレートで作成
              </Link>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
