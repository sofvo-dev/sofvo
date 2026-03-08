"use client";

import { useEffect, useState, use } from "react";
import dynamic from "next/dynamic";
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
import TournamentInfo from "@/components/TournamentInfo";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

const Scoreboard = dynamic(() => import("@/components/Scoreboard"), {
  loading: () => <div className="flex justify-center py-12"><div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>,
});
const Standings = dynamic(() => import("@/components/Standings"), {
  loading: () => <div className="flex justify-center py-12"><div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>,
});
const BracketView = dynamic(() => import("@/components/BracketView"), {
  loading: () => <div className="flex justify-center py-12"><div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>,
});
const TeamList = dynamic(() => import("@/components/TeamList"), {
  loading: () => <div className="flex justify-center py-12"><div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>,
});

type Tab = "info" | "scoreboard" | "standings" | "bracket" | "teams";

const tabIcons: Record<Tab, React.ReactNode> = {
  info: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>,
  scoreboard: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" /></svg>,
  standings: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" /></svg>,
  bracket: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772" /></svg>,
  teams: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A8.88 8.88 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" /></svg>,
};

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
  const { user, loading: authLoading } = useAuth();

  useEffect(() => {
    const unsub = onSnapshot(
      doc(db, "tournaments", tournamentId),
      (snap) => {
        if (snap.exists()) {
          const data = { id: snap.id, ...snap.data() } as Tournament;
          setTournament(data);
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

  useEffect(() => {
    async function loadRounds() {
      const roundsSnap = await getDocs(
        collection(db, "tournaments", tournamentId, "rounds")
      );
      const ids = roundsSnap.docs.map((d) => d.id).sort();
      setRoundIds(ids);
      if (ids.length > 0) {
        setSelectedRound((prev) => prev || ids[ids.length - 1]);
      }
    }
    loadRounds();
  }, [tournamentId]);

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
        <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
          <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
        </div>
        <p className="text-lg font-bold mb-2">大会が見つかりません</p>
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
  const fillPct = tournament.maxTeams > 0 ? Math.min(100, (entries.length / tournament.maxTeams) * 100) : 0;

  return (
    <div className="p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-5">
        <Link href="/tournaments" className="hover:text-primary transition-colors flex items-center gap-1">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
          大会一覧
        </Link>
        <span className="text-hint">/</span>
        <span className="text-foreground font-medium">{tournament.title}</span>
      </div>

      {/* Hero Header with gradient */}
      <div className="rounded-2xl overflow-hidden mb-6 border border-gray-200">
        <div className="gradient-navy px-8 py-7 relative">
          <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
          <div className="absolute bottom-[-20px] left-[25%] w-28 h-28 rounded-full bg-white/5" />
          <div className="relative z-10">
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-center gap-3 mb-3">
                  <StatusBadge status={tournament.status} />
                  {statusIsLive && (
                    <span className="text-xs text-white/50">
                      最終更新: {lastUpdate.toLocaleTimeString("ja-JP")}
                    </span>
                  )}
                </div>
                <h1 className="text-2xl font-bold text-white mb-3">
                  {tournament.title}
                </h1>
                <div className="flex flex-wrap gap-5 text-sm text-white/70">
                  <span className="flex items-center gap-1.5">
                    <svg className="w-4 h-4 text-white/50" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>
                    {tournament.date}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <svg className="w-4 h-4 text-white/50" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    {tournament.location}
                  </span>
                  <span className="flex items-center gap-1.5">
                    <svg className="w-4 h-4 text-white/50" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z" /><path strokeLinecap="round" strokeLinejoin="round" d="M6 6h.008v.008H6V6z" /></svg>
                    {tournament.type}
                  </span>
                </div>
              </div>

              {/* Manage button for organizer */}
              {!authLoading && user && tournament.organizerId === user.uid && (
                <Link
                  href={`/tournament/${tournamentId}/manage`}
                  className="flex items-center gap-2 px-5 py-2.5 bg-white/15 text-white rounded-xl text-sm font-medium hover:bg-white/25 transition-colors border border-white/20"
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
                  </svg>
                  管理パネル
                </Link>
              )}
            </div>
          </div>
        </div>

        {/* Summary stats bar */}
        <div className="bg-white px-8 py-4 flex items-center gap-6">
          <div className="flex items-center gap-3 flex-1">
            <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center">
              <svg className="w-5 h-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>
            </div>
            <div>
              <div className="text-lg font-bold text-foreground">{entries.length}<span className="text-muted font-normal text-sm">/{tournament.maxTeams}</span></div>
              <div className="text-[11px] text-muted">チーム</div>
            </div>
            <div className="flex-1 max-w-[120px] ml-2">
              <div className="progress-bar h-1.5">
                <div className="progress-bar-fill bg-blue-500" style={{ width: `${fillPct}%` }} />
              </div>
            </div>
          </div>

          <div className="w-px h-10 bg-gray-200" />

          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-green-50 flex items-center justify-center">
              <svg className="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" /></svg>
            </div>
            <div>
              <div className="text-lg font-bold text-foreground">{tournament.courts}</div>
              <div className="text-[11px] text-muted">コート</div>
            </div>
          </div>

          <div className="w-px h-10 bg-gray-200" />

          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-purple-50 flex items-center justify-center">
              <svg className="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 12c0-1.232-.046-2.453-.138-3.662a4.006 4.006 0 00-3.7-3.7 48.678 48.678 0 00-7.324 0 4.006 4.006 0 00-3.7 3.7c-.017.22-.032.441-.046.662M19.5 12l3-3m-3 3l-3-3m-12 3c0 1.232.046 2.453.138 3.662a4.006 4.006 0 003.7 3.7 48.656 48.656 0 007.324 0 4.006 4.006 0 003.7-3.7c.017-.22.032-.441.046-.662M4.5 12l3 3m-3-3l-3 3" /></svg>
            </div>
            <div>
              <div className="text-lg font-bold text-foreground">{roundIds.length}</div>
              <div className="text-[11px] text-muted">ラウンド</div>
            </div>
          </div>

          {tournament.entryFee !== undefined && tournament.entryFee > 0 && (
            <>
              <div className="w-px h-10 bg-gray-200" />
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center">
                  <svg className="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </div>
                <div>
                  <div className="text-lg font-bold text-foreground">¥{tournament.entryFee.toLocaleString()}</div>
                  <div className="text-[11px] text-muted">参加費</div>
                </div>
              </div>
            </>
          )}
        </div>
      </div>

      {/* タブ & ラウンド選択 */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex gap-1 bg-gray-100 rounded-xl p-1">
          {tabs.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium transition-all ${
                activeTab === tab.key
                  ? "bg-white text-primary shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              {tabIcons[tab.key]}
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
                  className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                    selectedRound === rid
                      ? "bg-primary text-white shadow-sm"
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
      <div className="animate-fade-in">
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
      </div>

      {(activeTab === "scoreboard" || activeTab === "standings") && !selectedRound && roundIds.length === 0 && (
        <div className="text-center py-16 text-muted bg-white rounded-xl border border-gray-200">
          <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-gray-100 flex items-center justify-center">
            <svg className="w-6 h-6 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          まだ対戦表が生成されていません
        </div>
      )}
    </div>
  );
}
