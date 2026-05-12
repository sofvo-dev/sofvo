"use client";

import { useEffect, useState, useRef } from "react";
import { useParams } from "next/navigation";
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

/** court_1 → "A", court_2 → "B", ... */
function getCourtLabel(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return courtId;
  return String.fromCharCode(64 + num);
}

const courtColorList = ["#1B3A5C", "#D32F2F", "#2E7D32", "#7B1FA2", "#E65100", "#0277BD", "#4E342E", "#00695C"];
function getCourtColor(courtId: string): string {
  const num = parseInt(courtId.replace(/\D/g, ""), 10);
  if (isNaN(num) || num < 1) return "#1B3A5C";
  return courtColorList[(num - 1) % courtColorList.length];
}

export default function TournamentManagePage() {
  const params = useParams<{ id: string }>();
  const tournamentId = (params?.id ?? "") as string;
  const { user, loading: authLoading } = useAuth();
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
      if (ids.length > 0) setSelectedRound((prev) => prev || ids[ids.length - 1]);
    }
    loadRounds();
  }, [tournamentId]);

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

  if (loading || authLoading) return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
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

      {/* Header */}
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

/* ==============================
   Status Changer
   ============================== */
function StatusChanger({ tournamentId, currentStatus }: { tournamentId: string; currentStatus: string }) {
  const statuses = ["募集中", "準備中", "満員", "エントリー締切", "試合準備中", "開催中", "決勝中", "終了"];
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

/* ==============================
   Overview Tab
   ============================== */
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

/* ==============================
   Entries Tab (with CSV Import)
   ============================== */
function EntriesTab({ entries, tournamentId }: { entries: Entry[]; tournamentId: string }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [csvPreview, setCsvPreview] = useState<{ teamName: string; members: string[] }[] | null>(null);
  const [importing, setImporting] = useState(false);
  const [csvMsg, setCsvMsg] = useState("");

  const handleCsvFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      const text = ev.target?.result as string;
      if (!text) return;
      const lines = text.split("\n").map((l) => l.trim()).filter(Boolean);
      if (lines.length === 0) { setCsvMsg("CSVファイルが空です"); return; }
      // Skip header if it looks like one
      let startIdx = 0;
      const first = lines[0].toLowerCase();
      if (first.includes("チーム") || first.includes("team") || first.includes("名前")) startIdx = 1;
      const teams: { teamName: string; members: string[] }[] = [];
      for (let i = startIdx; i < lines.length; i++) {
        const cols = lines[i].split(",").map((c) => c.trim().replace(/^["']|["']$/g, ""));
        if (!cols[0]) continue;
        teams.push({ teamName: cols[0], members: cols.slice(1).filter(Boolean) });
      }
      if (teams.length === 0) { setCsvMsg("有効なチームデータがありません"); return; }
      setCsvPreview(teams);
      setCsvMsg("");
    };
    reader.readAsText(file, "UTF-8");
    e.target.value = "";
  };

  const importCsv = async () => {
    if (!csvPreview) return;
    setImporting(true);
    try {
      const batch = writeBatch(db);
      for (const team of csvPreview) {
        const entryRef = doc(collection(db, "tournaments", tournamentId, "entries"));
        const memberNames: Record<string, string> = {};
        team.members.forEach((m, i) => { memberNames[`p${i + 1}`] = m; });
        batch.set(entryRef, {
          teamId: entryRef.id,
          teamName: team.teamName,
          leaderName: team.members[0] || "",
          memberCount: team.members.length,
          memberNames,
          enteredBy: "csv_import",
          createdAt: Timestamp.now(),
        });
      }
      await batch.commit();
      setCsvPreview(null);
      setCsvMsg(`${csvPreview.length}チームをインポートしました`);
      setTimeout(() => setCsvMsg(""), 4000);
    } catch (e) {
      console.error("CSV import failed:", e);
      setCsvMsg("インポートに失敗しました");
    }
    setImporting(false);
  };

  return (
    <div className="space-y-4">
      {/* CSV Import Section */}
      <div className="card-accent-left p-5">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-bold text-foreground flex items-center gap-2">
              <svg className="w-4 h-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
              CSV一括登録
            </h3>
            <p className="text-xs text-muted mt-1">CSVフォーマット: チーム名, 選手1, 選手2, ...</p>
          </div>
          <div className="flex gap-2">
            <input ref={fileRef} type="file" accept=".csv" onChange={handleCsvFile} className="hidden" />
            <button onClick={() => fileRef.current?.click()} className="btn-secondary text-xs px-4 py-2">
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m6.75 12l-3-3m0 0l-3 3m3-3v6m-1.5-15H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" /></svg>
              CSVファイルを選択
            </button>
          </div>
        </div>
        {csvMsg && (
          <div className={`mt-3 text-sm font-medium ${csvMsg.includes("失敗") || csvMsg.includes("空") || csvMsg.includes("有効") ? "text-error" : "text-success"}`}>{csvMsg}</div>
        )}
      </div>

      {/* CSV Preview Modal */}
      {csvPreview && (
        <div className="bg-white rounded-2xl border-2 border-accent p-5 animate-scale-in">
          <div className="flex items-center justify-between mb-4">
            <h3 className="section-title text-sm">インポート確認 ({csvPreview.length}チーム)</h3>
            <div className="flex gap-2">
              <button onClick={() => setCsvPreview(null)} className="btn-secondary text-xs px-4 py-2">キャンセル</button>
              <button onClick={importCsv} disabled={importing} className="btn-accent text-xs px-4 py-2">
                {importing ? <><div className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" /> インポート中...</> : "インポート実行"}
              </button>
            </div>
          </div>
          <div className="max-h-60 overflow-y-auto rounded-xl border border-gray-200">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 sticky top-0">
                <tr><th className="px-4 py-2 text-left text-xs font-bold text-muted">チーム名</th><th className="px-4 py-2 text-left text-xs font-bold text-muted">メンバー</th></tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {csvPreview.map((t, i) => (
                  <tr key={i} className="hover:bg-gray-50"><td className="px-4 py-2.5 font-medium">{t.teamName}</td><td className="px-4 py-2.5 text-muted">{t.members.join(", ") || "-"}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Entry List */}
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
    </div>
  );
}

/* ==============================
   Scores Tab - Court-based table with inline editing
   ============================== */
function ScoresTab({ matches, roundIds, selectedRound, onSelectRound, tournamentId }: {
  matches: Match[]; roundIds: string[]; selectedRound: string; onSelectRound: (id: string) => void; tournamentId: string;
}) {
  const [editScores, setEditScores] = useState<Record<string, { a: number; b: number }[]>>({});
  const [saving, setSaving] = useState<string | null>(null);

  // Group matches by court
  const courtGroups = new Map<string, Match[]>();
  for (const m of matches) {
    const cid = m.courtId || "unknown";
    if (!courtGroups.has(cid)) courtGroups.set(cid, []);
    courtGroups.get(cid)!.push(m);
  }
  const sortedCourts = Array.from(courtGroups.entries()).sort(([a], [b]) => a.localeCompare(b));

  const getEditSets = (m: Match) => editScores[m.id] || m.sets || [];

  const handleChange = (matchId: string, setIdx: number, team: "a" | "b", val: number, originalSets: { a: number; b: number }[]) => {
    setEditScores((prev) => {
      const current = prev[matchId] || originalSets.map((s) => ({ ...s }));
      const sets = [...current];
      if (!sets[setIdx]) sets[setIdx] = { a: 0, b: 0 };
      sets[setIdx] = { ...sets[setIdx], [team]: val };
      return { ...prev, [matchId]: sets };
    });
  };

  const saveMatch = async (matchId: string) => {
    const sets = editScores[matchId];
    if (!sets) return;
    setSaving(matchId);
    try {
      const matchRef = doc(db, "tournaments", tournamentId, "rounds", selectedRound, "matches", matchId);
      await updateDoc(matchRef, { sets });
      setEditScores((prev) => { const next = { ...prev }; delete next[matchId]; return next; });
    } catch (e) { console.error("Save failed:", e); }
    setSaving(null);
  };

  const saveAll = async () => {
    const ids = Object.keys(editScores);
    if (ids.length === 0) return;
    setSaving("all");
    try {
      const batch = writeBatch(db);
      for (const matchId of ids) {
        const matchRef = doc(db, "tournaments", tournamentId, "rounds", selectedRound, "matches", matchId);
        batch.update(matchRef, { sets: editScores[matchId] });
      }
      await batch.commit();
      setEditScores({});
    } catch (e) { console.error("Batch save failed:", e); }
    setSaving(null);
  };

  const hasChanges = Object.keys(editScores).length > 0;

  return (
    <div className="space-y-4">
      {/* Round selector + Save all */}
      <div className="flex items-center justify-between">
        {roundIds.length > 0 && (
          <div className="flex gap-2">
            {roundIds.map((rid) => (
              <button key={rid} onClick={() => onSelectRound(rid)}
                className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${selectedRound === rid ? "bg-primary text-white shadow-sm" : "bg-white text-muted border border-gray-200 hover:bg-gray-100"}`}
              >予選{rid.replace("round_", "")}</button>
            ))}
          </div>
        )}
        {hasChanges && (
          <button onClick={saveAll} disabled={saving === "all"} className="btn-accent text-sm px-5 py-2">
            {saving === "all" ? <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> 保存中...</> : (
              <><svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg> すべて保存 ({Object.keys(editScores).length}件)</>
            )}
          </button>
        )}
      </div>

      {matches.length === 0 ? (
        <div className="text-center py-16 text-muted bg-white rounded-2xl border border-gray-200">
          <div className="w-12 h-12 mx-auto mb-3 rounded-xl bg-gray-100 flex items-center justify-center">
            <svg className="w-6 h-6 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          対戦表がまだ生成されていません
        </div>
      ) : (
        <div className="space-y-4">
          {sortedCourts.map(([courtId, courtMatches]) => {
            const label = getCourtLabel(courtId);
            const color = getCourtColor(courtId);
            return (
              <div key={courtId} className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
                {/* Court header */}
                <div className="px-4 py-2 flex items-center gap-2 border-b border-gray-100" style={{ background: `linear-gradient(135deg, ${color}08, ${color}02)` }}>
                  <span className="w-6 h-6 rounded text-white text-[10px] font-bold flex items-center justify-center" style={{ background: color }}>{label}</span>
                  <span className="text-sm font-bold text-foreground">{label}コート</span>
                  <span className="text-xs text-muted">{courtMatches.length}試合</span>
                </div>
                {/* Compact score table */}
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-[10px] text-muted border-b border-gray-100 bg-gray-50/50">
                      <th className="px-3 py-1.5 text-center w-8">#</th>
                      <th className="py-1.5 text-right pr-2">チームA</th>
                      <th className="py-1.5 text-center" colSpan={2}>スコア</th>
                      <th className="py-1.5 text-left pl-2">チームB</th>
                      <th className="px-3 py-1.5 text-center w-14"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {courtMatches.sort((a, b) => (a.matchOrder ?? 0) - (b.matchOrder ?? 0)).map((m) => {
                      const sets = getEditSets(m);
                      const isEdited = !!editScores[m.id];
                      const isSaving = saving === m.id;
                      return (
                        <tr key={m.id} className={`border-b border-gray-50 ${isEdited ? "bg-amber-50/40" : "hover:bg-gray-50/50"}`}>
                          <td className="px-3 py-2 text-center text-xs text-muted">{m.matchOrder}</td>
                          <td className="py-2 text-right pr-2 font-semibold text-foreground truncate max-w-[120px]">{m.teamAName}</td>
                          <td className="py-2 text-center" colSpan={2}>
                            <div className="flex items-center justify-center gap-1">
                              {sets.map((s, si) => (
                                <div key={si} className="flex items-center gap-0.5">
                                  {si > 0 && <span className="text-gray-300 mx-0.5">|</span>}
                                  <input type="number" value={s.a} min={0} max={99}
                                    onChange={(e) => handleChange(m.id, si, "a", parseInt(e.target.value) || 0, m.sets || [])}
                                    className={`w-11 h-7 text-center text-sm font-bold rounded border focus:border-primary focus:ring-1 focus:ring-primary/20 ${s.a > s.b ? "border-[#1B3A5C]/40 bg-[#1B3A5C]/5 text-[#1B3A5C]" : "border-gray-200 bg-white"}`} />
                                  <span className="text-[10px] text-gray-300">-</span>
                                  <input type="number" value={s.b} min={0} max={99}
                                    onChange={(e) => handleChange(m.id, si, "b", parseInt(e.target.value) || 0, m.sets || [])}
                                    className={`w-11 h-7 text-center text-sm font-bold rounded border focus:border-primary focus:ring-1 focus:ring-primary/20 ${s.b > s.a ? "border-[#D32F2F]/40 bg-[#D32F2F]/5 text-[#D32F2F]" : "border-gray-200 bg-white"}`} />
                                </div>
                              ))}
                            </div>
                          </td>
                          <td className="py-2 text-left pl-2 font-semibold text-foreground truncate max-w-[120px]">{m.teamBName}</td>
                          <td className="px-2 py-2 text-center">
                            {isEdited ? (
                              <button onClick={() => saveMatch(m.id)} disabled={!!isSaving} className="text-[10px] text-white bg-primary px-2 py-1 rounded hover:bg-primary-dark transition-colors font-medium">
                                {isSaving ? "..." : "保存"}
                              </button>
                            ) : (
                              <span className={`text-[10px] font-medium ${m.status === "completed" ? "text-green-600" : "text-gray-400"}`}>
                                {m.status === "completed" ? "完了" : "—"}
                              </span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

/* ==============================
   CheckIn Tab
   ============================== */
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

/* ==============================
   Finance Tab
   ============================== */
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

/* ==============================
   Settings Tab
   ============================== */
/** Convert "2025/3/8" or "2025-3-8" to "2025-03-08" for input[type=date] */
function toDateInputValue(dateStr: string): string {
  if (!dateStr) return "";
  // Try parsing as-is (already YYYY-MM-DD)
  const isoMatch = dateStr.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (isoMatch) {
    return `${isoMatch[1]}-${isoMatch[2].padStart(2, "0")}-${isoMatch[3].padStart(2, "0")}`;
  }
  // Parse "YYYY/M/D" format
  const jpMatch = dateStr.match(/^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$/);
  if (jpMatch) {
    return `${jpMatch[1]}-${jpMatch[2].padStart(2, "0")}-${jpMatch[3].padStart(2, "0")}`;
  }
  return dateStr;
}

/** Convert "2025-03-08" back to "2025/3/8" for Firestore */
function toFirestoreDateStr(dateInput: string): string {
  if (!dateInput) return "";
  const parts = dateInput.split("-");
  if (parts.length !== 3) return dateInput;
  return `${parseInt(parts[0])}/${parseInt(parts[1])}/${parseInt(parts[2])}`;
}

function SettingsTab({ tournament, tournamentId }: { tournament: Tournament; tournamentId: string }) {
  const [title, setTitle] = useState(tournament.title);
  const [date, setDate] = useState(toDateInputValue(tournament.date || ""));
  const [location, setLocation] = useState(tournament.location);
  const [venueAddress, setVenueAddress] = useState(tournament.venueAddress || "");
  const [area, setArea] = useState(tournament.area || "");
  const [maxTeams, setMaxTeams] = useState(tournament.maxTeams);
  const [courts, setCourts] = useState(tournament.courts);
  const [entryFee, setEntryFee] = useState(tournament.entryFee || 0);
  const [type, setType] = useState(tournament.type || "");
  const [deadline, setDeadline] = useState(toDateInputValue(tournament.deadline || ""));
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  const prefectures = [
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
    "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
    "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
    "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
  ];

  const handleSave = async () => {
    setSaving(true);
    try {
      await updateDoc(doc(db, "tournaments", tournamentId), {
        title, date: toFirestoreDateStr(date), location, venueAddress, area, maxTeams, courts, entryFee, type, deadline: toFirestoreDateStr(deadline),
      });
      setMessage("保存しました");
      setTimeout(() => setMessage(""), 3000);
    } catch (e) {
      console.error("Save failed:", e);
      setMessage("保存に失敗しました");
    }
    finally { setSaving(false); }
  };

  return (
    <div className="bg-white rounded-2xl border border-gray-200 p-6 max-w-[700px]">
      <h3 className="section-title text-sm mb-4 pb-3 border-b border-gray-100">大会設定を編集</h3>
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
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">開催日</label>
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="input-field" />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">エントリー締切</label>
            <input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="input-field" />
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-foreground mb-1.5">会場名</label>
          <input type="text" value={location} onChange={(e) => setLocation(e.target.value)} className="input-field" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">住所</label>
            <input type="text" value={venueAddress} onChange={(e) => setVenueAddress(e.target.value)} className="input-field" placeholder="会場の住所" />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">エリア</label>
            <select value={area} onChange={(e) => setArea(e.target.value)} className="input-field bg-white">
              <option value="">都道府県を選択</option>
              {prefectures.map((p) => <option key={p} value={p}>{p}</option>)}
            </select>
          </div>
        </div>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">最大チーム数</label>
            <input type="number" value={maxTeams} onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)} className="input-field" min={1} />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">コート数</label>
            <input type="number" value={courts} onChange={(e) => setCourts(parseInt(e.target.value) || 0)} className="input-field" min={1} />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">参加費 (円)</label>
            <input type="number" value={entryFee} onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)} className="input-field" min={0} />
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-foreground mb-1.5">大会種別</label>
          <select value={type} onChange={(e) => setType(e.target.value)} className="input-field bg-white">
            <option value="">選択してください</option>
            <option value="メンズ">メンズ</option>
            <option value="レディース">レディース</option>
            <option value="混合">混合</option>
            <option value="ミックス">ミックス</option>
          </select>
        </div>
        <button onClick={handleSave} disabled={saving} className="btn-primary">
          {saving ? (
            <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> 保存中...</>
          ) : "変更を保存"}
        </button>
      </div>
    </div>
  );
}
