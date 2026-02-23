"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { collection, addDoc, Timestamp } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";

const prefectures = [
  "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
  "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
  "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
  "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
  "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
  "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
  "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
];

export default function CreateTournamentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const router = useRouter();

  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [location, setLocation] = useState("");
  const [area, setArea] = useState("");
  const [type, setType] = useState("混合");
  const [maxTeams, setMaxTeams] = useState(16);
  const [courts, setCourts] = useState(4);
  const [entryFee, setEntryFee] = useState(0);
  const [deadline, setDeadline] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-8 max-w-[1200px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">大会を作成するにはログインしてください</p>
          <Link
            href="/login"
            className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !date || !location) {
      setError("大会名、開催日、会場は必須です");
      return;
    }

    setSubmitting(true);
    setError("");

    try {
      const docRef = await addDoc(collection(db, "tournaments"), {
        title,
        date,
        location,
        area,
        type,
        maxTeams,
        courts,
        entryFee,
        deadline,
        currentTeams: 0,
        status: "募集中",
        organizerId: user.uid,
        organizerName: profile?.nickname || "",
        createdAt: Timestamp.now(),
        rules: {
          preliminary: { rounds: 1, sets: 3, points: 15, deuce: false },
          scoring: { win20: 3, win11: 2, draw: 1, lose11: 1, lose02: 0 },
          final: { enabled: true, sets: 3, points: 21 },
        },
      });
      router.push(`/tournament/${docRef.id}`);
    } catch (err) {
      setError("大会の作成に失敗しました");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors">大会管理</Link>
        <span>/</span>
        <span className="text-foreground">新規作成</span>
      </div>

      <h1 className="text-2xl font-bold text-foreground mb-6">大会を作成</h1>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        {error && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* 基本情報 */}
          <div>
            <h2 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100">基本情報</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">大会名 *</label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  placeholder="例: 第1回 ソフトバレーボール大会"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">開催日 *</label>
                  <input
                    type="date"
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">申込締切</label>
                  <input
                    type="date"
                    value={deadline}
                    onChange={(e) => setDeadline(e.target.value)}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">会場 *</label>
                <input
                  type="text"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  placeholder="例: 市立体育館"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">エリア</label>
                <select
                  value={area}
                  onChange={(e) => setArea(e.target.value)}
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
                >
                  <option value="">選択してください</option>
                  {prefectures.map((p) => (
                    <option key={p} value={p}>{p}</option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {/* 大会設定 */}
          <div>
            <h2 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100">大会設定</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">種別</label>
                <div className="flex gap-2">
                  {["メンズ", "レディース", "混合"].map((t) => (
                    <button
                      key={t}
                      type="button"
                      onClick={() => setType(t)}
                      className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                        type === t
                          ? "bg-primary text-white"
                          : "bg-gray-100 text-muted hover:bg-gray-200"
                      }`}
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">最大チーム数</label>
                  <input
                    type="number"
                    value={maxTeams}
                    onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)}
                    min={2}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">コート数</label>
                  <input
                    type="number"
                    value={courts}
                    onChange={(e) => setCourts(parseInt(e.target.value) || 0)}
                    min={1}
                    max={8}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">参加費 (円)</label>
                  <input
                    type="number"
                    value={entryFee}
                    onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)}
                    min={0}
                    step={100}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Submit */}
          <div className="flex items-center gap-3 pt-4 border-t border-gray-100">
            <button
              type="submit"
              disabled={submitting}
              className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {submitting ? "作成中..." : "大会を作成する"}
            </button>
            <Link
              href="/tournaments/manage"
              className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors"
            >
              キャンセル
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}
