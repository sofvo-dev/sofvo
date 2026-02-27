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

type Step = "basic" | "rules" | "schedule" | "confirm";

const stepMeta: Record<Step, { icon: React.ReactNode; desc: string }> = {
  basic: {
    icon: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>,
    desc: "大会の基本情報を設定",
  },
  rules: {
    icon: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" /></svg>,
    desc: "予選・決勝のルール設定",
  },
  schedule: {
    icon: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
    desc: "タイムスケジュール設定",
  },
  confirm: {
    icon: <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
    desc: "入力内容を確認して作成",
  },
};

// セット形式に応じた勝ち点のデフォルト値
function defaultScoringForSets(sets: number): Record<string, number> {
  switch (sets) {
    case 1: return { win: 3, lose: 0 };
    case 2: return { win20: 10, win11: 7, draw: 4, lose11: 2, lose02: 0 };
    case 3: return { win20: 5, win21: 3, lose12: 1, lose02: 0 };
    default: return { win20: 10, win11: 7, draw: 4, lose11: 2, lose02: 0 };
  }
}

function scoringLabels(sets: number): { key: string; label: string }[] {
  switch (sets) {
    case 1: return [
      { key: "win", label: "勝利" },
      { key: "lose", label: "敗北" },
    ];
    case 2: return [
      { key: "win20", label: "2-0 勝利" },
      { key: "win11", label: "1-1 得失点差勝ち" },
      { key: "draw", label: "1-1 同点" },
      { key: "lose11", label: "1-1 得失点差負け" },
      { key: "lose02", label: "0-2 敗北" },
    ];
    case 3: return [
      { key: "win20", label: "2-0 勝利" },
      { key: "win21", label: "2-1 勝利" },
      { key: "lose12", label: "1-2 敗北" },
      { key: "lose02", label: "0-2 敗北" },
    ];
    default: return [];
  }
}

