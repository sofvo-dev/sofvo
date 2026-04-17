"use client";

import { useState } from "react";

const FUNCTIONS_BASE = "https://us-central1-sofvo-19d84.cloudfunctions.net";

const targets: { key: string; label: string; desc: string }[] = [
  { key: "all", label: "全ユーザー", desc: "登録済みのすべてのユーザー" },
  { key: "active", label: "アクティブ", desc: "直近30日以内に利用したユーザー" },
  { key: "beginner", label: "初心者", desc: "経験「1年未満」のユーザー" },
  { key: "dormant", label: "休眠", desc: "30日以上利用がないユーザー" },
];

export default function BroadcastPage() {
  const [target, setTarget] = useState("all");
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const send = async () => {
    if (!message.trim()) {
      setError("メッセージを入力してください");
      return;
    }
    if (!confirm(`${targets.find((t) => t.key === target)?.label} にメッセージを送信しますか？\n\n「${message}」`)) {
      return;
    }
    setSending(true);
    setError(null);
    setResult(null);
    try {
      const res = await fetch(`${FUNCTIONS_BASE}/broadcastChatMessage`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: message.trim(), target }),
      });
      if (!res.ok) throw new Error("failed");
      const data = await res.json();
      setResult(`${data.sentCount ?? 0}人にメッセージを送信しました`);
      setMessage("");
    } catch {
      setError("送信に失敗しました。Cloud Functions の設定と権限を確認してください。");
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="p-8 max-w-[700px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">ブロードキャスト送信</h1>
      <p className="text-sm text-muted mb-6">
        公式アカウントから対象ユーザーへ一斉にメッセージを配信します
      </p>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
          {error}
        </div>
      )}
      {result && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-lg">
          {result}
        </div>
      )}

      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-4">
        <h2 className="text-sm font-bold text-foreground mb-3">送信対象</h2>
        <div className="space-y-2">
          {targets.map((t) => (
            <label
              key={t.key}
              className={`flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-colors ${
                target === t.key ? "border-primary bg-primary/5" : "border-gray-200 hover:border-gray-300"
              }`}
            >
              <input
                type="radio"
                name="target"
                value={t.key}
                checked={target === t.key}
                onChange={() => setTarget(t.key)}
                className="mt-0.5"
              />
              <div>
                <div className="text-sm font-semibold text-foreground">{t.label}</div>
                <div className="text-xs text-muted mt-0.5">{t.desc}</div>
              </div>
            </label>
          ))}
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-4">
        <h2 className="text-sm font-bold text-foreground mb-3">メッセージ内容</h2>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={6}
          maxLength={500}
          placeholder="送信するメッセージを入力..."
          className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
        />
        <div className="text-xs text-muted mt-1 text-right">{message.length}/500</div>
      </div>

      <div className="flex gap-3">
        <button
          onClick={send}
          disabled={sending || !message.trim()}
          className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          {sending ? "送信中..." : "メッセージを送信"}
        </button>
        <button
          onClick={() => setMessage("")}
          className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
        >
          クリア
        </button>
      </div>
    </div>
  );
}
