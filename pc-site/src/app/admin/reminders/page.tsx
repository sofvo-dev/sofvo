"use client";

import { useEffect, useState } from "react";
import { doc, getDoc, setDoc, serverTimestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";

interface ReminderSettings {
  tournamentReminder?: { enabled: boolean; daysBefore: number };
  deadlineReminder?: { enabled: boolean; hoursBefore: number };
  inactiveReminder?: { enabled: boolean; daysAfter: number };
  updatedAt?: unknown;
}

const DEFAULT_SETTINGS: ReminderSettings = {
  tournamentReminder: { enabled: true, daysBefore: 1 },
  deadlineReminder: { enabled: true, hoursBefore: 24 },
  inactiveReminder: { enabled: false, daysAfter: 30 },
};

export default function AdminRemindersPage() {
  const [settings, setSettings] = useState<ReminderSettings>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    async function load() {
      try {
        const snap = await getDoc(doc(db, "config", "reminders"));
        if (snap.exists()) {
          setSettings({ ...DEFAULT_SETTINGS, ...snap.data() });
        }
      } catch {
        // ignore
      }
      setLoading(false);
    }
    load();
  }, []);

  const save = async () => {
    setSaving(true);
    setMessage("");
    try {
      await setDoc(doc(db, "config", "reminders"), {
        ...settings,
        updatedAt: serverTimestamp(),
      });
      setMessage("保存しました");
    } catch {
      setMessage("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[700px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">リマインダー設定</h1>
      <p className="text-sm text-muted mb-6">
        大会参加者・主催者への自動リマインダー送信の設定
      </p>

      {message && (
        <div className={`mb-4 p-3 border text-sm rounded-lg ${message.includes("失敗") ? "bg-red-50 border-red-200 text-error" : "bg-green-50 border-green-200 text-green-700"}`}>
          {message}
        </div>
      )}

      <div className="space-y-4">
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-bold text-foreground">大会開催リマインダー</h2>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={settings.tournamentReminder?.enabled ?? false}
                onChange={(e) => setSettings((s) => ({ ...s, tournamentReminder: { ...s.tournamentReminder!, enabled: e.target.checked } }))}
                className="sr-only peer"
              />
              <div className="w-10 h-5 bg-gray-200 rounded-full peer peer-checked:bg-primary peer-focus:ring-2 peer-focus:ring-primary/20 after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5" />
            </label>
          </div>
          <p className="text-xs text-muted mb-3">参加者に大会開催の前日・当日にリマインダーを送信</p>
          <div className="flex items-center gap-2">
            <label className="text-xs text-muted">開催</label>
            <input
              type="number"
              min={0}
              max={7}
              value={settings.tournamentReminder?.daysBefore ?? 1}
              onChange={(e) => setSettings((s) => ({ ...s, tournamentReminder: { ...s.tournamentReminder!, daysBefore: Number(e.target.value) } }))}
              disabled={!settings.tournamentReminder?.enabled}
              className="w-16 px-2 py-1 border border-gray-300 rounded text-xs text-center disabled:opacity-50"
            />
            <span className="text-xs text-muted">日前</span>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-bold text-foreground">エントリー締切リマインダー</h2>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={settings.deadlineReminder?.enabled ?? false}
                onChange={(e) => setSettings((s) => ({ ...s, deadlineReminder: { ...s.deadlineReminder!, enabled: e.target.checked } }))}
                className="sr-only peer"
              />
              <div className="w-10 h-5 bg-gray-200 rounded-full peer peer-checked:bg-primary peer-focus:ring-2 peer-focus:ring-primary/20 after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5" />
            </label>
          </div>
          <p className="text-xs text-muted mb-3">ブックマークした大会の締切前にリマインダーを送信</p>
          <div className="flex items-center gap-2">
            <label className="text-xs text-muted">締切</label>
            <input
              type="number"
              min={1}
              max={168}
              value={settings.deadlineReminder?.hoursBefore ?? 24}
              onChange={(e) => setSettings((s) => ({ ...s, deadlineReminder: { ...s.deadlineReminder!, hoursBefore: Number(e.target.value) } }))}
              disabled={!settings.deadlineReminder?.enabled}
              className="w-16 px-2 py-1 border border-gray-300 rounded text-xs text-center disabled:opacity-50"
            />
            <span className="text-xs text-muted">時間前</span>
          </div>
        </div>

        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-bold text-foreground">休眠ユーザー呼び戻し</h2>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={settings.inactiveReminder?.enabled ?? false}
                onChange={(e) => setSettings((s) => ({ ...s, inactiveReminder: { ...s.inactiveReminder!, enabled: e.target.checked } }))}
                className="sr-only peer"
              />
              <div className="w-10 h-5 bg-gray-200 rounded-full peer peer-checked:bg-primary peer-focus:ring-2 peer-focus:ring-primary/20 after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-5" />
            </label>
          </div>
          <p className="text-xs text-muted mb-3">一定期間ログインがないユーザーにお知らせを送信</p>
          <div className="flex items-center gap-2">
            <label className="text-xs text-muted">最終ログインから</label>
            <input
              type="number"
              min={7}
              max={365}
              value={settings.inactiveReminder?.daysAfter ?? 30}
              onChange={(e) => setSettings((s) => ({ ...s, inactiveReminder: { ...s.inactiveReminder!, daysAfter: Number(e.target.value) } }))}
              disabled={!settings.inactiveReminder?.enabled}
              className="w-20 px-2 py-1 border border-gray-300 rounded text-xs text-center disabled:opacity-50"
            />
            <span className="text-xs text-muted">日経過</span>
          </div>
        </div>
      </div>

      <div className="flex gap-2 mt-6">
        <button
          onClick={save}
          disabled={saving}
          className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          {saving ? "保存中..." : "設定を保存"}
        </button>
      </div>
    </div>
  );
}
