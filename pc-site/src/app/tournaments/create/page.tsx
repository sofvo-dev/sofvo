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
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <Link href="/login" className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">ログイン</Link>
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

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors">大会管理</Link>
        <span>/</span>
        <span className="text-foreground">新規作成</span>
      </div>

      <h1 className="text-2xl font-bold text-foreground mb-6">大会を作成</h1>

      {/* Step indicator */}
      <div className="flex items-center gap-2 mb-8">
        {steps.map((s, i) => (
          <div key={s.key} className="flex items-center gap-2">
            <button
              onClick={() => setStep(s.key)}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                step === s.key ? "bg-primary text-white" : "bg-white text-muted border border-gray-200 hover:border-primary/30"
              }`}
            >
              <span className={`w-5 h-5 rounded-full text-xs flex items-center justify-center font-bold ${
                step === s.key ? "bg-white text-primary" : "bg-gray-200 text-muted"
              }`}>{i + 1}</span>
              {s.label}
            </button>
            {i < steps.length - 1 && <span className="text-gray-300">—</span>}
          </div>
        ))}
      </div>

      {error && (
        <div className="mb-6 p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg">{error}</div>
      )}

      {/* Step: Basic */}
      {step === "basic" && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-6">
          <Section title="基本情報">
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

          <Section title="大会設定">
            <Field label="種別">
              <div className="flex gap-2">
                {["メンズ", "レディース", "混合"].map((t) => (
                  <button key={t} type="button" onClick={() => setType(t)}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${type === t ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}
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
            <button onClick={() => setStep("rules")} className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">
              次へ: ルール設定
            </button>
          </div>
        </div>
      )}

      {/* Step: Rules */}
      {step === "rules" && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-6">
          <Section title="予選ルール">
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

          <Section title="勝ち点設定">
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

          <Section title="決勝ルール">
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
                <div className="flex items-center gap-6">
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
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={lunchBreak} onChange={(e) => setLunchBreak(e.target.checked)} className="w-4 h-4 text-primary rounded" />
                <span className="text-sm">昼休憩あり</span>
              </label>
            </div>
          </Section>

          <div className="flex justify-between pt-4 border-t border-gray-100">
            <button onClick={() => setStep("basic")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors">戻る</button>
            <button onClick={() => setStep("schedule")} className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">次へ: スケジュール</button>
          </div>
        </div>
      )}

      {/* Step: Schedule */}
      {step === "schedule" && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-6">
          <Section title="タイムスケジュール">
            <p className="text-sm text-muted mb-4">時間は任意です。設定した項目が大会情報に表示されます。</p>
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
            <button onClick={() => setStep("rules")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors">戻る</button>
            <button onClick={() => setStep("confirm")} className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">次へ: 確認</button>
          </div>
        </div>
      )}

      {/* Step: Confirm */}
      {step === "confirm" && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 space-y-6">
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
              <ConfirmRow label="セット/ポイント" value={`${prelSets}セット ${prelPoints}点`} />
              <ConfirmRow label="デュース" value={prelDeuce ? `あり (${prelDeuceCap}点キャップ)` : "なし"} />
            </div>
          </Section>

          {scoringEnabled && (
            <Section title="勝ち点">
              <div className="flex gap-4 text-sm">
                <span className="text-muted">2-0勝: <span className="font-bold text-foreground">{win20}</span></span>
                <span className="text-muted">2-1勝: <span className="font-bold text-foreground">{win11}</span></span>
                <span className="text-muted">引分: <span className="font-bold text-foreground">{draw}</span></span>
                <span className="text-muted">1-2負: <span className="font-bold text-foreground">{lose11}</span></span>
                <span className="text-muted">0-2負: <span className="font-bold text-foreground">{lose02}</span></span>
              </div>
            </Section>
          )}

          {finalEnabled && (
            <Section title="決勝">
              <div className="grid grid-cols-2 gap-y-3 text-sm">
                <ConfirmRow label="形式" value={finalFormat} />
                <ConfirmRow label="セット/ポイント" value={`${finalSets}セット ${finalPoints}点`} />
                <ConfirmRow label="デュース" value={finalDeuce ? `あり (${finalDeuceCap}点キャップ)` : "なし"} />
                <ConfirmRow label="3位決定戦" value={thirdPlace ? "あり" : "なし"} />
              </div>
            </Section>
          )}

          <div className="flex justify-between pt-4 border-t border-gray-100">
            <button onClick={() => setStep("schedule")} className="px-6 py-2.5 text-muted hover:text-foreground text-sm font-medium transition-colors">戻る</button>
            <button onClick={handleSubmit} disabled={submitting} className="px-8 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50">
              {submitting ? "作成中..." : "大会を作成する"}
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
