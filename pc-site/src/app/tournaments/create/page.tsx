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
  const [prelSets, setPrelSets] = useState(3);
  const [prelPoints, setPrelPoints] = useState(15);
  const [prelDeuce, setPrelDeuce] = useState(false);
  const [prelDeuceCap, setPrelDeuceCap] = useState(17);

  // Rules - Scoring
  const [scoringEnabled, setScoringEnabled] = useState(true);
  const [win20, setWin20] = useState(3);
  const [win11, setWin11] = useState(2);
  const [draw, setDraw] = useState(1);
  const [lose11, setLose11] = useState(1);
  const [lose02, setLose02] = useState(0);

  // Rules - Finals
  const [finalEnabled, setFinalEnabled] = useState(true);
  const [finalSets, setFinalSets] = useState(3);
  const [finalPoints, setFinalPoints] = useState(21);
  const [finalDeuce, setFinalDeuce] = useState(true);
  const [finalDeuceCap, setFinalDeuceCap] = useState(25);
  const [finalFormat, setFinalFormat] = useState("トーナメント");
  const [thirdPlace, setThirdPlace] = useState(true);
  const [loserRevival, setLoserRevival] = useState(false);

  // Rules - Other
  const [uniformRequired, setUniformRequired] = useState(false);
  const [snsVideoAllowed, setSnsVideoAllowed] = useState(true);
  const [lunchBreak, setLunchBreak] = useState(false);

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
      const docRef = await addDoc(collection(db, "tournaments"), {
        title, date, location, venueAddress, area, type, format, maxTeams, courts, entryFee, deadline,
        currentTeams: 0,
        status: "募集中",
        organizerId: user.uid,
        organizerName: profile?.nickname || "",
        createdAt: Timestamp.now(),
        rules: {
          management: { teamsPerCourt },
          preliminary: { rounds: prelRounds, sets: prelSets, points: prelPoints, deuce: prelDeuce, deuceCap: prelDeuceCap },
          scoring: { enabled: scoringEnabled, win20, win11, draw, lose11, lose02 },
          final: { enabled: finalEnabled, sets: finalSets, points: finalPoints, deuce: finalDeuce, deuceCap: finalDeuceCap, format: finalFormat, thirdPlace, loserRevival },
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

      {/* Header */}
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground mb-1">大会を作成</h1>
        <p className="text-sm text-muted">{stepMeta[step].desc}</p>
      </div>

      {/* Step indicator - connected dots with lines */}
      <div className="step-indicator mb-8">
        {steps.map((s, i) => (
          <div key={s.key} className="flex items-center" style={{ flex: i < steps.length - 1 ? 1 : "none" }}>
            <button
              onClick={() => setStep(s.key)}
              className="flex flex-col items-center gap-1.5 relative"
            >
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
          <Section title="基本情報" icon={<svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>}>
            <Field label="大会名 *">
              <input type="text" value={title} onChange={(e) => setTitle(e.target.value)} className="input-field" placeholder="例: 第1回 ソフトバレーボール大会" required />
            </Field>
            <div className="grid grid-cols-2 gap-4">
              <Field label="開催日 *"><input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="input-field" required /></Field>
              <Field label="申込締切"><input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="input-field" /></Field>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <Field label="会場 *"><input type="text" value={location} onChange={(e) => setLocation(e.target.value)} className="input-field" placeholder="例: 市立体育館" required /></Field>
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

          <Section title="大会設定" icon={<svg className="w-4 h-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" /></svg>}>
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
          <Section title="予選ルール" icon={<svg className="w-4 h-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z" /></svg>}>
            <div className="grid grid-cols-3 gap-4">
              <Field label="ラウンド数"><input type="number" value={prelRounds} onChange={(e) => setPrelRounds(parseInt(e.target.value) || 1)} min={1} max={5} className="input-field" /></Field>
              <Field label="セット数"><input type="number" value={prelSets} onChange={(e) => setPrelSets(parseInt(e.target.value) || 1)} min={1} max={5} className="input-field" /></Field>
              <Field label="ポイント数"><input type="number" value={prelPoints} onChange={(e) => setPrelPoints(parseInt(e.target.value) || 1)} min={1} max={30} className="input-field" /></Field>
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
          </Section>

          <Section title="勝ち点設定" icon={<svg className="w-4 h-4 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>}>
            <label className="flex items-center gap-2 mb-3 cursor-pointer">
              <input type="checkbox" checked={scoringEnabled} onChange={(e) => setScoringEnabled(e.target.checked)} className="w-4 h-4 text-primary rounded" />
              <span className="text-sm text-foreground font-medium">勝ち点制を使用</span>
            </label>
            {scoringEnabled && (
              <div className="grid grid-cols-5 gap-3">
                <Field label="2-0勝ち"><input type="number" value={win20} onChange={(e) => setWin20(parseInt(e.target.value) || 0)} className="input-field" /></Field>
                <Field label="2-1勝ち"><input type="number" value={win11} onChange={(e) => setWin11(parseInt(e.target.value) || 0)} className="input-field" /></Field>
                <Field label="引き分け"><input type="number" value={draw} onChange={(e) => setDraw(parseInt(e.target.value) || 0)} className="input-field" /></Field>
                <Field label="1-2負け"><input type="number" value={lose11} onChange={(e) => setLose11(parseInt(e.target.value) || 0)} className="input-field" /></Field>
                <Field label="0-2負け"><input type="number" value={lose02} onChange={(e) => setLose02(parseInt(e.target.value) || 0)} className="input-field" /></Field>
              </div>
            )}
          </Section>

          <Section title="決勝ルール" icon={<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>}>
            <label className="flex items-center gap-2 mb-3 cursor-pointer">
              <input type="checkbox" checked={finalEnabled} onChange={(e) => setFinalEnabled(e.target.checked)} className="w-4 h-4 text-primary rounded" />
              <span className="text-sm text-foreground font-medium">決勝トーナメントを実施</span>
            </label>
            {finalEnabled && (
              <>
                <div className="grid grid-cols-3 gap-4">
                  <Field label="形式">
                    <select value={finalFormat} onChange={(e) => setFinalFormat(e.target.value)} className="input-field bg-white">
                      <option value="トーナメント">トーナメント</option>
                      <option value="上位下位">上位・下位トーナメント</option>
                    </select>
                  </Field>
                  <Field label="セット数"><input type="number" value={finalSets} onChange={(e) => setFinalSets(parseInt(e.target.value) || 1)} min={1} max={5} className="input-field" /></Field>
                  <Field label="ポイント数"><input type="number" value={finalPoints} onChange={(e) => setFinalPoints(parseInt(e.target.value) || 1)} min={1} max={30} className="input-field" /></Field>
                </div>
                <div className="flex items-center gap-6 flex-wrap">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" checked={finalDeuce} onChange={(e) => setFinalDeuce(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                    <span className="text-sm">デュースあり</span>
                  </label>
                  {finalDeuce && (
                    <Field label="キャップ"><input type="number" value={finalDeuceCap} onChange={(e) => setFinalDeuceCap(parseInt(e.target.value) || 25)} className="input-field w-24" /></Field>
                  )}
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" checked={thirdPlace} onChange={(e) => setThirdPlace(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                    <span className="text-sm">3位決定戦</span>
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" checked={loserRevival} onChange={(e) => setLoserRevival(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                    <span className="text-sm">敗者復活</span>
                  </label>
                </div>
              </>
            )}
          </Section>

          <Section title="その他" icon={<svg className="w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" /></svg>}>
            <div className="flex flex-wrap gap-6">
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={uniformRequired} onChange={(e) => setUniformRequired(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">ユニフォーム必須</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={snsVideoAllowed} onChange={(e) => setSnsVideoAllowed(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">SNS・動画撮影OK</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={lunchBreak} onChange={(e) => setLunchBreak(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">昼休憩あり</span>
              </label>
            </div>
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
          <Section title="タイムスケジュール" icon={<svg className="w-4 h-4 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>}>
            <p className="text-sm text-muted mb-4 p-3 bg-blue-50 rounded-xl border border-blue-100">
              <svg className="w-4 h-4 text-blue-500 inline mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>
              時間は任意です。設定した項目が大会情報に表示されます。
            </p>
            <div className="grid grid-cols-2 gap-4">
              <Field label="開場"><input type="time" value={openTime} onChange={(e) => setOpenTime(e.target.value)} className="input-field" /></Field>
              <Field label="受付"><input type="time" value={receptionTime} onChange={(e) => setReceptionTime(e.target.value)} className="input-field" /></Field>
              <Field label="開会式"><input type="time" value={ceremonyTime} onChange={(e) => setCeremonyTime(e.target.value)} className="input-field" /></Field>
              <Field label="試合開始"><input type="time" value={matchStartTime} onChange={(e) => setMatchStartTime(e.target.value)} className="input-field" /></Field>
              {lunchBreak && (
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
            <Section title="基本情報" icon={<svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>}>
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

            <Section title="予選ルール" icon={<svg className="w-4 h-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6z" /></svg>}>
              <div className="grid grid-cols-2 gap-y-3 text-sm">
                <ConfirmRow label="ラウンド" value={`${prelRounds}ラウンド`} />
                <ConfirmRow label="セット/ポイント" value={`${prelSets}セット ${prelPoints}点`} />
                <ConfirmRow label="デュース" value={prelDeuce ? `あり (${prelDeuceCap}点キャップ)` : "なし"} />
              </div>
            </Section>

            {scoringEnabled && (
              <Section title="勝ち点" icon={<svg className="w-4 h-4 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>}>
                <div className="flex gap-3 flex-wrap">
                  <span className="px-3 py-1.5 bg-green-50 text-green-700 rounded-lg text-sm font-medium border border-green-200">2-0勝: {win20}pt</span>
                  <span className="px-3 py-1.5 bg-blue-50 text-blue-700 rounded-lg text-sm font-medium border border-blue-200">2-1勝: {win11}pt</span>
                  <span className="px-3 py-1.5 bg-gray-50 text-gray-700 rounded-lg text-sm font-medium border border-gray-200">引分: {draw}pt</span>
                  <span className="px-3 py-1.5 bg-orange-50 text-orange-700 rounded-lg text-sm font-medium border border-orange-200">1-2負: {lose11}pt</span>
                  <span className="px-3 py-1.5 bg-red-50 text-red-700 rounded-lg text-sm font-medium border border-red-200">0-2負: {lose02}pt</span>
                </div>
              </Section>
            )}

            {finalEnabled && (
              <Section title="決勝" icon={<svg className="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872" /></svg>}>
                <div className="grid grid-cols-2 gap-y-3 text-sm">
                  <ConfirmRow label="形式" value={finalFormat} />
                  <ConfirmRow label="セット/ポイント" value={`${finalSets}セット ${finalPoints}点`} />
                  <ConfirmRow label="デュース" value={finalDeuce ? `あり (${finalDeuceCap}点キャップ)` : "なし"} />
                  <ConfirmRow label="3位決定戦" value={thirdPlace ? "あり" : "なし"} />
                </div>
              </Section>
            )}
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

function Section({ title, icon, children }: { title: string; icon?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-sm font-bold text-foreground mb-4 pb-2 border-b border-gray-100 flex items-center gap-2">
        {icon}
        {title}
      </h2>
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
