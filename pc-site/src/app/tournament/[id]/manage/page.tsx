"use client";

import { useEffect, useState, use } from "react";
import {
  doc, onSnapshot, collection, getDocs, updateDoc, addDoc, deleteDoc, query, orderBy, Timestamp, writeBatch,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Tournament, Entry, Match, Expense, CheckIn } from "@/types/firestore";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

type Tab = "overview" | "entries" | "scores" | "checkin" | "finance" | "settings";

const tabIcons: Record<Tab, React.ReactNode> = {
  overview: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" /></svg>,
  entries: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>,
  scores: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z" /></svg>,
  checkin: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
  finance: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
  settings: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>,
};

export default function TournamentManagePage({ params }: { params: Promise<{ id: string }> }) {
  const { id: tournamentId } = use(params);
  const { user } = useAuth();
  const [tournament, setTournament] = useState<Tournament | null>(null);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [checkIns, setCheckIns] = useState<CheckIn[]>([]);
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [roundMatches, setRoundMatches] = useState<Map<string, Match[]>>(new Map());
  const [roundIds, setRoundIds] = useState<string[]>([]);
  const [selectedRound, setSelectedRound] = useState("");
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, "tournaments", tournamentId), (snap) => {
      if (snap.exists()) setTournament({ id: snap.id, ...snap.data() } as Tournament);
      setLoading(false);
    });
    return () => unsub();
  }, [tournamentId]);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, "tournaments", tournamentId, "entries"), (snap) => {
      setEntries(snap.docs.map((d) => ({ ...d.data() } as Entry)));
    });
    return () => unsub();
  }, [tournamentId]);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, "tournaments", tournamentId, "checkIns"), (snap) => {
      setCheckIns(snap.docs.map((d) => ({ ...d.data() } as CheckIn)));
    });
    return () => unsub();
  }, [tournamentId]);

  useEffect(() => {
    const unsub = onSnapshot(query(collection(db, "tournaments", tournamentId, "expenses"), orderBy("createdAt", "desc")), (snap) => {
      setExpenses(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Expense)));
    });
    return () => unsub();
  }, [tournamentId]);

  useEffect(() => {
    async function loadRounds() {
      const snap = await getDocs(collection(db, "tournaments", tournamentId, "rounds"));
      const ids = snap.docs.map((d) => d.id).sort();
      setRoundIds(ids);
      if (ids.length > 0 && !selectedRound) setSelectedRound(ids[ids.length - 1]);
    }
    loadRounds();
  }, [tournamentId, selectedRound]);

  useEffect(() => {
    if (!selectedRound) return;
    const unsub = onSnapshot(
      query(collection(db, "tournaments", tournamentId, "rounds", selectedRound, "matches"), orderBy("courtNumber"), orderBy("matchOrder")),
      (snap) => {
        setRoundMatches((prev) => {
          const next = new Map(prev);
          next.set(selectedRound, snap.docs.map((d) => ({ id: d.id, ...d.data() } as Match)));
          return next;
        });
      }
    );
    return () => unsub();
  }, [tournamentId, selectedRound]);

  if (loading) return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  if (!tournament) return <div className="text-center py-32 text-muted">大会が見つかりません</div>;
  if (!user || tournament.organizerId !== user.uid) {
    return (
      <div className="p-8">
        <div className="text-center py-20 bg-white rounded-2xl border border-gray-200">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">管理権限がありません</h3>
          <Link href={`/tournament/${tournamentId}`} className="text-sm text-primary hover:underline">大会詳細に戻る</Link>
        </div>
      </div>
    );
  }

  const tabs: { key: Tab; label: string }[] = [
    { key: "overview", label: "概要" },
    { key: "entries", label: `エントリー (${entries.length})` },
    { key: "scores", label: "スコア入力" },
    { key: "checkin", label: `チェックイン (${checkIns.length}/${entries.length})` },
    { key: "finance", label: "収支" },
    { key: "settings", label: "大会設定" },
  ];

  return (
    <div className="p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-5">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors flex items-center gap-1">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
          大会管理
        </Link>
        <span className="text-hint">/</span>
        <Link href={`/tournament/${tournamentId}`} className="hover:text-primary transition-colors">{tournament.title}</Link>
        <span className="text-hint">/</span>
        <span className="text-foreground font-medium">管理パネル</span>
      </div>

      {/* Header with gradient */}
      <div className="rounded-2xl overflow-hidden mb-6 border border-gray-200">
        <div className="gradient-navy px-8 py-6 relative">
          <div className="absolute top-[-30px] right-[-30px] w-40 h-40 rounded-full bg-white/5" />
          <div className="relative z-10 flex items-center justify-between">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-xl font-bold text-white">{tournament.title}</h1>
                <StatusBadge status={tournament.status} />
              </div>
              <p className="text-sm text-white/60 flex items-center gap-4">
                <span className="flex items-center gap-1.5">
                  <svg className="w-3.5 h-3.5 text-white/40" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
                  {tournament.date}
                </span>
                <span className="flex items-center gap-1.5">
                  <svg className="w-3.5 h-3.5 text-white/40" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                  {tournament.location}
                </span>
              </p>
            </div>
            <StatusChanger tournamentId={tournamentId} currentStatus={tournament.status} />
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-xl p-1 mb-6 overflow-x-auto">
        {tabs.map((tab) => (
          <button key={tab.key} onClick={() => setActiveTab(tab.key)}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-lg text-sm font-medium transition-all whitespace-nowrap ${activeTab === tab.key ? "bg-white text-primary shadow-sm" : "text-muted hover:text-foreground"}`}
          >
            {tabIcons[tab.key]}
            {tab.label}
          </button>
        ))}
      </div>

      <div className="animate-fade-in">
        {activeTab === "overview" && <OverviewTab tournament={tournament} entries={entries} checkIns={checkIns} expenses={expenses} />}
        {activeTab === "entries" && <EntriesTab entries={entries} tournamentId={tournamentId} />}
        {activeTab === "scores" && <ScoresTab matches={roundMatches.get(selectedRound) || []} roundIds={roundIds} selectedRound={selectedRound} onSelectRound={setSelectedRound} tournamentId={tournamentId} />}
        {activeTab === "checkin" && <CheckInTab entries={entries} checkIns={checkIns} tournamentId={tournamentId} />}
        {activeTab === "finance" && <FinanceTab tournament={tournament} entries={entries} expenses={expenses} tournamentId={tournamentId} />}
        {activeTab === "settings" && <SettingsTab tournament={tournament} tournamentId={tournamentId} />}
      </div>
    </div>
  );
}

function StatusChanger({ tournamentId, currentStatus }: { tournamentId: string; currentStatus: string }) {
  const statuses = ["募集中", "準備中", "満員", "開催中", "決勝中", "終了"];
  const [open, setOpen] = useState(false);
  return (
    <div className="relative">
      <button onClick={() => setOpen(!open)} className="px-4 py-2 bg-white/15 text-white rounded-xl text-sm font-medium hover:bg-white/25 transition-colors border border-white/20 flex items-center gap-2">
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" /></svg>
        ステータス変更
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-2 bg-white border border-gray-200 rounded-xl shadow-lg z-10 min-w-[180px] overflow-hidden">
          {statuses.map((s) => (
            <button key={s} onClick={async () => { await updateDoc(doc(db, "tournaments", tournamentId), { status: s }); setOpen(false); }}
              className={`w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 transition-colors flex items-center gap-2 ${s === currentStatus ? "text-primary font-bold bg-primary/5" : "text-foreground"}`}
            >
              {s === currentStatus && <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>}
              {s}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function OverviewTab({ tournament: t, entries, checkIns, expenses }: { tournament: Tournament; entries: Entry[]; checkIns: CheckIn[]; expenses: Expense[] }) {
  const revenue = (t.entryFee || 0) * entries.length;
  const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
  const profit = revenue - totalExpenses;
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div className="card-static stat-navy p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <svg className="w-5 h-5 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>
          </div>
          <div className="text-xs font-medium text-muted">参加チーム</div>
        </div>
        <div className="text-2xl font-bold text-primary">{entries.length}<span className="text-sm text-muted font-normal">/{t.maxTeams}</span></div>
      </div>
      <div className="card-static stat-green p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-green-500/10 flex items-center justify-center">
            <svg className="w-5 h-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          <div className="text-xs font-medium text-muted">チェックイン</div>
        </div>
        <div className="text-2xl font-bold text-success">{checkIns.length}<span className="text-sm text-muted font-normal">/{entries.length}</span></div>
      </div>
      <div className="card-static stat-blue p-5">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-xl bg-info/10 flex items-center justify-center">
            <svg className="w-5 h-5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          <div className="text-xs font-medium text-muted">収入</div>
        </div>
        <div className="text-2xl font-bold text-info">¥{revenue.toLocaleString()}</div>
        <div className="text-xs text-muted mt-1">¥{(t.entryFee || 0).toLocaleString()} x {entries.length}</div>
      </div>
      <div className={`card-static ${profit >= 0 ? "stat-green" : "stat-red"} p-5`}>
        <div className="flex items-center gap-3 mb-2">
          <div className={`w-10 h-10 rounded-xl ${profit >= 0 ? "bg-green-500/10" : "bg-red-500/10"} flex items-center justify-center`}>
            <svg className={`w-5 h-5 ${profit >= 0 ? "text-success" : "text-error"}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" /></svg>
          </div>
          <div className="text-xs font-medium text-muted">{profit >= 0 ? "利益" : "赤字"}</div>
        </div>
        <div className={`text-2xl font-bold ${profit >= 0 ? "text-success" : "text-error"}`}>¥{Math.abs(profit).toLocaleString()}</div>
        <div className="text-xs text-muted mt-1">支出: ¥{totalExpenses.toLocaleString()}</div>
      </div>
    </div>
  );
}

function EntriesTab({ entries, tournamentId }: { entries: Entry[]; tournamentId: string }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
      <div className="section-header-navy px-5 py-4 flex items-center justify-between">
        <h3 className="text-sm font-bold text-foreground flex items-center gap-2">
          <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584" /></svg>
          エントリー一覧 ({entries.length}チーム)
        </h3>
      </div>
      {entries.length === 0 ? (
        <div className="text-center py-16 text-muted text-sm">
          <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-gray-100 flex items-center justify-center">
            <svg className="w-6 h-6 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72" /></svg>
          </div>
          まだエントリーがありません
        </div>
      ) : (
        <div className="divide-y divide-gray-100">
          {entries.map((e, i) => (
            <div key={e.teamId || i} className="px-5 py-3.5 flex items-center gap-4 hover:bg-gray-50 transition-colors">
              <span className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm">{i + 1}</span>
              <div className="flex-1"><span className="text-sm font-semibold text-foreground">{e.teamName}</span></div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ScoresTab({ matches, roundIds, selectedRound, onSelectRound, tournamentId }: {
  matches: Match[]; roundIds: string[]; selectedRound: string; onSelectRound: (id: string) => void; tournamentId: string;
}) {
  const [editingMatch, setEditingMatch] = useState<string | null>(null);
  const [scores, setScores] = useState<Record<string, { sets: { a: number; b: number }[] }>>({});

  const handleScoreChange = (matchId: string, setIndex: number, team: "a" | "b", value: number) => {
    setScores((prev) => {
      const match = matches.find((m) => m.id === matchId);
      const current = prev[matchId] || { sets: match?.sets?.map((s) => ({ ...s })) || [] };
      const sets = [...current.sets];
      if (!sets[setIndex]) sets[setIndex] = { a: 0, b: 0 };
      sets[setIndex] = { ...sets[setIndex], [team]: value };
      return { ...prev, [matchId]: { sets } };
    });
  };

  const saveScore = async (matchId: string) => {
    const data = scores[matchId];
    if (!data) return;
    const matchRef = doc(db, "tournaments", tournamentId, "rounds", selectedRound, "matches", matchId);
    await updateDoc(matchRef, { sets: data.sets });
    setEditingMatch(null);
  };

  return (
    <div>
      {roundIds.length > 0 && (
        <div className="flex gap-2 mb-4">
          {roundIds.map((rid) => (
            <button key={rid} onClick={() => onSelectRound(rid)}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${selectedRound === rid ? "bg-primary text-white shadow-sm" : "bg-white text-muted border border-gray-200 hover:bg-gray-100"}`}
            >予選{rid.replace("round_", "")}</button>
          ))}
        </div>
      )}
      {matches.length === 0 ? (
        <div className="text-center py-16 text-muted bg-white rounded-2xl border border-gray-200">
          <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-gray-100 flex items-center justify-center">
            <svg className="w-6 h-6 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          対戦表がまだ生成されていません
        </div>
      ) : (
        <div className="space-y-3">
          {matches.map((m) => {
            const isEditing = editingMatch === m.id;
            const editSets = scores[m.id]?.sets || m.sets || [];
            return (
              <div key={m.id} className={`bg-white rounded-2xl border ${isEditing ? "border-primary ring-2 ring-primary/10" : "border-gray-200"} p-5 transition-all`}>
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-bold text-muted flex items-center gap-2">
                    <span className="w-6 h-6 rounded-md bg-primary/10 flex items-center justify-center text-primary text-[10px] font-bold">{m.courtId?.replace("court_", "").toUpperCase()}</span>
                    コート 第{m.matchOrder}試合
                  </span>
                  <div className="flex items-center gap-2">
                    <span className={`text-xs px-2.5 py-1 rounded-lg font-medium ${m.status === "completed" ? "bg-green-50 text-green-700 border border-green-200" : "bg-gray-100 text-gray-600"}`}>
                      {m.status === "completed" ? "完了" : "未完了"}
                    </span>
                    {!isEditing ? (
                      <button onClick={() => { setEditingMatch(m.id); if (!scores[m.id]) setScores((prev) => ({ ...prev, [m.id]: { sets: m.sets?.map((s) => ({ ...s })) || [] } })); }}
                        className="text-xs text-primary hover:underline font-medium flex items-center gap-1">
                        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z" /></svg>
                        編集
                      </button>
                    ) : (
                      <button onClick={() => saveScore(m.id)} className="text-xs bg-primary text-white px-4 py-1.5 rounded-lg hover:bg-primary-dark font-medium transition-colors">保存</button>
                    )}
                  </div>
                </div>
                <div className="grid grid-cols-[1fr_auto_1fr] gap-4 items-center">
                  <span className="text-sm font-bold text-foreground truncate">{m.teamAName}</span>
                  <div className="flex gap-2">
                    {editSets.map((s, si) => (
                      <div key={si} className="text-center">
                        <div className="text-[10px] text-muted mb-1 font-medium">S{si + 1}</div>
                        {isEditing ? (
                          <div className="flex gap-1">
                            <input type="number" value={s.a} onChange={(e) => handleScoreChange(m.id, si, "a", parseInt(e.target.value) || 0)}
                              className="w-10 text-center border border-gray-300 rounded-lg text-sm py-1 focus:border-primary focus:ring-2 focus:ring-primary/10" min={0} />
                            <span className="text-muted self-center">-</span>
                            <input type="number" value={s.b} onChange={(e) => handleScoreChange(m.id, si, "b", parseInt(e.target.value) || 0)}
                              className="w-10 text-center border border-gray-300 rounded-lg text-sm py-1 focus:border-primary focus:ring-2 focus:ring-primary/10" min={0} />
                          </div>
                        ) : (
                          <span className="text-sm font-bold">{s.a} - {s.b}</span>
                        )}
                      </div>
                    ))}
                  </div>
                  <span className="text-sm font-bold text-foreground truncate text-right">{m.teamBName}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function CheckInTab({ entries, checkIns, tournamentId }: { entries: Entry[]; checkIns: CheckIn[]; tournamentId: string }) {
  const checkedTeamIds = new Set(checkIns.map((c) => c.teamId));
  const progress = entries.length > 0 ? (checkIns.length / entries.length) * 100 : 0;

  const toggleCheckIn = async (entry: Entry) => {
    if (checkedTeamIds.has(entry.teamId)) {
      const snap = await getDocs(collection(db, "tournaments", tournamentId, "checkIns"));
      const docToDelete = snap.docs.find((d) => d.data().teamId === entry.teamId);
      if (docToDelete) await deleteDoc(docToDelete.ref);
    } else {
      await addDoc(collection(db, "tournaments", tournamentId, "checkIns"), {
        teamId: entry.teamId, teamName: entry.teamName, checkedInAt: Timestamp.now(),
      });
    }
  };

  return (
    <div>
      <div className="bg-white rounded-2xl border border-gray-200 p-5 mb-4">
        <div className="flex items-center justify-between mb-3">
          <span className="text-sm font-bold text-foreground flex items-center gap-2">
            <svg className="w-4 h-4 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            チェックイン状況
          </span>
          <span className="text-sm font-bold text-primary">{checkIns.length}/{entries.length} 完了</span>
        </div>
        <div className="progress-bar">
          <div className="progress-bar-fill bg-green-500" style={{ width: `${progress}%` }} />
        </div>
        {progress === 100 && (
          <div className="text-center mt-3 text-green-600 font-bold text-sm flex items-center justify-center gap-2">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            全チームチェックイン完了!
          </div>
        )}
      </div>
      <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
        <div className="divide-y divide-gray-100">
          {entries.map((e, i) => {
            const checked = checkedTeamIds.has(e.teamId);
            return (
              <div key={e.teamId || i} className={`px-5 py-3.5 flex items-center gap-4 transition-colors ${checked ? "bg-green-50/50" : "hover:bg-gray-50"}`}>
                <button onClick={() => toggleCheckIn(e)}
                  className={`w-7 h-7 rounded-full border-2 flex items-center justify-center transition-all ${checked ? "bg-green-500 border-green-500 text-white scale-110" : "border-gray-300 hover:border-primary"}`}
                >
                  {checked && <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>}
                </button>
                <span className={`text-sm font-medium ${checked ? "text-foreground" : "text-muted"}`}>{e.teamName}</span>
                {checked && <span className="text-xs text-green-600 ml-auto font-medium badge-gold" style={{ background: "rgba(46,125,50,0.1)", color: "#2E7D32", borderColor: "rgba(46,125,50,0.2)" }}>到着</span>}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function FinanceTab({ tournament, entries, expenses, tournamentId }: { tournament: Tournament; entries: Entry[]; expenses: Expense[]; tournamentId: string }) {
  const [newName, setNewName] = useState("");
  const [newAmount, setNewAmount] = useState("");
  const revenue = (tournament.entryFee || 0) * entries.length;
  const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
  const profit = revenue - totalExpenses;

  const addExpense = async () => {
    if (!newName || !newAmount) return;
    await addDoc(collection(db, "tournaments", tournamentId, "expenses"), {
      name: newName, amount: parseInt(newAmount) || 0, createdAt: Timestamp.now(),
    });
    setNewName("");
    setNewAmount("");
  };

  const removeExpense = async (id: string) => {
    await deleteDoc(doc(db, "tournaments", tournamentId, "expenses", id));
  };

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-4">
        <div className="card-static stat-blue p-5">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-8 h-8 rounded-lg bg-info/10 flex items-center justify-center">
              <svg className="w-4 h-4 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" /></svg>
            </div>
            <div className="text-sm font-medium text-info">収入</div>
          </div>
          <div className="text-2xl font-bold text-info">¥{revenue.toLocaleString()}</div>
          <div className="text-xs text-muted mt-1">¥{(tournament.entryFee || 0).toLocaleString()} x {entries.length}チーム</div>
        </div>
        <div className="card-static stat-red p-5">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-8 h-8 rounded-lg bg-error/10 flex items-center justify-center">
              <svg className="w-4 h-4 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 6L9 12.75l4.286-4.286a11.948 11.948 0 014.306 6.43l.776 2.898m0 0l3.182-5.511m-3.182 5.51l-5.511-3.181" /></svg>
            </div>
            <div className="text-sm font-medium text-error">支出</div>
          </div>
          <div className="text-2xl font-bold text-error">¥{totalExpenses.toLocaleString()}</div>
          <div className="text-xs text-muted mt-1">{expenses.length}件の支出</div>
        </div>
        <div className={`card-static ${profit >= 0 ? "stat-green" : "stat-red"} p-5`}>
          <div className="flex items-center gap-2 mb-2">
            <div className={`w-8 h-8 rounded-lg ${profit >= 0 ? "bg-green-500/10" : "bg-red-500/10"} flex items-center justify-center`}>
              <svg className={`w-4 h-4 ${profit >= 0 ? "text-success" : "text-error"}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            </div>
            <div className={`text-sm font-medium ${profit >= 0 ? "text-success" : "text-error"}`}>{profit >= 0 ? "利益" : "赤字"}</div>
          </div>
          <div className={`text-2xl font-bold ${profit >= 0 ? "text-success" : "text-error"}`}>¥{Math.abs(profit).toLocaleString()}</div>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-gray-200 p-5">
        <h3 className="text-sm font-bold text-foreground mb-4 flex items-center gap-2">
          <svg className="w-4 h-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
          支出を追加
        </h3>
        <div className="flex gap-3">
          <input type="text" value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="項目名" className="input-field flex-1" />
          <input type="number" value={newAmount} onChange={(e) => setNewAmount(e.target.value)} placeholder="金額" className="input-field w-32" min={0} />
          <button onClick={addExpense} className="btn-primary px-5">追加</button>
        </div>
      </div>

      {expenses.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <div className="section-header-navy px-5 py-3">
            <h3 className="text-sm font-bold text-foreground">支出一覧</h3>
          </div>
          <div className="divide-y divide-gray-100">
            {expenses.map((e) => (
              <div key={e.id} className="px-5 py-3.5 flex items-center justify-between hover:bg-gray-50 transition-colors">
                <span className="text-sm text-foreground">{e.name}</span>
                <div className="flex items-center gap-4">
                  <span className="text-sm font-bold text-error">¥{e.amount.toLocaleString()}</span>
                  <button onClick={() => removeExpense(e.id)} className="text-xs text-muted hover:text-error transition-colors">削除</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function SettingsTab({ tournament, tournamentId }: { tournament: Tournament; tournamentId: string }) {
  const [title, setTitle] = useState(tournament.title);
  const [location, setLocation] = useState(tournament.location);
  const [maxTeams, setMaxTeams] = useState(tournament.maxTeams);
  const [courts, setCourts] = useState(tournament.courts);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateDoc(doc(db, "tournaments", tournamentId), { title, location, maxTeams, courts });
      setMessage("保存しました");
      setTimeout(() => setMessage(""), 3000);
    } catch { setMessage("保存に失敗しました"); }
    finally { setSaving(false); }
  };

  return (
    <div className="bg-white rounded-2xl border border-gray-200 p-6 max-w-[600px]">
      <h3 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100 flex items-center gap-2">
        <svg className="w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281" /></svg>
        大会設定を編集
      </h3>
      {message && (
        <div className={`mb-4 p-3 text-sm rounded-xl flex items-center gap-2 ${message === "保存しました" ? "bg-green-50 border border-green-200 text-green-700" : "bg-red-50 border border-red-200 text-red-700"}`}>
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          {message}
        </div>
      )}
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-foreground mb-1.5">大会名</label>
          <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} className="input-field" />
        </div>
        <div>
          <label className="block text-sm font-medium text-foreground mb-1.5">会場</label>
          <input type="text" value={location} onChange={(e) => setLocation(e.target.value)} className="input-field" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">最大チーム数</label>
            <input type="number" value={maxTeams} onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)} className="input-field" />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">コート数</label>
            <input type="number" value={courts} onChange={(e) => setCourts(parseInt(e.target.value) || 0)} className="input-field" />
          </div>
        </div>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? (
            <>
              <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              保存中...
            </>
          ) : "保存"}
        </button>
      </div>
    </div>
  );
}
