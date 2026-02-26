"use client";

import { useEffect, useState, use } from "react";
import {
  doc,
  onSnapshot,
  collection,
  getDocs,
  query,
  orderBy,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament, Match, Entry } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Scoreboard from "@/components/Scoreboard";
import Standings from "@/components/Standings";
import BracketView from "@/components/BracketView";
import TournamentInfo from "@/components/TournamentInfo";
import TeamList from "@/components/TeamList";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

type Tab = "info" | "scoreboard" | "standings" | "bracket" | "teams";

export default function TournamentPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: tournamentId } = use(params);
  const [tournament, setTournament] = useState<Tournament | null>(null);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [roundIds, setRoundIds] = useState<string[]>([]);
  const [courtIds, setCourtIds] = useState<string[]>([]);
  const [selectedRound, setSelectedRound] = useState<string>("");
  const [activeTab, setActiveTab] = useState<Tab>("info");
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());
  const { user } = useAuth();

  // 大会データのリアルタイムリスナー
  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, "tournaments", tournamentId),
      (snap) => {
        if (snap.exists()) {
          const data = { id: snap.id, ...snap.data() } as Tournament;
          setTournament(data);
          // Auto-select tab based on status
          const liveStatuses = ["開催中", "決勝中"];
          if (liveStatuses.includes(data.status) || data.status.includes("完了")) {
            if (data.status === "決勝中") {
              setActiveTab("bracket");
            } else {
              setActiveTab("scoreboard");
            }
          }
        }
        setLoading(false);
        setLastUpdate(new Date());
      }
    );
    return () => unsub();
  }, [tournamentId]);

  // エントリー取得
  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, "tournaments", tournamentId, "entries"),
      (snap) => {
        setEntries(
          snap.docs.map((d) => ({ ...d.data() } as Entry))
        );
      }
    );
    return () => unsub();
  }, [tournamentId]);

  // ラウンド一覧取得
  useEffect(() => {
    async function loadRounds() {
      const roundsSnap = await getDocs(
        collection(db, "tournaments", tournamentId, "rounds")
      );
      const ids = roundsSnap.docs.map((d) => d.id).sort();
      setRoundIds(ids);
      if (ids.length > 0 && !selectedRound) {
        setSelectedRound(ids[ids.length - 1]);
      }
    }
    loadRounds();
  }, [tournamentId, selectedRound]);

  // 選択ラウンドのコートID取得
  useEffect(() => {
    if (!selectedRound) return;

    const q = query(
      collection(
        db,
        "tournaments",
        tournamentId,
        "rounds",
        selectedRound,
        "matches"
      ),
      orderBy("courtNumber")
    );

    const unsub = onSnapshot(q, (snap) => {
      const courts = new Set<string>();
      snap.docs.forEach((d) => {
        const data = d.data() as Match;
        if (data.courtId) courts.add(data.courtId);
      });
      setCourtIds(Array.from(courts).sort());
    });

    return () => unsub();
  }, [tournamentId, selectedRound]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!tournament) {
    return (
      <div className="text-center py-32 text-muted">
        <div className="text-4xl mb-4">🔍</div>
        <p>大会が見つかりません</p>
        <Link href="/tournaments" className="text-primary text-sm hover:underline mt-2 inline-block">
          大会一覧に戻る
        </Link>
      </div>
    );
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: "info", label: "大会情報" },
    { key: "scoreboard", label: "スコアボード" },
    { key: "standings", label: "順位表" },
    { key: "bracket", label: "決勝トーナメント" },
    { key: "teams", label: "参加チーム" },
  ];

  const roundLabel = (id: string) => {
    const num = id.replace("round_", "");
    return `予選${num}`;
  };

  const statusIsLive = ["開催中", "決勝中"].includes(tournament.status) || tournament.status.includes("完了");

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-4">
        <Link href="/tournaments" className="hover:text-primary transition-colors">大会一覧</Link>
        <span>/</span>
        <span className="text-foreground">{tournament.title}</span>
      </div>

      {/* 大会ヘッダー */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <div className="flex items-start justify-between">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <StatusBadge status={tournament.status} />
              {statusIsLive && (
                <span className="text-xs text-muted">
                  最終更新: {lastUpdate.toLocaleTimeString("ja-JP")}
                </span>
              )}
            </div>
            <h1 className="text-2xl font-bold text-foreground mb-2">
              {tournament.title}
            </h1>
            <div className="flex flex-wrap gap-4 text-sm text-muted">
              <span className="flex items-center gap-1.5">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>
                {tournament.date}
              </span>
              <span className="flex items-center gap-1.5">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                {tournament.location}
              </span>
              <span>{tournament.type}</span>
            </div>
          </div>

          {/* サマリーカード */}
          <div className="flex gap-4">
            <div className="bg-blue-50 rounded-lg px-4 py-3 text-center">
              <div className="text-2xl font-bold text-blue-700">
                {entries.length}
              </div>
              <div className="text-xs text-blue-600">チーム</div>
            </div>
            <div className="bg-green-50 rounded-lg px-4 py-3 text-center">
              <div className="text-2xl font-bold text-green-700">
                {tournament.courts}
              </div>
              <div className="text-xs text-green-600">コート</div>
            </div>
            <div className="bg-purple-50 rounded-lg px-4 py-3 text-center">
              <div className="text-2xl font-bold text-purple-700">
                {roundIds.length}
              </div>
              <div className="text-xs text-purple-600">ラウンド</div>
            </div>
          </div>
        </div>
      </div>

      {/* Manage button for organizer */}
      {user && tournament.organizerId === user.uid && (
        <div className="mb-4">
          <Link
            href={`/tournament/${tournamentId}/manage`}
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
            </svg>
            管理パネル
          </Link>
        </div>
      )}

      {/* タブ & ラウンド選択 */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex gap-1 bg-gray-100 rounded-lg p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                activeTab === tab.key
                  ? "bg-white text-primary shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {(activeTab === "scoreboard" || activeTab === "standings") && roundIds.length > 0 && (
          <div className="flex items-center gap-2">
            <span className="text-sm text-muted">ラウンド:</span>
            <div className="flex gap-1">
              {roundIds.map((rid) => (
                <button
                  key={rid}
                  onClick={() => setSelectedRound(rid)}
                  className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                    selectedRound === rid
                      ? "bg-primary text-white"
                      : "bg-white text-muted hover:bg-gray-100 border border-gray-200"
                  }`}
                >
                  {roundLabel(rid)}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* タブコンテンツ */}
      {activeTab === "info" && (
        <TournamentInfo tournament={tournament} entries={entries} />
      )}
      {activeTab === "scoreboard" && selectedRound && (
        <Scoreboard
          tournamentId={tournamentId}
          roundId={selectedRound}
        />
      )}
      {activeTab === "standings" && selectedRound && (
        <Standings
          tournamentId={tournamentId}
          roundId={selectedRound}
          courtIds={courtIds}
        />
      )}
      {activeTab === "bracket" && (
        <BracketView tournamentId={tournamentId} />
      )}
      {activeTab === "teams" && (
        <TeamList entries={entries} tournamentId={tournamentId} />
      )}

      {(activeTab === "scoreboard" || activeTab === "standings") && !selectedRound && roundIds.length === 0 && (
        <div className="text-center py-16 text-muted bg-white rounded-xl border border-gray-200">
          まだ対戦表が生成されていません
        </div>
      )}
    </div>
  );
}
