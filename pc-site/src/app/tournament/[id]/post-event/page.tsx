"use client";

import { use, useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  getDoc,
  writeBatch,
  serverTimestamp,
  increment,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Standing } from "@/types/firestore";
import Link from "next/link";

const DEFAULT_PRIZE_POINTS: Record<number, number> = {
  1: 100,
  2: 60,
  3: 40,
  4: 20,
};

type TeamRanking = Standing;

export default function PostEventPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { user } = useAuth();
  const [tournamentTitle, setTournamentTitle] = useState("");
  const [organizerId, setOrganizerId] = useState("");
  const [status, setStatus] = useState("");
  const [standings, setStandings] = useState<TeamRanking[]>([]);
  const [loading, setLoading] = useState(true);
  const [finalizing, setFinalizing] = useState(false);
  const [finalizeMessage, setFinalizeMessage] = useState("");

  useEffect(() => {
    async function loadTournament() {
      const snap = await getDoc(doc(db, "tournaments", id));
      if (snap.exists()) {
        setOrganizerId(snap.data().organizerId ?? "");
        setTournamentTitle(snap.data().title ?? "");
        setStatus(snap.data().status ?? "");
      }
    }
    loadTournament();
  }, [id]);

  useEffect(() => {
    const q = query(collection(db, "tournaments", id, "standings"), orderBy("rank", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setStandings(snap.docs.map((d) => d.data() as TeamRanking));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [id]);

  const isOrganizer = user?.uid === organizerId;

  const finalize = async () => {
    if (standings.length === 0) {
      alert("順位データがありません。先にスコア入力を完了してください。");
      return;
    }
    if (!confirm("大会を終了してポイントを配布しますか？\nこの操作は各チームのメンバーにポイントを付与します。")) return;
    setFinalizing(true);
    setFinalizeMessage("");
    try {
      const batch = writeBatch(db);
      // Update tournament status
      batch.update(doc(db, "tournaments", id), {
        status: "終了",
        finalizedAt: serverTimestamp(),
      });

      for (const s of standings) {
        const pts = DEFAULT_PRIZE_POINTS[s.rank] ?? 0;
        if (pts <= 0) continue;

        // Fetch members
        const teamSnap = await getDoc(doc(db, "teams", s.teamId));
        const members = ((teamSnap.data()?.memberIds ?? []) as string[]);
        if (members.length === 0) continue;

        for (const uid of members) {
          const userRef = doc(db, "users", uid);
          batch.update(userRef, {
            totalPoints: increment(pts),
            seasonPoints: increment(pts),
            ...(s.rank === 1 ? { "stats.championships": increment(1) } : {}),
            "stats.tournamentsPlayed": increment(1),
          });
          batch.set(doc(collection(db, "users", uid, "pointHistory")), {
            tournamentId: id,
            tournamentName: tournamentTitle,
            points: pts,
            rank: s.rank,
            createdAt: serverTimestamp(),
          });
          batch.set(doc(collection(db, "users", uid, "tournamentHistory")), {
            tournamentId: id,
            tournamentName: tournamentTitle,
            rank: s.rank,
            points: pts,
            createdAt: serverTimestamp(),
          });
        }
      }

      await batch.commit();
      setFinalizeMessage("大会を終了し、ポイントを配布しました");
      setStatus("終了");
    } catch {
      setFinalizeMessage("ポイント配布に失敗しました。権限・データを確認してください。");
    } finally {
      setFinalizing(false);
    }
  };

  const reopen = async () => {
    if (!confirm("大会のステータスを「開催中」に戻しますか？")) return;
    await updateDoc(doc(db, "tournaments", id), { status: "開催中" });
    setStatus("開催中");
  };

  if (!isOrganizer) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">主催者のみが実行できます</p>
        <Link href={`/tournament/${id}`} className="inline-block mt-4 text-primary text-sm hover:underline">
          大会詳細に戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href={`/tournament/${id}`} className="hover:text-primary transition-colors">
          {tournamentTitle || "大会"}
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">大会終了処理</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">大会終了処理</h1>
      <p className="text-sm text-muted mb-6">
        最終順位を確認し、ポイントを各チームのメンバーに配布します
      </p>

      {finalizeMessage && (
        <div className={`mb-4 p-3 border text-sm rounded-lg ${finalizeMessage.includes("失敗") ? "bg-red-50 border-red-200 text-error" : "bg-green-50 border-green-200 text-green-700"}`}>
          {finalizeMessage}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
        <div className="text-xs text-muted mb-1">現在のステータス</div>
        <div className="text-lg font-bold text-foreground">{status || "-"}</div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-gray-100">
          <h2 className="text-sm font-bold text-foreground">最終順位</h2>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-10">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : standings.length === 0 ? (
          <div className="p-8 text-center text-sm text-muted">
            順位データがありません。先に対戦表・スコア入力を完了してください。
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50/50 border-b border-gray-100">
              <tr>
                <th className="text-left text-xs font-medium text-muted px-5 py-2">順位</th>
                <th className="text-left text-xs font-medium text-muted px-5 py-2">チーム</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-2">勝-分-負</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-2">配布Pt</th>
              </tr>
            </thead>
            <tbody>
              {standings.map((s) => (
                <tr key={s.teamId} className="border-b border-gray-50">
                  <td className="px-5 py-2 text-sm font-bold text-foreground">{s.rank}位</td>
                  <td className="px-5 py-2 text-sm text-foreground">{s.teamName}</td>
                  <td className="px-5 py-2 text-sm text-right text-muted">
                    {s.wins}-{s.draws}-{s.losses}
                  </td>
                  <td className="px-5 py-2 text-sm text-right font-semibold text-accent">
                    {DEFAULT_PRIZE_POINTS[s.rank] ?? 0}pt
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h2 className="text-sm font-bold text-foreground mb-3">アクション</h2>
        <div className="flex flex-wrap gap-2">
          <button
            onClick={finalize}
            disabled={finalizing || status === "終了" || standings.length === 0}
            className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
          >
            {finalizing ? "処理中..." : "大会を終了してポイント配布"}
          </button>
          {status === "終了" && (
            <button
              onClick={reopen}
              className="px-5 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400"
            >
              開催中に戻す
            </button>
          )}
        </div>
        <p className="text-xs text-muted mt-3">
          ポイントは 1位: 100 / 2位: 60 / 3位: 40 / 4位: 20 で配布されます
        </p>
      </div>
    </div>
  );
}