export default function CreateTournamentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const router = useRouter();
  const [step, setStep] = useState<Step>("basic");

  // Basic
  const [title, setTitle] = useState("");
  const [date, setDate] = useState("");
  const [location, setLocation] = useState("");
  const [venueAddress, setVenueAddress] = useState("");
  const [area, setArea] = useState("");
  const [type, setType] = useState("混合");
  const [format, setFormat] = useState("");
  const [maxTeams, setMaxTeams] = useState(16);
  const [courts, setCourts] = useState(4);
  const [entryFee, setEntryFee] = useState(0);
  const [deadline, setDeadline] = useState("");
  const [teamsPerCourt, setTeamsPerCourt] = useState(4);

  // Rules - Preliminary
  const [prelRounds, setPrelRounds] = useState(1);
  const [prelSets, setPrelSets] = useState(2);
  const [prelDeuce, setPrelDeuce] = useState(false);
  const [prelDeuceCap, setPrelDeuceCap] = useState(17);

  // Rules - Round 2 (when prelRounds=2)
  const [r2SameAsR1, setR2SameAsR1] = useState(true);
  const [r2Sets, setR2Sets] = useState(2);
  const [r2Deuce, setR2Deuce] = useState(false);
  const [r2DeuceCap, setR2DeuceCap] = useState(17);

  // Rules - Scoring
  const [scoringEnabled, setScoringEnabled] = useState(true);
  const [r1Scoring, setR1Scoring] = useState<Record<string, number>>(defaultScoringForSets(2));
  const [r2Scoring, setR2Scoring] = useState<Record<string, number>>(defaultScoringForSets(2));

  // Rules - Finals
  const [finalEnabled, setFinalEnabled] = useState(true);
  const [finalSets, setFinalSets] = useState(3);
  const [finalDeuce, setFinalDeuce] = useState(true);
  const [finalDeuceCap, setFinalDeuceCap] = useState(17);
  const [finalFormat, setFinalFormat] = useState("順位別複数");
  const [finalTierCount, setFinalTierCount] = useState(3);

  // Rules - Other
  const [uniformRequired, setUniformRequired] = useState(false);
  const [snsVideoAllowed, setSnsVideoAllowed] = useState(true);
  const [lunchBreak, setLunchBreak] = useState("なし");

  // Schedule
  const [openTime, setOpenTime] = useState("");
  const [receptionTime, setReceptionTime] = useState("");
  const [ceremonyTime, setCeremonyTime] = useState("");
  const [matchStartTime, setMatchStartTime] = useState("");
  const [lunchTime, setLunchTime] = useState("");
  const [finalsTime, setFinalsTime] = useState("");
  const [closingTime, setClosingTime] = useState("");

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
        <div className="text-center py-20 bg-white rounded-2xl border border-gray-200">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-100 flex items-center justify-center">
            <svg className="w-8 h-8 text-hint" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <Link href="/login" className="btn-primary mt-4">ログイン</Link>
        </div>
      </div>
    );
  }

  const handleSubmit = async () => {
    if (!title || !date || !location) {
      setError("大会名、開催日、会場は必須です");
      setStep("basic");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      // Build preliminary rules
      const preliminaryRules: Record<string, unknown> = {
        rounds: prelRounds,
        sets: prelSets,
        points: 15,
        deuce: prelDeuce,
        deuceCap: prelDeuceCap,
      };
      if (prelRounds === 2) {
        preliminaryRules.round1 = { sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap };
        preliminaryRules.round2 = r2SameAsR1
          ? { sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap }
          : { sets: r2Sets, points: 15, deuce: r2Deuce, deuceCap: r2DeuceCap };
      }

      // Build scoring rules
      const scoringRules: Record<string, unknown> = { enabled: scoringEnabled, ...r1Scoring };
      if (prelRounds === 2) {
        scoringRules.round1 = { ...r1Scoring };
        scoringRules.round2 = r2SameAsR1 ? { ...r1Scoring } : { ...r2Scoring };
      }

      const docRef = await addDoc(collection(db, "tournaments"), {
        title, date, location, venueAddress, area, type, format, maxTeams, courts, entryFee, deadline,
        currentTeams: 0,
        status: "募集中",
        organizerId: user.uid,
        organizerName: profile?.nickname || "",
        createdAt: Timestamp.now(),
        rules: {
          management: { teamsPerCourt },
          preliminary: preliminaryRules,
          scoring: scoringRules,
          final: { enabled: finalEnabled, sets: finalSets, points: 15, deuce: finalDeuce, deuceCap: finalDeuceCap, format: finalFormat, tierCount: finalTierCount },
          other: { uniformRequired, snsVideoAllowed, lunchBreak },
        },
        schedule: { openTime, receptionTime, ceremonyTime, matchStartTime, lunch: lunchTime, finalsTime, closingTime },
      });
      router.push(`/tournament/${docRef.id}`);
    } catch {
      setError("大会の作成に失敗しました");
    } finally {
      setSubmitting(false);
    }
  };

  const steps: { key: Step; label: string }[] = [
    { key: "basic", label: "基本情報" },
    { key: "rules", label: "ルール設定" },
    { key: "schedule", label: "スケジュール" },
    { key: "confirm", label: "確認" },
  ];

  const stepIndex = steps.findIndex((s) => s.key === step);

  // Helper to update scoring when set format changes
  const handlePrelSetsChange = (newSets: number) => {
    setPrelSets(newSets);
    setR1Scoring(defaultScoringForSets(newSets));
    if (r2SameAsR1) {
      setR2Sets(newSets);
      setR2Scoring(defaultScoringForSets(newSets));
    }
  };

  const handleR2SetsChange = (newSets: number) => {
    setR2Sets(newSets);
    setR2Scoring(defaultScoringForSets(newSets));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto animate-fade-in">
      <div className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors flex items-center gap-1">
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
          大会管理
        </Link>
        <span className="text-hint">/</span>
        <span className="text-foreground font-medium">新規作成</span>
      </div>

      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground mb-1">大会を作成</h1>
        <p className="text-sm text-muted">{stepMeta[step].desc}</p>
      </div>

      {/* Step indicator */}
      <div className="step-indicator mb-8">
        {steps.map((s, i) => (
          <div key={s.key} className="flex items-center" style={{ flex: i < steps.length - 1 ? 1 : "none" }}>
            <button onClick={() => setStep(s.key)} className="flex flex-col items-center gap-1.5 relative">
              <div className={`step-dot ${i === stepIndex ? "active" : i < stepIndex ? "completed" : "pending"}`}>
                {i < stepIndex ? (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}><path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>
                ) : (
                  <span>{i + 1}</span>
                )}
              </div>
              <span className={`text-[11px] font-medium whitespace-nowrap ${i === stepIndex ? "text-primary" : i < stepIndex ? "text-success" : "text-hint"}`}>
                {s.label}
              </span>
            </button>
            {i < steps.length - 1 && (
              <div className={`step-line mx-2 ${i < stepIndex ? "completed" : i === stepIndex ? "active" : ""}`} style={{ marginBottom: 20 }} />
            )}
          </div>
        ))}
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl flex items-center gap-3">
          <svg className="w-5 h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>
          {error}
        </div>
      )}

      {/* Step: Basic */}
      {step === "basic" && (
        <div className="bg-white rounded-2xl border border-gray-200 p-6 space-y-6">
          <Section title="基本情報">
            <Field label="大会名 *">
              <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} className="input-field" placeholder="例: 第1回 ソフトバレーボール大会" />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="開催日 *"><input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="input-field" /></Field>
              <Field label="申込締切"><input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="input-field" /></Field>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <Field label="会場 *"><input type="text" value={location} onChange={(e) => setLocation(e.target.value)} className="input-field" placeholder="例: 市立体育館" /></Field>
              <Field label="住所"><input type="text" value={venueAddress} onChange={(e) => setVenueAddress(e.target.value)} className="input-field" placeholder="例: 東京都..." /></Field>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <Field label="エリア">
                <select value={area} onChange={(e) => setArea(e.target.value)} className="input-field bg-white">
                  <option value="">選択してください</option>
                  {prefectures.map((p) => <option key={p} value={p}>{p}</option>)}
                </select>
              </Field>
              <Field label="大会形式">
                <input type="text" value={format} onChange={(e) => setFormat(e.target.value)} className="input-field" placeholder="例: 予選リーグ+決勝トーナメント" />
              </Field>
            </div>
          </Section>

          <Section title="大会設定">
            <Field label="種別">
              <div className="flex gap-2">
                {["メンズ", "レディース", "混合"].map((t) => (
                  <button key={t} type="button" onClick={() => setType(t)}
                    className={`px-5 py-2.5 rounded-xl text-sm font-medium transition-all ${type === t ? "bg-primary text-white shadow-sm" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                  >{t}</button>
                ))}
              </div>
            </Field>
            <div className="grid grid-cols-4 gap-4">
              <Field label="最大チーム数"><input type="number" value={maxTeams} onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)} min={2} className="input-field" /></Field>
              <Field label="コート数"><input type="number" value={courts} onChange={(e) => setCourts(parseInt(e.target.value) || 0)} min={1} max={8} className="input-field" /></Field>
              <Field label="コートあたりチーム"><input type="number" value={teamsPerCourt} onChange={(e) => setTeamsPerCourt(parseInt(e.target.value) || 0)} min={2} max={8} className="input-field" /></Field>
              <Field label="参加費 (円)"><input type="number" value={entryFee} onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)} min={0} step={100} className="input-field" /></Field>
            </div>
          </Section>

          <div className="flex justify-end pt-4 border-t border-gray-100">
            <button onClick={() => setStep("rules")} className="btn-primary">
              次へ: ルール設定
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" /></svg>
            </button>
          </div>
        </div>
      )}

      {/* Step: Rules */}
      {step === "rules" && (
        <div className="bg-white rounded-2xl border border-gray-200 p-6 space-y-6">
          <Section title="予選ルール">
            <div className="grid grid-cols-2 gap-4">
              <Field label="ラウンド数">
                <div className="flex gap-2">
                  {[1, 2].map((n) => (
                    <button key={n} type="button" onClick={() => setPrelRounds(n)}
                      className={`px-5 py-2.5 rounded-xl text-sm font-medium transition-all ${prelRounds === n ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                    >{n}ラウンド</button>
                  ))}
                </div>
              </Field>
              <Field label="セット形式">
                <div className="flex gap-2">
                  {[1, 2, 3].map((n) => (
                    <button key={n} type="button" onClick={() => handlePrelSetsChange(n)}
                      className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${prelSets === n ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                    >{n === 1 ? "1セット" : n === 2 ? "2セット" : "3セット先取"}</button>
                  ))}
                </div>
              </Field>
            </div>
            <div className="flex items-center gap-6">
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={prelDeuce} onChange={(e) => setPrelDeuce(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm text-foreground">デュースあり</span>
              </label>
              {prelDeuce && (
                <Field label="デュースキャップ"><input type="number" value={prelDeuceCap} onChange={(e) => setPrelDeuceCap(parseInt(e.target.value) || 17)} min={15} max={30} className="input-field w-24" /></Field>
              )}
            </div>

            {/* Round 2 settings */}
            {prelRounds === 2 && (
              <div className="mt-4 p-4 bg-gray-50 rounded-xl space-y-4">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" checked={r2SameAsR1} onChange={(e) => setR2SameAsR1(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                  <span className="text-sm font-medium text-foreground">2回目も同じルール</span>
                </label>
                {!r2SameAsR1 && (
                  <>
                    <Field label="2回目セット形式">
                      <div className="flex gap-2">
                        {[1, 2, 3].map((n) => (
                          <button key={n} type="button" onClick={() => handleR2SetsChange(n)}
                            className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${r2Sets === n ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                          >{n === 1 ? "1セット" : n === 2 ? "2セット" : "3セット先取"}</button>
                        ))}
                      </div>
                    </Field>
                    <div className="flex items-center gap-6">
                      <label className="flex items-center gap-2 cursor-pointer">
                        <input type="checkbox" checked={r2Deuce} onChange={(e) => setR2Deuce(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                        <span className="text-sm text-foreground">デュースあり</span>
                      </label>
                      {r2Deuce && (
                        <Field label="キャップ"><input type="number" value={r2DeuceCap} onChange={(e) => setR2DeuceCap(parseInt(e.target.value) || 17)} className="input-field w-24" /></Field>
                      )}
                    </div>
                  </>
                )}
              </div>
            )}
          </Section>

          <Section title="勝ち点設定">
            <label className="flex items-center gap-2 mb-3 cursor-pointer">
              <input type="checkbox" checked={scoringEnabled} onChange={(e) => setScoringEnabled(e.target.checked)} className="w-4 h-4 text-primary rounded" />
              <span className="text-sm text-foreground font-medium">勝ち点制を使用</span>
            </label>
            {scoringEnabled && (
              <>
                <p className="text-xs text-muted mb-3">ラウンド1 ({prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"})</p>
                <div className="grid grid-cols-5 gap-3">
                  {scoringLabels(prelSets).map(({ key, label }) => (
                    <Field key={key} label={label}>
                      <input type="number" value={r1Scoring[key] ?? 0} onChange={(e) => setR1Scoring({ ...r1Scoring, [key]: parseInt(e.target.value) || 0 })} className="input-field" />
                    </Field>
                  ))}
                </div>
                {prelRounds === 2 && !r2SameAsR1 && (
                  <>
                    <p className="text-xs text-muted mb-3 mt-4">ラウンド2 ({r2Sets === 1 ? "1セット" : r2Sets === 2 ? "2セット" : "3セット先取"})</p>
                    <div className="grid grid-cols-5 gap-3">
                      {scoringLabels(r2Sets).map(({ key, label }) => (
                        <Field key={key} label={label}>
                          <input type="number" value={r2Scoring[key] ?? 0} onChange={(e) => setR2Scoring({ ...r2Scoring, [key]: parseInt(e.target.value) || 0 })} className="input-field" />
                        </Field>
                      ))}
                    </div>
                  </>
                )}
              </>
            )}
          </Section>

          <Section title="決勝ルール">
            <label className="flex items-center gap-2 mb-3 cursor-pointer">
              <input type="checkbox" checked={finalEnabled} onChange={(e) => setFinalEnabled(e.target.checked)} className="w-4 h-4 text-primary rounded" />
              <span className="text-sm text-foreground font-medium">順位決定戦を行う</span>
            </label>
            {finalEnabled && (
              <>
                <div className="grid grid-cols-2 gap-4">
                  <Field label="形式">
                    <div className="flex gap-2">
                      {["順位別複数", "全チーム一本"].map((f) => (
                        <button key={f} type="button" onClick={() => setFinalFormat(f)}
                          className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${finalFormat === f ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                        >{f}</button>
                      ))}
                    </div>
                  </Field>
                  {finalFormat === "順位別複数" && (
                    <Field label="区分数">
                      <div className="flex gap-2">
                        {[2, 3].map((n) => (
                          <button key={n} type="button" onClick={() => setFinalTierCount(n)}
                            className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${finalTierCount === n ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                          >{n === 2 ? "上・中" : "上・中・下"}</button>
                        ))}
                      </div>
                    </Field>
                  )}
                </div>
                <Field label="セット形式">
                  <div className="flex gap-2">
                    {[1, 2, 3].map((n) => (
                      <button key={n} type="button" onClick={() => setFinalSets(n)}
                        className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${finalSets === n ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                      >{n === 1 ? "1セット" : n === 2 ? "2セット" : "3セット先取"}</button>
                    ))}
                  </div>
                </Field>
                <div className="flex items-center gap-6 flex-wrap">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" checked={finalDeuce} onChange={(e) => setFinalDeuce(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                    <span className="text-sm">デュースあり</span>
                  </label>
                  {finalDeuce && (
                    <Field label="キャップ"><input type="number" value={finalDeuceCap} onChange={(e) => setFinalDeuceCap(parseInt(e.target.value) || 17)} className="input-field w-24" /></Field>
                  )}
                </div>
              </>
            )}
          </Section>

          <Section title="その他">
            <div className="flex flex-wrap gap-6">
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={uniformRequired} onChange={(e) => setUniformRequired(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">ユニフォーム必須</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={snsVideoAllowed} onChange={(e) => setSnsVideoAllowed(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">SNS・動画撮影OK</span>
              </label>
            </div>
            <Field label="昼休憩">
              <div className="flex gap-2">
                {["なし", "30分", "45分", "60分"].map((opt) => (
                  <button key={opt} type="button" onClick={() => setLunchBreak(opt)}
                    className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${lunchBreak === opt ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
                  >{opt}</button>
                ))}
              </div>
            </Field>
          </Section>

          <div className="flex justify-between pt-4 border-t border-gray-100">
            <button onClick={() => setStep("basic")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
              戻る
            </button>
            <button onClick={() => setStep("schedule")} className="btn-primary">
              次へ: スケジュール
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" /></svg>
            </button>
          </div>
        </div>
      )}

      {/* Step: Schedule */}
      {step === "schedule" && (
        <div className="bg-white rounded-2xl border border-gray-200 p-6 space-y-6">
          <Section title="タイムスケジュール">
            <p className="text-sm text-muted mb-4 p-3 bg-blue-50 rounded-xl border border-blue-100">
              時間は任意です。設定した項目が大会情報に表示されます。
            </p>
            <div className="grid grid-cols-2 gap-4">
              <Field label="開場"><input type="time" value={openTime} onChange={(e) => setOpenTime(e.target.value)} className="input-field" /></Field>
              <Field label="受付"><input type="time" value={receptionTime} onChange={(e) => setReceptionTime(e.target.value)} className="input-field" /></Field>
              <Field label="開会式"><input type="time" value={ceremonyTime} onChange={(e) => setCeremonyTime(e.target.value)} className="input-field" /></Field>
              <Field label="試合開始"><input type="time" value={matchStartTime} onChange={(e) => setMatchStartTime(e.target.value)} className="input-field" /></Field>
              {lunchBreak !== "なし" && (
                <Field label="昼休憩"><input type="time" value={lunchTime} onChange={(e) => setLunchTime(e.target.value)} className="input-field" /></Field>
              )}
              {finalEnabled && (
                <Field label="決勝"><input type="time" value={finalsTime} onChange={(e) => setFinalsTime(e.target.value)} className="input-field" /></Field>
              )}
              <Field label="閉会"><input type="time" value={closingTime} onChange={(e) => setClosingTime(e.target.value)} className="input-field" /></Field>
            </div>
          </Section>

          <div className="flex justify-between pt-4 border-t border-gray-100">
            <button onClick={() => setStep("rules")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
              戻る
            </button>
            <button onClick={() => setStep("confirm")} className="btn-primary">
              次へ: 確認
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" /></svg>
            </button>
          </div>
        </div>
      )}

      {/* Step: Confirm */}
      {step === "confirm" && (
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-gray-200 p-6 space-y-6">
            <Section title="基本情報">
              <div className="grid grid-cols-2 gap-y-3 text-sm">
                <ConfirmRow label="大会名" value={title || "未設定"} />
                <ConfirmRow label="開催日" value={date || "未設定"} />
                <ConfirmRow label="会場" value={location || "未設定"} />
                <ConfirmRow label="エリア" value={area || "未設定"} />
                <ConfirmRow label="種別" value={type} />
                <ConfirmRow label="形式" value={format || "未設定"} />
                <ConfirmRow label="最大チーム" value={`${maxTeams}チーム`} />
                <ConfirmRow label="コート" value={`${courts}コート (${teamsPerCourt}チーム/コート)`} />
                <ConfirmRow label="参加費" value={entryFee > 0 ? `¥${entryFee.toLocaleString()}` : "無料"} />
                <ConfirmRow label="申込締切" value={deadline || "未設定"} />
              </div>
            </Section>

            <Section title="予選ルール">
              <div className="grid grid-cols-2 gap-y-3 text-sm">
                <ConfirmRow label="ラウンド" value={`${prelRounds}ラウンド`} />
                <ConfirmRow label="セット形式" value={prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"} />
                <ConfirmRow label="デュース" value={prelDeuce ? `あり (${prelDeuceCap}点キャップ)` : "なし"} />
              </div>
            </Section>

            {scoringEnabled && (
              <Section title="勝ち点">
                <div className="flex gap-3 flex-wrap">
                  {scoringLabels(prelSets).map(({ key, label }) => (
                    <span key={key} className="px-3 py-1.5 bg-gray-50 text-gray-700 rounded-lg text-sm font-medium border border-gray-200">
                      {label}: {r1Scoring[key] ?? 0}pt
                    </span>
                  ))}
                </div>
              </Section>
            )}

            {finalEnabled && (
              <Section title="決勝">
                <div className="grid grid-cols-2 gap-y-3 text-sm">
                  <ConfirmRow label="形式" value={finalFormat} />
                  {finalFormat === "順位別複数" && <ConfirmRow label="区分" value={finalTierCount === 2 ? "上・中" : "上・中・下"} />}
                  <ConfirmRow label="セット" value={finalSets === 1 ? "1セット" : finalSets === 2 ? "2セット" : "3セット先取"} />
                  <ConfirmRow label="デュース" value={finalDeuce ? `あり (${finalDeuceCap}点キャップ)` : "なし"} />
                </div>
              </Section>
            )}

            <Section title="その他">
              <div className="grid grid-cols-2 gap-y-3 text-sm">
                <ConfirmRow label="ユニフォーム" value={uniformRequired ? "必須" : "任意"} />
                <ConfirmRow label="SNS・動画" value={snsVideoAllowed ? "OK" : "NG"} />
                <ConfirmRow label="昼休憩" value={lunchBreak} />
              </div>
            </Section>
          </div>

          <div className="flex justify-between pt-2">
            <button onClick={() => setStep("schedule")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" /></svg>
              戻る
            </button>
            <button onClick={handleSubmit} disabled={submitting} className="btn-accent px-8">
              {submitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  作成中...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
                  大会を作成する
                </>
              )}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100">{title}</h2>
      <div className="space-y-4">{children}</div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-1.5">{label}</label>
      {children}
    </div>
  );
}

function ConfirmRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline gap-2">
      <span className="text-muted w-28 flex-shrink-0">{label}</span>
      <span className="font-medium text-foreground">{value}</span>
    </div>
  );
}
