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
    case 1: return [{ key: "win", label: "勝ち" }, { key: "lose", label: "負け" }];
    case 2: return [
      { key: "win20", label: "2-0勝" }, { key: "win11", label: "1-1差勝" },
      { key: "draw", label: "同点" }, { key: "lose11", label: "1-1差負" }, { key: "lose02", label: "0-2負" },
    ];
    case 3: return [
      { key: "win20", label: "2-0勝" }, { key: "win21", label: "2-1勝" },
      { key: "lose12", label: "1-2負" }, { key: "lose02", label: "0-2負" },
    ];
    default: return [];
  }
}

export default function CreateTournamentPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const router = useRouter();

  // Venue picker
  const [allVenues, setAllVenues] = useState<VenueItem[]>([]);
  const [showVenuePicker, setShowVenuePicker] = useState(false);
  const [venueSearch, setVenueSearch] = useState("");
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
  const [r2SameAsR1, setR2SameAsR1] = useState(true);
  const [r2Sets, setR2Sets] = useState(2);
  const [r2Deuce, setR2Deuce] = useState(false);
  const [r2DeuceCap, setR2DeuceCap] = useState(17);

  // Scoring
  const [scoringEnabled, setScoringEnabled] = useState(true);
  const [r1Scoring, setR1Scoring] = useState<Record<string, number>>(defaultScoringForSets(2));
  const [r2Scoring, setR2Scoring] = useState<Record<string, number>>(defaultScoringForSets(2));

  // Finals
  const [finalEnabled, setFinalEnabled] = useState(true);
  const [finalSets, setFinalSets] = useState(3);
  const [finalDeuce, setFinalDeuce] = useState(true);
  const [finalDeuceCap, setFinalDeuceCap] = useState(17);
  const [finalFormat, setFinalFormat] = useState("順位別複数");
  const [finalTierCount, setFinalTierCount] = useState(3);

  // Other
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
  const [showRules, setShowRules] = useState(false);
  const [showSchedule, setShowSchedule] = useState(false);

  useEffect(() => {
    getDocs(query(collection(db, "venues"), orderBy("name"))).then((snap) => {
      setAllVenues(snap.docs.map((d) => ({ id: d.id, ...d.data() } as VenueItem)));
    });
  }, []);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (venueRef.current && !venueRef.current.contains(e.target as Node)) setShowVenuePicker(false);
    }
    if (showVenuePicker) document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [showVenuePicker]);

  const filteredVenues = allVenues.filter((v) => {
    if (!venueSearch && !location) return true;
    const q = (venueSearch || location).toLowerCase();
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

  const handlePrelSetsChange = (n: number) => {
    setPrelSets(n);
    setR1Scoring(defaultScoringForSets(n));
    if (r2SameAsR1) { setR2Sets(n); setR2Scoring(defaultScoringForSets(n)); }
  };

  if (authLoading) {
    return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  }
  if (!user) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
        <div className="text-center py-20 bg-white rounded-2xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <Link href="/login" className="btn-primary mt-4">ログイン</Link>
        </div>
      </div>
    );
  }

  const handleSubmit = async () => {
    if (!title || !date || !location) {
      setError("大会名、開催日、会場は必須です");
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    setSubmitting(true); setError("");
    try {
      const prelim: Record<string, unknown> = { rounds: prelRounds, sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap };
      if (prelRounds === 2) {
        prelim.round1 = { sets: prelSets, points: 15, deuce: prelDeuce, deuceCap: prelDeuceCap };
        prelim.round2 = r2SameAsR1 ? prelim.round1 : { sets: r2Sets, points: 15, deuce: r2Deuce, deuceCap: r2DeuceCap };
      }
      const scoring: Record<string, unknown> = { enabled: scoringEnabled, ...r1Scoring };
      if (prelRounds === 2) {
        scoring.round1 = { ...r1Scoring };
        scoring.round2 = r2SameAsR1 ? { ...r1Scoring } : { ...r2Scoring };
      }
      const docRef = await addDoc(collection(db, "tournaments"), {
        title, date, location, venueAddress, venueId: selectedVenueId || null,
        area, type, format, maxTeams, courts, entryFee, deadline,
        currentTeams: 0, status: "募集中",
        organizerId: user.uid, organizerName: profile?.nickname || "",
        createdAt: Timestamp.now(),
        rules: {
          management: { teamsPerCourt },
          preliminary: prelim, scoring,
          final: { enabled: finalEnabled, sets: finalSets, points: 15, deuce: finalDeuce, deuceCap: finalDeuceCap, format: finalFormat, tierCount: finalTierCount },
          other: { lunchBreak },
        },
        schedule: { openTime, receptionTime, ceremonyTime, matchStartTime, lunch: lunchTime, finalsTime, closingTime },
      });
      router.push(`/tournament/${docRef.id}`);
    } catch {
      setError("大会の作成に失敗しました");
    } finally { setSubmitting(false); }
  };

  return (
    <div className="p-6 md:p-8 max-w-[780px] mx-auto animate-fade-in">
      <div className="flex items-center gap-2 text-sm text-muted mb-4">
        <Link href="/tournaments" className="hover:text-primary transition-colors">大会一覧</Link>
        <span>/</span>
        <span className="text-foreground font-medium">新規作成</span>
      </div>

      <h1 className="text-2xl font-bold text-foreground mb-6">大会を作成</h1>

      {error && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl flex items-center gap-2">
          <span className="font-bold">!</span> {error}
        </div>
      )}

      <div className="space-y-5">
        {/* ===== 1. 基本情報 ===== */}
        <Section title="基本情報" num={1}>
          <div className="space-y-4">
            <Field label="大会名" required>
              <input type="text" value={title} onChange={(e) => setTitle(e.target.value)}
                className="input-field" placeholder="例: 第1回 ソフトバレーボール大会" />
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field label="開催日" required>
                <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="input-field" />
              </Field>
              <Field label="申込締切">
                <input type="date" value={deadline} onChange={(e) => setDeadline(e.target.value)} className="input-field" />
              </Field>
            </div>

            <Field label="種別">
              <Chips options={["メンズ", "レディース", "混合"]} value={type} onChange={setType} />
            </Field>
          </div>
        </Section>

        {/* ===== 2. 会場 ===== */}
        <Section title="会場" num={2}>
          <div className="space-y-4">
            <Field label="会場名" required hint="登録済み会場から選択、または直接入力">
              <div ref={venueRef} className="relative">
                <div className="relative">
                  <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
                  <input type="text" value={location}
                    onChange={(e) => { setLocation(e.target.value); setSelectedVenueId(""); setShowVenuePicker(true); }}
                    onFocus={() => setShowVenuePicker(true)}
                    className="input-field pl-11" placeholder="会場名を検索・入力..." />
                  {selectedVenueId && (
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-green-600 text-xs font-medium flex items-center gap-1">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                      選択済
                    </span>
                  )}
                </div>
                {showVenuePicker && allVenues.length > 0 && (
                  <div className="absolute z-20 top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-xl shadow-xl max-h-80 overflow-y-auto">
                    <div className="p-2 border-b border-gray-100 sticky top-0 bg-white z-10">
                      <input type="text" value={venueSearch} onChange={(e) => setVenueSearch(e.target.value)}
                        className="w-full px-3 py-1.5 text-sm border border-gray-200 rounded-lg" placeholder="絞り込み..." autoFocus />
                    </div>
                    {filteredVenues.length === 0 ? (
                      <div className="p-4 text-center text-sm text-gray-400">該当なし</div>
                    ) : filteredVenues.map((v) => (
                      <button key={v.id} type="button" onClick={() => selectVenue(v)}
                        className={`w-full text-left px-4 py-2 hover:bg-primary/5 transition-colors border-b border-gray-50 last:border-b-0 ${selectedVenueId === v.id ? "bg-primary/5" : ""}`}>
                        <span className="text-sm font-medium text-foreground">{v.name}</span>
                        <span className="text-xs text-muted ml-2">{v.address}</span>
                        {v.courts && <span className="text-xs text-primary ml-1">({v.courts}コート)</span>}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field label="住所">
                <input type="text" value={venueAddress} onChange={(e) => setVenueAddress(e.target.value)} className="input-field" placeholder="自動入力されます" />
              </Field>
              <Field label="エリア">
                <select value={area} onChange={(e) => setArea(e.target.value)} className="input-field bg-white">
                  <option value="">都道府県を選択</option>
                  {prefectures.map((p) => <option key={p} value={p}>{p}</option>)}
                </select>
              </Field>
            </div>
          </div>
        </Section>

        {/* ===== 3. チーム設定 ===== */}
        <Section title="チーム設定" num={3}>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <Field label="最大チーム数">
              <input type="number" value={maxTeams} onChange={(e) => setMaxTeams(parseInt(e.target.value) || 0)} min={2} className="input-field text-center" />
            </Field>
            <Field label="コート数">
              <input type="number" value={courts} onChange={(e) => setCourts(parseInt(e.target.value) || 0)} min={1} className="input-field text-center" />
            </Field>
            <Field label="チーム/コート">
              <input type="number" value={teamsPerCourt} onChange={(e) => setTeamsPerCourt(parseInt(e.target.value) || 0)} min={2} className="input-field text-center" />
            </Field>
            <Field label="参加費 (円)">
              <input type="number" value={entryFee} onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)} min={0} step={500} className="input-field text-center" />
            </Field>
          </div>
          <Field label="大会形式">
            <input type="text" value={format} onChange={(e) => setFormat(e.target.value)} className="input-field" placeholder="例: 予選リーグ+決勝トーナメント" />
          </Field>
        </Section>

        {/* ===== 4. ルール設定 (Collapsible) ===== */}
        <CollapsibleSection title="ルール設定" num={4} open={showRules} onToggle={() => setShowRules(!showRules)}
          summary={`予選: ${prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"} ・ 決勝: ${finalSets === 1 ? "1セット" : finalSets === 2 ? "2セット" : "3セット先取"} ・ 昼休憩: ${lunchBreak}`}>
          <div className="space-y-5">
            {/* Preliminary */}
            <div>
              <h4 className="text-sm font-bold text-foreground mb-3 flex items-center gap-2">
                <span className="w-5 h-5 bg-primary/10 text-primary rounded text-xs flex items-center justify-center font-bold">予</span>
                予選ルール
              </h4>
              <div className="grid grid-cols-2 gap-4 mb-3">
                <Field label="ラウンド数">
                  <Chips options={["1ラウンド", "2ラウンド"]} value={`${prelRounds}ラウンド`}
                    onChange={(v) => setPrelRounds(parseInt(v))} />
                </Field>
                <Field label="セット形式">
                  <Chips options={["1セット", "2セット", "3セット先取"]}
                    value={prelSets === 1 ? "1セット" : prelSets === 2 ? "2セット" : "3セット先取"}
                    onChange={(v) => handlePrelSetsChange(v === "1セット" ? 1 : v === "2セット" ? 2 : 3)} />
                </Field>
              </div>
              <div className="flex items-center gap-4 flex-wrap">
                <Toggle label="デュース" checked={prelDeuce} onChange={setPrelDeuce} />
                {prelDeuce && (
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-muted">キャップ</span>
                    <input type="number" value={prelDeuceCap} onChange={(e) => setPrelDeuceCap(parseInt(e.target.value) || 17)} className="w-16 input-field text-center py-1.5 text-sm" />
                  </div>
                )}
              </div>
              {prelRounds === 2 && (
                <div className="mt-3 p-3 bg-gray-50 rounded-xl border border-gray-100 space-y-3">
                  <Toggle label="ラウンド2も同じルール" checked={r2SameAsR1} onChange={setR2SameAsR1} />
                  {!r2SameAsR1 && (
                    <>
                      <Field label="R2 セット形式">
                        <Chips options={["1セット", "2セット", "3セット先取"]}
                          value={r2Sets === 1 ? "1セット" : r2Sets === 2 ? "2セット" : "3セット先取"}
                          onChange={(v) => { const n = v === "1セット" ? 1 : v === "2セット" ? 2 : 3; setR2Sets(n); setR2Scoring(defaultScoringForSets(n)); }} />
                      </Field>
                      <div className="flex items-center gap-4">
                        <Toggle label="デュース" checked={r2Deuce} onChange={setR2Deuce} />
                        {r2Deuce && <input type="number" value={r2DeuceCap} onChange={(e) => setR2DeuceCap(parseInt(e.target.value) || 17)} className="w-16 input-field text-center py-1.5 text-sm" />}
                      </div>
                    </>
                  )}
                </div>
              )}
            </div>

            {/* Scoring */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-sm font-bold text-foreground flex items-center gap-2">
                  <span className="w-5 h-5 bg-primary/10 text-primary rounded text-xs flex items-center justify-center font-bold">点</span>
                  勝ち点
                </h4>
                <Toggle label="" checked={scoringEnabled} onChange={setScoringEnabled} />
              </div>
              {scoringEnabled && (
                <div className="grid grid-cols-5 gap-2">
                  {scoringLabels(prelSets).map(({ key, label }) => (
                    <div key={key} className="text-center">
                      <p className="text-[11px] text-muted mb-1 truncate">{label}</p>
                      <input type="number" value={r1Scoring[key] ?? 0} onChange={(e) => setR1Scoring({ ...r1Scoring, [key]: parseInt(e.target.value) || 0 })}
                        className="w-full input-field text-center py-1.5 text-sm" />
                    </div>
                  ))}
                </div>
              )}
              {scoringEnabled && prelRounds === 2 && !r2SameAsR1 && (
                <div className="mt-3">
                  <p className="text-xs text-muted mb-2">ラウンド2 勝ち点</p>
                  <div className="grid grid-cols-5 gap-2">
                    {scoringLabels(r2Sets).map(({ key, label }) => (
                      <div key={key} className="text-center">
                        <p className="text-[11px] text-muted mb-1 truncate">{label}</p>
                        <input type="number" value={r2Scoring[key] ?? 0} onChange={(e) => setR2Scoring({ ...r2Scoring, [key]: parseInt(e.target.value) || 0 })}
                          className="w-full input-field text-center py-1.5 text-sm" />
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Finals */}
            <div>
              <div className="flex items-center justify-between mb-3">
                <h4 className="text-sm font-bold text-foreground flex items-center gap-2">
                  <span className="w-5 h-5 bg-accent/20 text-accent rounded text-xs flex items-center justify-center font-bold">決</span>
                  決勝ルール
                </h4>
                <Toggle label="" checked={finalEnabled} onChange={setFinalEnabled} />
              </div>
              {finalEnabled && (
                <div className="space-y-3">
                  <div className="grid grid-cols-2 gap-4">
                    <Field label="形式">
                      <Chips options={["順位別複数", "全チーム一本"]} value={finalFormat} onChange={setFinalFormat} />
                    </Field>
                    {finalFormat === "順位別複数" && (
                      <Field label="区分数">
                        <Chips options={["上・中", "上・中・下"]} value={finalTierCount === 2 ? "上・中" : "上・中・下"}
                          onChange={(v) => setFinalTierCount(v === "上・中" ? 2 : 3)} />
                      </Field>
                    )}
                  </div>
                  <Field label="セット形式">
                    <Chips options={["1セット", "2セット", "3セット先取"]}
                      value={finalSets === 1 ? "1セット" : finalSets === 2 ? "2セット" : "3セット先取"}
                      onChange={(v) => setFinalSets(v === "1セット" ? 1 : v === "2セット" ? 2 : 3)} />
                  </Field>
                  <div className="flex items-center gap-4">
                    <Toggle label="デュース" checked={finalDeuce} onChange={setFinalDeuce} />
                    {finalDeuce && <input type="number" value={finalDeuceCap} onChange={(e) => setFinalDeuceCap(parseInt(e.target.value) || 17)} className="w-16 input-field text-center py-1.5 text-sm" />}
                  </div>
                </div>
              )}
            </div>

            {/* Lunch break */}
            <Field label="昼休憩">
              <Chips options={["なし", "30分", "45分", "60分"]} value={lunchBreak} onChange={setLunchBreak} />
            </Field>
          </div>
        </CollapsibleSection>

        {/* ===== 5. スケジュール (Collapsible) ===== */}
        <CollapsibleSection title="タイムスケジュール" num={5} open={showSchedule} onToggle={() => setShowSchedule(!showSchedule)}
          summary="任意項目 - 設定した項目が大会ページに表示されます">
          <div className="grid grid-cols-2 gap-4">
            <Field label="開場"><input type="time" value={openTime} onChange={(e) => setOpenTime(e.target.value)} className="input-field" /></Field>
            <Field label="受付"><input type="time" value={receptionTime} onChange={(e) => setReceptionTime(e.target.value)} className="input-field" /></Field>
            <Field label="開会式"><input type="time" value={ceremonyTime} onChange={(e) => setCeremonyTime(e.target.value)} className="input-field" /></Field>
            <Field label="試合開始"><input type="time" value={matchStartTime} onChange={(e) => setMatchStartTime(e.target.value)} className="input-field" /></Field>
            {lunchBreak !== "なし" && <Field label="昼休憩"><input type="time" value={lunchTime} onChange={(e) => setLunchTime(e.target.value)} className="input-field" /></Field>}
            {finalEnabled && <Field label="決勝"><input type="time" value={finalsTime} onChange={(e) => setFinalsTime(e.target.value)} className="input-field" /></Field>}
            <Field label="閉会・片付け"><input type="time" value={closingTime} onChange={(e) => setClosingTime(e.target.value)} className="input-field" /></Field>
          </div>
        </CollapsibleSection>

        {/* ===== Submit ===== */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mt-2">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-bold text-foreground">準備ができたら作成しましょう</p>
              <p className="text-xs text-muted mt-0.5">ルールとスケジュールは後から変更できます</p>
            </div>
            <button onClick={handleSubmit} disabled={submitting}
              className="btn-accent px-8 py-3 text-base">
              {submitting ? (
                <><div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" /> 作成中...</>
              ) : "大会を作成"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ==============================
   Shared Components
   ============================== */

function Section({ title, num, children }: { title: string; num: number; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200">
      <div className="px-6 py-3.5 border-b border-gray-100 bg-gray-50/50 flex items-center gap-3 rounded-t-2xl">
        <span className="w-7 h-7 rounded-lg bg-primary text-white text-xs font-bold flex items-center justify-center">{num}</span>
        <h2 className="text-base font-bold text-foreground">{title}</h2>
      </div>
      <div className="p-6 space-y-4">{children}</div>
    </div>
  );
}

function CollapsibleSection({ title, num, open, onToggle, summary, children }: {
  title: string; num: number; open: boolean; onToggle: () => void; summary: string; children: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
      <button onClick={onToggle}
        className="w-full px-6 py-3.5 border-b border-gray-100 bg-gray-50/50 flex items-center gap-3 hover:bg-gray-100/50 transition-colors text-left">
        <span className="w-7 h-7 rounded-lg bg-primary text-white text-xs font-bold flex items-center justify-center">{num}</span>
        <div className="flex-1">
          <h2 className="text-base font-bold text-foreground">{title}</h2>
          {!open && <p className="text-xs text-muted mt-0.5">{summary}</p>}
        </div>
        <svg className={`w-5 h-5 text-muted transition-transform ${open ? "rotate-180" : ""}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" /></svg>
      </button>
      {open && <div className="p-6">{children}</div>}
    </div>
  );
}

function Field({ label, required, hint, children }: { label: string; required?: boolean; hint?: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-1.5">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {hint && <p className="text-xs text-muted mb-1.5">{hint}</p>}
      {children}
    </div>
  );
}

function Chips({ options, value, onChange }: { options: string[]; value: string; onChange: (v: string) => void }) {
  return (
    <div className="flex gap-2 flex-wrap">
      {options.map((opt) => (
        <button key={opt} type="button" onClick={() => onChange(opt)}
          className={`px-4 py-2 rounded-xl text-sm font-medium transition-all border ${
            value === opt
              ? "bg-primary text-white border-primary"
              : "bg-white text-muted border-gray-200 hover:border-primary/30 hover:text-foreground"
          }`}>
          {opt}
        </button>
      ))}
    </div>
  );
}

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex items-center gap-2.5 cursor-pointer select-none">
      <div className={`relative w-10 h-5.5 rounded-full transition-colors ${checked ? "bg-primary" : "bg-gray-300"}`}
        onClick={(e) => { e.preventDefault(); onChange(!checked); }}>
        <div className={`absolute top-0.5 w-4.5 h-4.5 bg-white rounded-full shadow transition-transform ${checked ? "translate-x-5" : "translate-x-0.5"}`} />
      </div>
      {label && <span className="text-sm font-medium text-foreground">{label}</span>}
    </label>
  );
}
