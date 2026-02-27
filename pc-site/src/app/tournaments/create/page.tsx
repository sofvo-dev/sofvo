"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { collection, addDoc, Timestamp, query, orderBy, getDocs } from "firebase/firestore";
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

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type VenueItem = { id: string; name: string; address: string; courts?: number } & Record<string, any>;

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
      { key: "win20", label: "2-0 勝ち" },
      { key: "win11", label: "1-1 得失点差勝ち" },
      { key: "draw", label: "1-1 同点" },
      { key: "lose11", label: "1-1 得失点差負け" },
      { key: "lose02", label: "0-2 負け" },
    ];
    case 3: return [
      { key: "win20", label: "2-0 勝ち" },
      { key: "win21", label: "2-1 勝ち" },
      { key: "lose12", label: "1-2 負け" },
      { key: "lose02", label: "0-2 負け" },
    ];
    default: return [];
  }
}

export default function CreateTournamentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const router = useRouter();
  const [step, setStep] = useState<Step>("basic");

  // Venue picker
  const [allVenues, setAllVenues] = useState<VenueItem[]>([]);
  const [venueSearch, setVenueSearch] = useState("");
  const [showVenuePicker, setShowVenuePicker] = useState(false);
  const [selectedVenueId, setSelectedVenueId] = useState("");
  const venueRef = useRef<HTMLDivElement>(null);

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

  // Rules - Round 2
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

  // Load venues for picker
  useEffect(() => {
    async function loadVenues() {
      const q = query(collection(db, "venues"), orderBy("name"));
      const snap = await getDocs(q);
      setAllVenues(snap.docs.map((d) => ({ id: d.id, ...d.data() } as VenueItem)));
    }
    loadVenues();
  }, []);

  // Close venue picker on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (venueRef.current && !venueRef.current.contains(e.target as Node)) {
        setShowVenuePicker(false);
      }
    }
    if (showVenuePicker) document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [showVenuePicker]);

  const filteredVenues = allVenues.filter((v) => {
    if (!venueSearch) return true;
    const q = venueSearch.toLowerCase();
    return v.name.toLowerCase().includes(q) || v.address.toLowerCase().includes(q);
  });

  const selectVenue = (venue: VenueItem) => {
    setSelectedVenueId(venue.id);
    setLocation(venue.name);
    setVenueAddress(venue.address);
    if (venue.courts) setCourts(venue.courts);
    setVenueSearch("");
    setShowVenuePicker(false);
  };

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
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
      const preliminaryRules: Record<string, unknown> = {
        rounds: prelRounds, sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap,
      };
      if (prelRounds === 2) {
        preliminaryRules.round1 = { sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap };
        preliminaryRules.round2 = r2SameAsR1
          ? { sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap }
          : { sets: r2Sets, points: 15, deuce: r2Deuce, deuceCap: r2DeuceCap };
      }
      const scoringRules: Record<string, unknown> = { enabled: scoringEnabled, ...r1Scoring };
      if (prelRounds === 2) {
        scoringRules.round1 = { ...r1Scoring };
        scoringRules.round2 = r2SameAsR1 ? { ...r1Scoring } : { ...r2Scoring };
      }

      const docRef = await addDoc(collection(db, "tournaments"), {
        title, date, location, venueAddress, venueId: selectedVenueId || null,
        area, type, format, maxTeams, courts, entryFee, deadline,
        currentTeams: 0, status: "募集中",
        organizerId: user.uid, organizerName: profile?.nickname || "",
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

  const steps: { key: Step; label: string; icon: string }[] = [
    { key: "basic", label: "基本情報", icon: "📋" },
    { key: "rules", label: "ルール", icon: "⚙️" },
    { key: "schedule", label: "スケジュール", icon: "🕐" },
    { key: "confirm", label: "確認", icon: "✅" },
  ];
  const stepIndex = steps.findIndex((s) => s.key === step);

  const handlePrelSetsChange = (newSets: number) => {
    setPrelSets(newSets);
    setR1Scoring(defaultScoringForSets(newSets));
    if (r2SameAsR1) { setR2Sets(newSets); setR2Scoring(defaultScoringForSets(newSets)); }
  };
  const handleR2SetsChange = (newSets: number) => {
    setR2Sets(newSets);
    setR2Scoring(defaultScoringForSets(newSets));
  };

  return (
    <div className="p-6 md:p-8 max-w-[820px] mx-auto animate-fade-in">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-5">
        <Link href="/tournaments/manage" className="hover:text-primary transition-colors">大会管理</Link>
        <span>/</span>
        <span className="text-foreground font-medium">新規作成</span>
      </div>

      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">大会を作成</h1>
      </div>

      {/* Step indicator */}
      <div className="flex items-center mb-8 bg-white rounded-xl border border-gray-200 p-4">
        {steps.map((s, i) => (
          <div key={s.key} className="flex items-center" style={{ flex: i < steps.length - 1 ? 1 : "none" }}>
            <button onClick={() => setStep(s.key)} className="flex items-center gap-2">
              <div className={`w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold transition-all ${
                i === stepIndex ? "bg-primary text-white shadow-md" :
                i < stepIndex ? "bg-green-500 text-white" : "bg-gray-100 text-gray-400"
              }`}>
                {i < stepIndex ? "✓" : i + 1}
              </div>
              <span className={`text-sm font-medium hidden sm:inline ${
                i === stepIndex ? "text-primary" : i < stepIndex ? "text-green-600" : "text-gray-400"
              }`}>{s.label}</span>
            </button>
            {i < steps.length - 1 && (
              <div className={`flex-1 h-0.5 mx-3 rounded ${i < stepIndex ? "bg-green-400" : "bg-gray-200"}`} />
            )}
          </div>
        ))}
      </div>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl flex items-center gap-3">
          <span>⚠️</span> {error}
        </div>
      )}

      {/* ========== STEP: BASIC ========== */}
      {step === "basic" && (
        <div className="space-y-6">
          {/* 大会名・日程 */}
          <Card title="大会名・日程">
            <div className="space-y-5">
              <Field label="大会名" required>
                <input type="text" value={title} onChange={(e) => setTitle(e.target.value)}
                  className="input-field" placeholder="例: 第1回 ソフトバレーボール大会" />
              </Field>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                <Field label="開催日" required>
                  <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="input-field" />
                </Field>
                <Field label="申込締切">
                  <input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="input-field" />
                </Field>
              </div>
            </div>
          </Card>

          {/* 会場 */}
          <Card title="会場">
            <div className="space-y-5">
              <Field label="会場名" required hint="登録済み会場から選択するか、直接入力してください">
                <div ref={venueRef} className="relative">
                  <div className="relative">
                    <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
                    <input type="text" value={location}
                      onChange={(e) => { setLocation(e.target.value); setSelectedVenueId(""); setShowVenuePicker(true); }}
                      onFocus={() => setShowVenuePicker(true)}
                      className="input-field pl-11" placeholder="会場名を検索・入力..." />
                    {selectedVenueId && (
                      <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1.5 text-green-600">
                        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                        <span className="text-xs font-medium">選択済み</span>
                      </div>
                    )}
                  </div>
                  {showVenuePicker && allVenues.length > 0 && (
                    <div className="absolute z-20 top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-xl shadow-xl max-h-64 overflow-y-auto">
                      <div className="p-2 border-b border-gray-100">
                        <input type="text" value={venueSearch} onChange={(e) => setVenueSearch(e.target.value)}
                          className="w-full px-3 py-2 text-sm border border-gray-200 rounded-lg" placeholder="会場を絞り込み..." autoFocus />
                      </div>
                      {filteredVenues.length === 0 ? (
                        <div className="p-4 text-center text-sm text-gray-400">該当する会場がありません</div>
                      ) : (
                        filteredVenues.map((v) => (
                          <button key={v.id} type="button" onClick={() => selectVenue(v)}
                            className={`w-full text-left px-4 py-3 hover:bg-primary/5 transition-colors border-b border-gray-50 last:border-b-0 ${
                              selectedVenueId === v.id ? "bg-primary/5" : ""
                            }`}>
                            <div className="font-medium text-sm text-foreground">{v.name}</div>
                            <div className="text-xs text-muted mt-0.5 flex items-center gap-2">
                              <span>{v.address}</span>
                              {v.courts && <span className="text-primary">({v.courts}コート)</span>}
                            </div>
                          </button>
                        ))
                      )}
                    </div>
                  )}
                </div>
              </Field>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                <Field label="住所">
                  <input type="text" value={venueAddress} onChange={(e) => setVenueAddress(e.target.value)} className="input-field" placeholder="例: 東京都渋谷区..." />
                </Field>
                <Field label="エリア">
                  <select value={area} onChange={(e) => setArea(e.target.value)} className="input-field bg-white">
                    <option value="">都道府県を選択</option>
                    {prefectures.map((p) => <option key={p} value={p}>{p}</option>)}
                  </select>
                </Field>
              </div>
            </div>
          </Card>

          {/* 大会設定 */}
          <Card title="大会設定">
            <div className="space-y-5">
              <Field label="種別">
                <ButtonGroup options={["メンズ", "レディース", "混合"]} value={type} onChange={setType} />
              </Field>
              <Field label="大会形式">
                <input type="text" value={format} onChange={(e) => setFormat(e.target.value)} className="input-field" placeholder="例: 予選リーグ+決勝トーナメント" />
              </Field>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <Field label="最大チーム数">
                  <input type="number" value={maxTeams} onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)} min={2} className="input-field text-center" />
                </Field>
                <Field label="コート数">
                  <input type="number" value={courts} onChange={(e) => setCourts(parseInt(e.target.value) || 0)} min={1} max={8} className="input-field text-center" />
                </Field>
                <Field label="コートあたりチーム">
                  <input type="number" value={teamsPerCourt} onChange={(e) => setTeamsPerCourt(parseInt(e.target.value) || 0)} min={2} max={8} className="input-field text-center" />
                </Field>
                <Field label="参加費 (円)">
                  <input type="number" value={entryFee} onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)} min={0} step={500} className="input-field text-center" />
                </Field>
              </div>
            </div>
          </Card>

          <NavButtons onNext={() => setStep("rules")} nextLabel="ルール設定へ" />
        </div>
      )}

      {/* ========== STEP: RULES ========== */}
      {step === "rules" && (
        <div className="space-y-6">
          <Card title="予選ルール">
            <div className="space-y-5">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                <Field label="ラウンド数">
                  <ButtonGroup options={["1ラウンド", "2ラウンド"]} value={`${prelRounds}ラウンド`}
                    onChange={(v) => setPrelRounds(parseInt(v))} />
                </Field>
                <Field label="セット形式">
                  <ButtonGroup options={["1セット", "2セット", "3セット先取"]} value={prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"}
                    onChange={(v) => handlePrelSetsChange(v === "1セット" ? 1 : v === "2セット" ? 2 : 3)} />
                </Field>
              </div>
              <div className="flex items-center gap-6 flex-wrap">
                <Toggle label="デュースあり" checked={prelDeuce} onChange={setPrelDeuce} />
                {prelDeuce && (
                  <Field label="キャップ">
                    <input type="number" value={prelDeuceCap} onChange={(e) => setPrelDeuceCap(parseInt(e.target.value) || 17)} min={15} max={30} className="input-field w-20 text-center" />
                  </Field>
                )}
              </div>

              {prelRounds === 2 && (
                <div className="mt-2 p-4 bg-gray-50 rounded-xl space-y-4 border border-gray-100">
                  <p className="text-sm font-bold text-foreground">ラウンド2 設定</p>
                  <Toggle label="1回目と同じルール" checked={r2SameAsR1} onChange={setR2SameAsR1} />
                  {!r2SameAsR1 && (
                    <>
                      <Field label="セット形式">
                        <ButtonGroup options={["1セット", "2セット", "3セット先取"]} value={r2Sets === 1 ? "1セット" : r2Sets === 2 ? "2セット" : "3セット先取"}
                          onChange={(v) => handleR2SetsChange(v === "1セット" ? 1 : v === "2セット" ? 2 : 3)} />
                      </Field>
                      <div className="flex items-center gap-6 flex-wrap">
                        <Toggle label="デュースあり" checked={r2Deuce} onChange={setR2Deuce} />
                        {r2Deuce && (
                          <Field label="キャップ">
                            <input type="number" value={r2DeuceCap} onChange={(e) => setR2DeuceCap(parseInt(e.target.value) || 17)} className="input-field w-20 text-center" />
                          </Field>
                        )}
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>
          </Card>

          <Card title="勝ち点設定">
            <div className="space-y-5">
              <Toggle label="勝ち点制を使用" checked={scoringEnabled} onChange={setScoringEnabled} />
              {scoringEnabled && (
                <>
                  <p className="text-xs text-muted">ラウンド1 ({prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"})</p>
                  <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
                    {scoringLabels(prelSets).map(({ key, label }) => (
                      <Field key={key} label={label}>
                        <input type="number" value={r1Scoring[key] ?? 0} onChange={(e) => setR1Scoring({ ...r1Scoring, [key]: parseInt(e.target.value) || 0 })}
                          className="input-field text-center" />
                      </Field>
                    ))}
                  </div>
                  {prelRounds === 2 && !r2SameAsR1 && (
                    <>
                      <p className="text-xs text-muted mt-3">ラウンド2 ({r2Sets === 1 ? "1セット" : r2Sets === 2 ? "2セット" : "3セット先取"})</p>
                      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
                        {scoringLabels(r2Sets).map(({ key, label }) => (
                          <Field key={key} label={label}>
                            <input type="number" value={r2Scoring[key] ?? 0} onChange={(e) => setR2Scoring({ ...r2Scoring, [key]: parseInt(e.target.value) || 0 })}
                              className="input-field text-center" />
                          </Field>
                        ))}
                      </div>
                    </>
                  )}
                </>
              )}
            </div>
          </Card>

          <Card title="決勝ルール">
            <div className="space-y-5">
              <Toggle label="順位決定戦を行う" checked={finalEnabled} onChange={setFinalEnabled} />
              {finalEnabled && (
                <>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                    <Field label="形式">
                      <ButtonGroup options={["順位別複数", "全チーム一本"]} value={finalFormat} onChange={setFinalFormat} />
                    </Field>
                    {finalFormat === "順位別複数" && (
                      <Field label="区分数">
                        <ButtonGroup options={["上・中", "上・中・下"]} value={finalTierCount === 2 ? "上・中" : "上・中・下"}
                          onChange={(v) => setFinalTierCount(v === "上・中" ? 2 : 3)} />
                      </Field>
                    )}
                  </div>
                  <Field label="セット形式">
                    <ButtonGroup options={["1セット", "2セット", "3セット先取"]} value={finalSets === 1 ? "1セット" : finalSets === 2 ? "2セット" : "3セット先取"}
                      onChange={(v) => setFinalSets(v === "1セット" ? 1 : v === "2セット" ? 2 : 3)} />
                  </Field>
                  <div className="flex items-center gap-6 flex-wrap">
                    <Toggle label="デュースあり" checked={finalDeuce} onChange={setFinalDeuce} />
                    {finalDeuce && (
                      <Field label="キャップ">
                        <input type="number" value={finalDeuceCap} onChange={(e) => setFinalDeuceCap(parseInt(e.target.value) || 17)} className="input-field w-20 text-center" />
                      </Field>
                    )}
                  </div>
                </>
              )}
            </div>
          </Card>

          <Card title="その他">
            <div className="space-y-5">
              <div className="flex flex-wrap gap-6">
                <Toggle label="ユニフォーム必須" checked={uniformRequired} onChange={setUniformRequired} />
                <Toggle label="SNS・動画撮影OK" checked={snsVideoAllowed} onChange={setSnsVideoAllowed} />
              </div>
              <Field label="昼休憩">
                <ButtonGroup options={["なし", "30分", "45分", "60分"]} value={lunchBreak} onChange={setLunchBreak} />
              </Field>
            </div>
          </Card>

          <NavButtons onPrev={() => setStep("basic")} onNext={() => setStep("schedule")} nextLabel="スケジュールへ" />
        </div>
      )}

      {/* ========== STEP: SCHEDULE ========== */}
      {step === "schedule" && (
        <div className="space-y-6">
          <Card title="タイムスケジュール">
            <div className="space-y-5">
              <div className="p-3 bg-blue-50 rounded-lg text-sm text-blue-700 border border-blue-100">
                時間は任意です。設定した項目が大会情報に表示されます。
              </div>
              <div className="grid grid-cols-2 gap-5">
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
            </div>
          </Card>

          <NavButtons onPrev={() => setStep("rules")} onNext={() => setStep("confirm")} nextLabel="確認へ" />
        </div>
      )}

      {/* ========== STEP: CONFIRM ========== */}
      {step === "confirm" && (
        <div className="space-y-6">
          <Card title="基本情報">
            <ConfirmGrid>
              <ConfirmRow label="大会名" value={title || "−"} />
              <ConfirmRow label="開催日" value={date || "−"} />
              <ConfirmRow label="会場" value={location || "−"} />
              <ConfirmRow label="住所" value={venueAddress || "−"} />
              <ConfirmRow label="エリア" value={area || "−"} />
              <ConfirmRow label="種別" value={type} />
              <ConfirmRow label="形式" value={format || "−"} />
              <ConfirmRow label="最大チーム" value={`${maxTeams}チーム`} />
              <ConfirmRow label="コート" value={`${courts}コート (${teamsPerCourt}チーム/コート)`} />
              <ConfirmRow label="参加費" value={entryFee > 0 ? `¥${entryFee.toLocaleString()}` : "無料"} />
            </ConfirmGrid>
          </Card>

          <Card title="予選ルール">
            <ConfirmGrid>
              <ConfirmRow label="ラウンド" value={`${prelRounds}ラウンド`} />
              <ConfirmRow label="セット形式" value={prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"} />
              <ConfirmRow label="デュース" value={prelDeuce ? `あり (${prelDeuceCap}点キャップ)` : "なし"} />
            </ConfirmGrid>
            {scoringEnabled && (
              <div className="flex gap-2 flex-wrap mt-4 pt-4 border-t border-gray-100">
                {scoringLabels(prelSets).map(({ key, label }) => (
                  <span key={key} className="px-3 py-1.5 bg-gray-50 text-gray-700 rounded-lg text-sm border border-gray-200">
                    {label}: <strong>{r1Scoring[key] ?? 0}pt</strong>
                  </span>
                ))}
              </div>
            )}
          </Card>

          {finalEnabled && (
            <Card title="決勝ルール">
              <ConfirmGrid>
                <ConfirmRow label="形式" value={finalFormat} />
                {finalFormat === "順位別複数" && <ConfirmRow label="区分" value={finalTierCount === 2 ? "上・中" : "上・中・下"} />}
                <ConfirmRow label="セット" value={finalSets === 1 ? "1セット" : finalSets === 2 ? "2セット" : "3セット先取"} />
                <ConfirmRow label="デュース" value={finalDeuce ? `あり (${finalDeuceCap}点キャップ)` : "なし"} />
              </ConfirmGrid>
            </Card>
          )}

          <Card title="その他">
            <ConfirmGrid>
              <ConfirmRow label="ユニフォーム" value={uniformRequired ? "必須" : "任意"} />
              <ConfirmRow label="SNS・動画" value={snsVideoAllowed ? "OK" : "NG"} />
              <ConfirmRow label="昼休憩" value={lunchBreak} />
            </ConfirmGrid>
          </Card>

          <div className="flex items-center justify-between pt-2">
            <button onClick={() => setStep("schedule")} className="flex items-center gap-2 px-5 py-3 text-muted hover:text-foreground text-sm font-medium transition-colors">
              ← 戻る
            </button>
            <button onClick={handleSubmit} disabled={submitting}
              className="btn-accent px-8 py-3 text-base">
              {submitting ? (
                <><div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" /> 作成中...</>
              ) : (
                <>大会を作成する</>
              )}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/* ==============================
   Shared Components
   ============================== */

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
      <div className="px-6 py-4 border-b border-gray-100 bg-gray-50/50">
        <h2 className="text-base font-bold text-foreground">{title}</h2>
      </div>
      <div className="p-6">{children}</div>
    </div>
  );
}

function Field({ label, required, hint, children }: { label: string; required?: boolean; hint?: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-2">
        {label}
        {required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {hint && <p className="text-xs text-muted mb-2">{hint}</p>}
      {children}
    </div>
  );
}

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex items-center gap-3 cursor-pointer select-none">
      <div className={`relative w-11 h-6 rounded-full transition-colors ${checked ? "bg-primary" : "bg-gray-300"}`}
        onClick={() => onChange(!checked)}>
        <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${checked ? "translate-x-5.5" : "translate-x-0.5"}`} />
      </div>
      <span className="text-sm font-medium text-foreground">{label}</span>
    </label>
  );
}

function ButtonGroup({ options, value, onChange }: { options: string[]; value: string; onChange: (v: string) => void }) {
  return (
    <div className="flex gap-2 flex-wrap">
      {options.map((opt) => (
        <button key={opt} type="button" onClick={() => onChange(opt)}
          className={`px-4 py-2.5 rounded-xl text-sm font-medium transition-all border ${
            value === opt
              ? "bg-primary text-white border-primary shadow-sm"
              : "bg-white text-muted border-gray-200 hover:border-primary/30 hover:text-foreground"
          }`}>
          {opt}
        </button>
      ))}
    </div>
  );
}

function NavButtons({ onPrev, onNext, nextLabel }: { onPrev?: () => void; onNext: () => void; nextLabel: string }) {
  return (
    <div className="flex items-center justify-between pt-2">
      {onPrev ? (
        <button onClick={onPrev} className="flex items-center gap-2 px-5 py-3 text-muted hover:text-foreground text-sm font-medium transition-colors">
          ← 戻る
        </button>
      ) : <div />}
      <button onClick={onNext} className="btn-primary px-6 py-3">
        {nextLabel} →
      </button>
    </div>
  );
}

function ConfirmGrid({ children }: { children: React.ReactNode }) {
  return <div className="space-y-3">{children}</div>;
}

function ConfirmRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 py-2 border-b border-gray-50 last:border-b-0">
      <span className="text-sm text-muted w-32 flex-shrink-0">{label}</span>
      <span className="text-sm font-medium text-foreground">{value}</span>
    </div>
  );
}
