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
import Header from "@/components/Header";
import StatusBadge from "@/components/StatusBadge";
import Scoreboard from "@/components/Scoreboard";
import Standings from "@/components/Standings";
import BracketView from "@/components/BracketView";

type Tab = "scoreboard" | "standings" | "bracket";

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
  const [activeTab, setActiveTab] = useState<Tab>("scoreboard");
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  // 大会データのリアルタイムリスナー
  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, "tournaments", tournamentId),
      (snap) => {
        if (snap.exists()) {
          setTournament({ id: snap.id, ...snap.data() } as Tournament);
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
        setSelectedRound(ids[ids.length - 1]); // 最新ラウンドを選択
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
      <div className="min-h-screen">
        <Header />
        <div className="flex items-center justify-center py-32">
          <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  if (!tournament) {
    return (
      <div className="min-h-screen">
        <Header />
        <div className="text-center py-32 text-muted">
          大会が見つかりません
        </div>
      </div>
    );
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: "scoreboard", label: "スコアボード" },
    { key: "standings", label: "順位表" },
    { key: "bracket", label: "決勝トーナメント" },
  ];

  const roundLabel = (id: string) => {
    const num = id.replace("round_", "");
    return `予選${num}`;
  };

  const statusIsLive = ["開催中", "決勝中"].includes(tournament.status) || tournament.status.includes("完了");

  return (
    <div className="min-h-screen">
      <Header />
      <main className="max-w-[1400px] mx-auto px-6 py-6">
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
                <span>📅 {tournament.date}</span>
                <span>📍 {tournament.location}</span>
                <span>🏐 {tournament.courts}コート</span>
                <span>
                  👥 {entries.length}/{tournament.maxTeams}チーム
                </span>
                <span>{tournament.type}</span>
              </div>
            </div>

            {/* サマリーカード */}
            {statusIsLive && (
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
            )}
          </div>
        </div>

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

          {activeTab !== "bracket" && roundIds.length > 0 && (
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

        {activeTab !== "bracket" && !selectedRound && roundIds.length === 0 && (
          <div className="text-center py-16 text-muted">
            まだ対戦表が生成されていません
          </div>
        )}
      </main>
    </div>
  );
}
