"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Tournament } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

export default function TournamentManagePage() {
  const { user, loading: authLoading } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) {
      setLoading(false);
      return;
    }
    const q = query(
      collection(db, "tournaments"),
      where("organizerId", "==", user.uid),
      orderBy("date", "desc")
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as Tournament[];
      setTournaments(list);
      setLoading(false);
    });
    return () => unsub();
  }, [user]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="page-container">
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">大会管理機能を利用するにはログインしてください</p>
          <Link href="/login" className="btn-primary">ログイン</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="page-container animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">大会管理</h1>
          <p className="text-sm text-muted mt-1">あなたが主催する大会を管理</p>
        </div>
        <Link href="/tournaments/create" className="btn-accent">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          新しい大会を作成
        </Link>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : tournaments.length === 0 ? (
        <div className="text-center py-20 card-static">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl gradient-navy flex items-center justify-center">
            <svg className="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">まだ大会がありません</h3>
          <p className="text-sm text-muted mb-6">新しい大会を作成して始めましょう</p>
          <Link href="/tournaments/create" className="btn-primary">大会を作成する</Link>
        </div>
      ) : (
        <div className="space-y-3">
          {tournaments.map((t) => (
            <div key={t.id} className="card flex items-center gap-5 p-4 group">
              <StatusBadge status={t.status} />
              <div className="flex-1 min-w-0">
                <h3 className="text-[15px] font-bold text-foreground group-hover:text-primary transition-colors truncate">{t.title}</h3>
                <div className="flex flex-wrap gap-4 mt-1 text-sm text-muted">
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
                    {t.date}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <svg className="w-3.5 h-3.5 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    {t.location}
                  </span>
                  <span className="font-medium">{t.currentTeams ?? 0}/{t.maxTeams}チーム</span>
                </div>
              </div>
              <div className="flex gap-2 flex-shrink-0">
                <Link href={`/tournament/${t.id}`} className="btn-secondary text-xs px-3 py-1.5">詳細</Link>
                <Link href={`/tournament/${t.id}/manage`} className="btn-primary text-xs px-3 py-1.5">管理</Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
