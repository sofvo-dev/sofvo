"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Expense } from "@/types/firestore";
import Link from "next/link";

export default function TournamentFinancePage() {
  const params = useParams<{ id: string }>();
  const id = (params?.id ?? "") as string;
  const { user } = useAuth();
  const [tournamentTitle, setTournamentTitle] = useState("");
  const [organizerId, setOrganizerId] = useState("");
  const [entryFee, setEntryFee] = useState(0);
  const [currentTeams, setCurrentTeams] = useState(0);
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [amount, setAmount] = useState(0);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    async function loadTournament() {
      const snap = await getDoc(doc(db, "tournaments", id));
      if (snap.exists()) {
        const d = snap.data();
        setTournamentTitle(d.title ?? "");
        setOrganizerId(d.organizerId ?? "");
        setEntryFee(d.entryFee ?? 0);
        setCurrentTeams(d.currentTeams ?? 0);
      }
    }
    loadTournament();
  }, [id]);

  useEffect(() => {
    const q = query(collection(db, "tournaments", id, "expenses"), orderBy("createdAt", "desc"));
    const unsub = onSnapshot(q, (snap) => {
      setExpenses(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Expense)));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [id]);

  const isOrganizer = user?.uid === organizerId;

  const resetForm = () => {
    setEditingId(null);
    setName("");
    setAmount(0);
    setShowForm(false);
  };

  const startEdit = (ex: Expense) => {
    setEditingId(ex.id);
    setName(ex.name);
    setAmount(ex.amount);
    setShowForm(true);
  };

  const submit = async () => {
    if (!name.trim()) { alert("項目名を入力してください"); return; }
    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        amount: Number(amount) || 0,
        updatedAt: serverTimestamp(),
      };
      if (editingId) {
        await updateDoc(doc(db, "tournaments", id, "expenses", editingId), payload);
      } else {
        await addDoc(collection(db, "tournaments", id, "expenses"), {
          ...payload,
          createdAt: serverTimestamp(),
        });
      }
      resetForm();
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (ex: Expense) => {
    if (!confirm(`「${ex.name}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "tournaments", id, "expenses", ex.id));
  };

  const income = entryFee * currentTeams;
  const totalExpense = expenses.reduce((sum, e) => sum + (e.amount || 0), 0);
  const profit = income - totalExpense;

  if (!isOrganizer) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">主催者のみが収支を確認できます</p>
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
        <span className="text-foreground font-medium">収支管理</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-6">収支管理</h1>

      <div className="grid grid-cols-3 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">参加費収入</div>
          <div className="text-xl font-bold text-success">¥{income.toLocaleString()}</div>
          <div className="text-[10px] text-muted mt-1">¥{entryFee.toLocaleString()} × {currentTeams}チーム</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">支出合計</div>
          <div className="text-xl font-bold text-error">¥{totalExpense.toLocaleString()}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">差引</div>
          <div className={`text-xl font-bold ${profit >= 0 ? "text-primary" : "text-error"}`}>
            ¥{profit.toLocaleString()}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between mb-4">
        <h2 className="text-base font-bold text-foreground">支出項目</h2>
        <button
          onClick={() => (showForm ? resetForm() : setShowForm(true))}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "支出を追加"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 mb-4 shadow-sm">
          <div className="grid grid-cols-[1fr_160px_auto] gap-2 items-end">
            <div>
              <label className="block text-xs text-muted mb-1">項目名</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="例: 会場レンタル"
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
            <div>
              <label className="block text-xs text-muted mb-1">金額</label>
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(Number(e.target.value))}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
              />
            </div>
            <button
              onClick={submit}
              disabled={saving}
              className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark disabled:opacity-50"
            >
              {saving ? "..." : "保存"}
            </button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : expenses.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">支出項目がまだありません</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50/50 border-b border-gray-200">
              <tr>
                <th className="text-left text-xs font-medium text-muted px-5 py-3">項目名</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">金額</th>
                <th className="text-right text-xs font-medium text-muted px-5 py-3">操作</th>
              </tr>
            </thead>
            <tbody>
              {expenses.map((e) => (
                <tr key={e.id} className="border-b border-gray-100 hover:bg-gray-50/50">
                  <td className="px-5 py-3 text-sm text-foreground">{e.name}</td>
                  <td className="px-5 py-3 text-sm text-right font-semibold text-error">¥{e.amount.toLocaleString()}</td>
                  <td className="px-5 py-3 text-right space-x-3">
                    <button onClick={() => startEdit(e)} className="text-xs text-primary hover:underline">編集</button>
                    <button onClick={() => remove(e)} className="text-xs text-error hover:underline">削除</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
