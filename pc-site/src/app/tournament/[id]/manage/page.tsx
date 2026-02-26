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
    return <div className="p-8"><div className="text-center py-20 bg-white rounded-xl border border-gray-200"><div className="text-4xl mb-4">🔒</div><h3 className="text-lg font-bold text-foreground mb-2">管理権限がありません</h3><Link href={`/tournament/${tournamentId}`} className="text-sm text-primary hover:underline">大会詳細に戻る</Link></div></div>;
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
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="flex items-center gap-2 text-sm text-muted mb-4">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors">大会管理</Link>
        <span>/</span>
        <Link href={`/tournament/${tournamentId}`} className="hover:text-primary transition-colors">{tournament.title}</Link>
        <span>/</span>
        <span className="text-foreground">管理パネル</span>
      </div>

      <div className="flex items-center justify-between mb-6">
        <div>
          <div className="flex items-center gap-3 mb-1">
            <h1 className="text-xl font-bold text-foreground">{tournament.title}</h1>
            <StatusBadge status={tournament.status} />
          </div>
          <p className="text-sm text-muted">{tournament.date} - {tournament.location}</p>
        </div>
        <StatusChanger tournamentId={tournamentId} currentStatus={tournament.status} />
      </div>

      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 mb-6 overflow-x-auto">
        {tabs.map((tab) => (
          <button key={tab.key} onClick={() => setActiveTab(tab.key)}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors whitespace-nowrap ${activeTab === tab.key ? "bg-white text-primary shadow-sm" : "text-muted hover:text-foreground"}`}
          >{tab.label}</button>
        ))}
      </div>

      {activeTab === "overview" && <OverviewTab tournament={tournament} entries={entries} checkIns={checkIns} expenses={expenses} />}
      {activeTab === "entries" && <EntriesTab entries={entries} tournamentId={tournamentId} />}
      {activeTab === "scores" && <ScoresTab matches={roundMatches.get(selectedRound) || []} roundIds={roundIds} selectedRound={selectedRound} onSelectRound={setSelectedRound} tournamentId={tournamentId} />}
      {activeTab === "checkin" && <CheckInTab entries={entries} checkIns={checkIns} tournamentId={tournamentId} />}
      {activeTab === "finance" && <FinanceTab tournament={tournament} entries={entries} expenses={expenses} tournamentId={tournamentId} />}
      {activeTab === "settings" && <SettingsTab tournament={tournament} tournamentId={tournamentId} />}
    </div>
  );
}

function StatusChanger({ tournamentId, currentStatus }: { tournamentId: string; currentStatus: string }) {
  const statuses = ["募集中", "準備中", "満員", "開催中", "決勝中", "終了"];
  const [open, setOpen] = useState(false);
  return (
    <div className="relative">
      <button onClick={() => setOpen(!open)} className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:border-primary/30 transition-colors">
        ステータス変更
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-10 min-w-[160px]">
          {statuses.map((s) => (
            <button key={s} onClick={async () => { await updateDoc(doc(db, "tournaments", tournamentId), { status: s }); setOpen(false); }}
              className={`w-full text-left px-4 py-2 text-sm hover:bg-gray-50 ${s === currentStatus ? "text-primary font-bold" : "text-foreground"}`}
            >{s}</button>
          ))}
        </div>
      )}
    </div>
  );
}

function OverviewTab({ tournament: t, entries, checkIns, expenses }: { tournament: Tournament; entries: Entry[]; checkIns: CheckIn[]; expenses: Expense[] }) {
  const revenue = (t.entryFee || 0) * entries.length;
  const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <StatCard label="参加チーム" value={`${entries.length}/${t.maxTeams}`} sub="チーム" color="text-blue-600" />
      <StatCard label="チェックイン" value={`${checkIns.length}/${entries.length}`} sub="完了" color="text-green-600" />
      <StatCard label="収入" value={`¥${revenue.toLocaleString()}`} sub={`${t.entryFee || 0}円 x ${entries.length}チーム`} color="text-primary" />
      <StatCard label="利益" value={`¥${(revenue - totalExpenses).toLocaleString()}`} sub={`支出: ¥${totalExpenses.toLocaleString()}`} color={revenue - totalExpenses >= 0 ? "text-green-600" : "text-red-600"} />
    </div>
  );
}

function StatCard({ label, value, sub, color }: { label: string; value: string; sub: string; color: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5">
      <div className="text-sm text-muted mb-1">{label}</div>
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
      <div className="text-xs text-muted mt-1">{sub}</div>
    </div>
  );
}

function EntriesTab({ entries, tournamentId }: { entries: Entry[]; tournamentId: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-5 py-4 bg-gray-50 border-b border-gray-100 flex items-center justify-between">
        <h3 className="text-sm font-bold text-foreground">エントリー一覧 ({entries.length}チーム)</h3>
      </div>
      {entries.length === 0 ? (
        <div className="text-center py-12 text-muted text-sm">まだエントリーがありません</div>
      ) : (
        <div className="divide-y divide-gray-100">
          {entries.map((e, i) => (
            <div key={e.teamId || i} className="px-5 py-3 flex items-center gap-4">
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
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${selectedRound === rid ? "bg-primary text-white" : "bg-white text-muted border border-gray-200 hover:bg-gray-100"}`}
            >予選{rid.replace("round_", "")}</button>
          ))}
        </div>
      )}
      {matches.length === 0 ? (
        <div className="text-center py-16 text-muted bg-white rounded-xl border border-gray-200">対戦表がまだ生成されていません</div>
      ) : (
        <div className="space-y-3">
          {matches.map((m) => {
            const isEditing = editingMatch === m.id;
            const editSets = scores[m.id]?.sets || m.sets || [];
            return (
              <div key={m.id} className={`bg-white rounded-xl border ${isEditing ? "border-primary" : "border-gray-200"} p-4`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-bold text-muted">{m.courtId?.replace("court_", "").toUpperCase()}コート 第{m.matchOrder}試合</span>
                  <div className="flex items-center gap-2">
                    <span className={`text-xs px-2 py-0.5 rounded ${m.status === "completed" ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"}`}>
                      {m.status === "completed" ? "完了" : "未完了"}
                    </span>
                    {!isEditing ? (
                      <button onClick={() => { setEditingMatch(m.id); if (!scores[m.id]) setScores((prev) => ({ ...prev, [m.id]: { sets: m.sets?.map((s) => ({ ...s })) || [] } })); }}
                        className="text-xs text-primary hover:underline">編集</button>
                    ) : (
                      <button onClick={() => saveScore(m.id)} className="text-xs bg-primary text-white px-3 py-1 rounded hover:bg-primary-dark">保存</button>
                    )}
                  </div>
                </div>
                <div className="grid grid-cols-[1fr_auto_1fr] gap-4 items-center">
                  <span className="text-sm font-bold text-foreground truncate">{m.teamAName}</span>
                  <div className="flex gap-2">
                    {editSets.map((s, si) => (
                      <div key={si} className="text-center">
                        <div className="text-[10px] text-muted mb-1">S{si + 1}</div>
                        {isEditing ? (
                          <div className="flex gap-1">
                            <input type="number" value={s.a} onChange={(e) => handleScoreChange(m.id, si, "a", parseInt(e.target.value) || 0)}
                              className="w-10 text-center border border-gray-300 rounded text-sm py-0.5" min={0} />
                            <span className="text-muted">-</span>
                            <input type="number" value={s.b} onChange={(e) => handleScoreChange(m.id, si, "b", parseInt(e.target.value) || 0)}
                              className="w-10 text-center border border-gray-300 rounded text-sm py-0.5" min={0} />
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
      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-4">
        <div className="flex items-center justify-between mb-2">
          <span className="text-sm font-semibold">チェックイン状況</span>
          <span className="text-sm text-muted">{checkIns.length}/{entries.length} 完了</span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-3">
          <div className="bg-green-500 rounded-full h-3 transition-all" style={{ width: `${progress}%` }} />
        </div>
        {progress === 100 && <div className="text-center mt-3 text-green-600 font-bold text-sm">全チームチェックイン完了!</div>}
      </div>
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="divide-y divide-gray-100">
          {entries.map((e, i) => {
            const checked = checkedTeamIds.has(e.teamId);
            return (
              <div key={e.teamId || i} className="px-5 py-3 flex items-center gap-4">
                <button onClick={() => toggleCheckIn(e)}
                  className={`w-6 h-6 rounded-full border-2 flex items-center justify-center transition-colors ${checked ? "bg-green-500 border-green-500 text-white" : "border-gray-300"}`}
                >
                  {checked && <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>}
                </button>
                <span className={`text-sm font-medium ${checked ? "text-foreground" : "text-muted"}`}>{e.teamName}</span>
                {checked && <span className="text-xs text-green-600 ml-auto">到着</span>}
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
        <div className="bg-blue-50 rounded-xl p-5">
          <div className="text-sm text-blue-600 mb-1">収入</div>
          <div className="text-2xl font-bold text-blue-700">¥{revenue.toLocaleString()}</div>
          <div className="text-xs text-blue-500 mt-1">¥{(tournament.entryFee || 0).toLocaleString()} x {entries.length}チーム</div>
        </div>
        <div className="bg-red-50 rounded-xl p-5">
          <div className="text-sm text-red-600 mb-1">支出</div>
          <div className="text-2xl font-bold text-red-700">¥{totalExpenses.toLocaleString()}</div>
          <div className="text-xs text-red-500 mt-1">{expenses.length}件の支出</div>
        </div>
        <div className={`${profit >= 0 ? "bg-green-50" : "bg-red-50"} rounded-xl p-5`}>
          <div className={`text-sm ${profit >= 0 ? "text-green-600" : "text-red-600"} mb-1`}>{profit >= 0 ? "利益" : "赤字"}</div>
          <div className={`text-2xl font-bold ${profit >= 0 ? "text-green-700" : "text-red-700"}`}>¥{Math.abs(profit).toLocaleString()}</div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <h3 className="text-sm font-bold text-foreground mb-4">支出を追加</h3>
        <div className="flex gap-3">
          <input type="text" value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="項目名" className="input-field flex-1" />
          <input type="number" value={newAmount} onChange={(e) => setNewAmount(e.target.value)} placeholder="金額" className="input-field w-32" min={0} />
          <button onClick={addExpense} className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">追加</button>
        </div>
      </div>

      {expenses.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="px-5 py-3 bg-gray-50 border-b border-gray-100">
            <h3 className="text-sm font-bold text-foreground">支出一覧</h3>
          </div>
          <div className="divide-y divide-gray-100">
            {expenses.map((e) => (
              <div key={e.id} className="px-5 py-3 flex items-center justify-between">
                <span className="text-sm text-foreground">{e.name}</span>
                <div className="flex items-center gap-4">
                  <span className="text-sm font-bold text-red-600">¥{e.amount.toLocaleString()}</span>
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
    <div className="bg-white rounded-xl border border-gray-200 p-6 max-w-[600px]">
      <h3 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100">大会設定を編集</h3>
      {message && <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-lg">{message}</div>}
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
        <button onClick={handleSave} disabled={saving} className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50">
          {saving ? "保存中..." : "保存"}
        </button>
      </div>
    </div>
  );
}
