"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { collection, addDoc, Timestamp, query, orderBy, getDocs } from "firebase/firestore";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { db, storage } from "@/lib/firebase";
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

const DRAFT_KEY = "sofvo_tournament_draft";

/* ===== Templates ===== */
interface TemplateConfig {
  maxTeams: number;
  courts: number;
  format: string;
  entryFee: number;
  prelRounds: number;
  prelSets: number;
  prelDeuce: boolean;
  prelDeuceCap: number;
  finalEnabled: boolean;
  finalSets: number;
  finalDeuce: boolean;
  finalDeuceCap: number;
  finalFormat: string;
  finalTierCount: number;
  lunchBreak: string;
}

const templates: { id: string; name: string; desc: string; teams: string; config: TemplateConfig | null }[] = [
  {
    id: "custom", name: "カスタム", desc: "すべて自由に設定", teams: "",
    config: null,
  },
  {
    id: "standard16", name: "標準大会", desc: "予選2セット+決勝3セット先取", teams: "16チーム / 4コート",
    config: {
      maxTeams: 16, courts: 4, format: "予選リーグ+決勝トーナメント", entryFee: 1500,
      prelRounds: 1, prelSets: 2, prelDeuce: false, prelDeuceCap: 17,
      finalEnabled: true, finalSets: 3, finalDeuce: true, finalDeuceCap: 17,
      finalFormat: "順位別複数", finalTierCount: 3, lunchBreak: "45分",
    },
  },
  {
    id: "small8", name: "小規模大会", desc: "予選2セット+決勝3セット先取", teams: "8チーム / 2コート",
    config: {
      maxTeams: 8, courts: 2, format: "予選リーグ+決勝トーナメント", entryFee: 1000,
      prelRounds: 1, prelSets: 2, prelDeuce: false, prelDeuceCap: 17,
      finalEnabled: true, finalSets: 3, finalDeuce: true, finalDeuceCap: 17,
      finalFormat: "順位別複数", finalTierCount: 2, lunchBreak: "なし",
    },
  },
  {
    id: "large24", name: "大規模大会", desc: "予選2セット(2R)+決勝3セット先取", teams: "24チーム / 6コート",
    config: {
      maxTeams: 24, courts: 6, format: "予選リーグ+決勝トーナメント", entryFee: 2000,
      prelRounds: 2, prelSets: 2, prelDeuce: false, prelDeuceCap: 17,
      finalEnabled: true, finalSets: 3, finalDeuce: true, finalDeuceCap: 17,
      finalFormat: "順位別複数", finalTierCount: 3, lunchBreak: "45分",
    },
  },
];

/* ===== Scoring helpers ===== */
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

  // Template
  const [selectedTemplate, setSelectedTemplate] = useState("custom");

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
  const [description, setDescription] = useState("");
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

  // PDF
  const [pdfFile, setPdfFile] = useState<File | null>(null);

  // UI state
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [showRules, setShowRules] = useState(false);
  const [showSchedule, setShowSchedule] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const [hasDraft, setHasDraft] = useState(false);

  // Draft auto-save ref
  const formRef = useRef<Record<string, unknown>>({});
  formRef.current = {
    title, date, location, venueAddress, area, type, format, description,
    maxTeams, courts, entryFee, deadline, selectedVenueId, selectedTemplate,
    prelRounds, prelSets, prelDeuce, prelDeuceCap,
    r2SameAsR1, r2Sets, r2Deuce, r2DeuceCap,
    scoringEnabled, r1Scoring, r2Scoring,
    finalEnabled, finalSets, finalDeuce, finalDeuceCap, finalFormat, finalTierCount,
    lunchBreak,
    openTime, receptionTime, ceremonyTime, matchStartTime, lunchTime, finalsTime, closingTime,
  };

  // Load venues
  useEffect(() => {
    getDocs(query(collection(db, "venues"), orderBy("name"))).then((snap) => {
      setAllVenues(snap.docs.map((d) => ({ id: d.id, ...d.data() } as VenueItem)));
    });
  }, []);

  // Outside click for venue picker
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (venueRef.current && !venueRef.current.contains(e.target as Node)) setShowVenuePicker(false);
    }
    if (showVenuePicker) document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, [showVenuePicker]);

  // Check for existing draft on mount
  useEffect(() => {
    try {
      const saved = localStorage.getItem(DRAFT_KEY);
      if (saved) {
        const d = JSON.parse(saved);
        if (d.title || d.date || d.location) setHasDraft(true);
      }
    } catch { /* ignore */ }
  }, []);

  // Auto-save draft every 5 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      const d = formRef.current as { title?: string; date?: string; location?: string };
      if (d.title || d.date || d.location) {
        localStorage.setItem(DRAFT_KEY, JSON.stringify(formRef.current));
      }
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  // Auto-calculate teamsPerCourt
  useEffect(() => {
    if (courts > 0 && maxTeams > 0) {
      setTeamsPerCourt(Math.ceil(maxTeams / courts));
    }
  }, [maxTeams, courts]);

  // Venue filtering
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

  // Template apply
  const applyTemplate = (id: string) => {
    setSelectedTemplate(id);
    const tmpl = templates.find(t => t.id === id);
    if (!tmpl?.config) return;
    const c = tmpl.config;
    setMaxTeams(c.maxTeams);
    setCourts(c.courts);
    setFormat(c.format);
    setEntryFee(c.entryFee);
    setPrelRounds(c.prelRounds);
    setPrelSets(c.prelSets);
    setPrelDeuce(c.prelDeuce);
    setPrelDeuceCap(c.prelDeuceCap);
    setR1Scoring(defaultScoringForSets(c.prelSets));
    setR2SameAsR1(true);
    setR2Sets(c.prelSets);
    setR2Scoring(defaultScoringForSets(c.prelSets));
    setFinalEnabled(c.finalEnabled);
    setFinalSets(c.finalSets);
    setFinalDeuce(c.finalDeuce);
    setFinalDeuceCap(c.finalDeuceCap);
    setFinalFormat(c.finalFormat);
    setFinalTierCount(c.finalTierCount);
    setLunchBreak(c.lunchBreak);
  };

  // Draft restore
  const restoreDraft = () => {
    try {
      const raw = localStorage.getItem(DRAFT_KEY);
      if (!raw) return;
      const d = JSON.parse(raw);
      if (d.title !== undefined) setTitle(d.title);
      if (d.date !== undefined) setDate(d.date);
      if (d.location !== undefined) setLocation(d.location);
      if (d.venueAddress !== undefined) setVenueAddress(d.venueAddress);
      if (d.area !== undefined) setArea(d.area);
      if (d.type !== undefined) setType(d.type);
      if (d.format !== undefined) setFormat(d.format);
      if (d.description !== undefined) setDescription(d.description);
      if (d.maxTeams !== undefined) setMaxTeams(d.maxTeams);
      if (d.courts !== undefined) setCourts(d.courts);
      if (d.entryFee !== undefined) setEntryFee(d.entryFee);
      if (d.deadline !== undefined) setDeadline(d.deadline);
      if (d.selectedVenueId !== undefined) setSelectedVenueId(d.selectedVenueId);
      if (d.selectedTemplate !== undefined) setSelectedTemplate(d.selectedTemplate);
      if (d.prelRounds !== undefined) setPrelRounds(d.prelRounds);
      if (d.prelSets !== undefined) setPrelSets(d.prelSets);
      if (d.prelDeuce !== undefined) setPrelDeuce(d.prelDeuce);
      if (d.prelDeuceCap !== undefined) setPrelDeuceCap(d.prelDeuceCap);
      if (d.r2SameAsR1 !== undefined) setR2SameAsR1(d.r2SameAsR1);
      if (d.r2Sets !== undefined) setR2Sets(d.r2Sets);
      if (d.r2Deuce !== undefined) setR2Deuce(d.r2Deuce);
      if (d.r2DeuceCap !== undefined) setR2DeuceCap(d.r2DeuceCap);
      if (d.scoringEnabled !== undefined) setScoringEnabled(d.scoringEnabled);
      if (d.r1Scoring !== undefined) setR1Scoring(d.r1Scoring);
      if (d.r2Scoring !== undefined) setR2Scoring(d.r2Scoring);
      if (d.finalEnabled !== undefined) setFinalEnabled(d.finalEnabled);
      if (d.finalSets !== undefined) setFinalSets(d.finalSets);
      if (d.finalDeuce !== undefined) setFinalDeuce(d.finalDeuce);
      if (d.finalDeuceCap !== undefined) setFinalDeuceCap(d.finalDeuceCap);
      if (d.finalFormat !== undefined) setFinalFormat(d.finalFormat);
      if (d.finalTierCount !== undefined) setFinalTierCount(d.finalTierCount);
      if (d.lunchBreak !== undefined) setLunchBreak(d.lunchBreak);
      if (d.openTime !== undefined) setOpenTime(d.openTime);
      if (d.receptionTime !== undefined) setReceptionTime(d.receptionTime);
      if (d.ceremonyTime !== undefined) setCeremonyTime(d.ceremonyTime);
      if (d.matchStartTime !== undefined) setMatchStartTime(d.matchStartTime);
      if (d.lunchTime !== undefined) setLunchTime(d.lunchTime);
      if (d.finalsTime !== undefined) setFinalsTime(d.finalsTime);
      if (d.closingTime !== undefined) setClosingTime(d.closingTime);
    } catch { /* ignore */ }
    setHasDraft(false);
  };

  const discardDraft = () => {
    localStorage.removeItem(DRAFT_KEY);
    setHasDraft(false);
  };

  // Inline validations (computed)
  const deadlineWarning = deadline && date && deadline > date ? "締切日が開催日より後です" : "";
  const courtsVsTeamsWarning = courts > 0 && maxTeams > 0 && courts > maxTeams ? "コート数がチーム数を超えています" : "";

  // Schedule time validation
  const scheduleWarnings: string[] = [];
  const orderedTimes = [
    { val: openTime, label: "開場" },
    { val: receptionTime, label: "受付" },
    { val: ceremonyTime, label: "開会式" },
    { val: matchStartTime, label: "試合開始" },
    ...(lunchBreak !== "なし" ? [{ val: lunchTime, label: "昼休憩" }] : []),
    ...(finalEnabled ? [{ val: finalsTime, label: "決勝" }] : []),
    { val: closingTime, label: "閉会" },
  ].filter(t => t.val);
  for (let i = 1; i < orderedTimes.length; i++) {
    if (orderedTimes[i].val < orderedTimes[i - 1].val) {
      scheduleWarnings.push(`「${orderedTimes[i].label}」が「${orderedTimes[i - 1].label}」より前の時間です`);
    }
  }

  // Auth checks
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
    const newErrors: Record<string, string> = {};
    if (!title.trim()) newErrors.title = "大会名は必須です";
    if (!date) newErrors.date = "開催日は必須です";
    if (!location.trim()) newErrors.location = "会場は必須です";
    if (maxTeams < 2) newErrors.maxTeams = "2チーム以上にしてください";
    if (courts < 1) newErrors.courts = "1コート以上にしてください";
    if (deadline && date && deadline > date) newErrors.deadline = "締切日は開催日以前にしてください";

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    setErrors({});
    setSubmitting(true);
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
      // PDF をアップロード
      let rulesPdfUrl: string | null = null;
      let rulesPdfName: string | null = null;
      if (pdfFile) {
        const timestamp = Date.now();
        const storageRef = ref(storage, `tournament_rules/${user.uid}/${timestamp}_${pdfFile.name}`);
        await uploadBytes(storageRef, pdfFile, { contentType: "application/pdf" });
        rulesPdfUrl = await getDownloadURL(storageRef);
        rulesPdfName = pdfFile.name;
      }

      const docRef = await addDoc(collection(db, "tournaments"), {
        title, date, location, venueAddress, venueId: selectedVenueId || null,
        area, type, format, description, maxTeams, courts, entryFee, deadline,
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
        ...(rulesPdfUrl ? { rulesPdfUrl, rulesPdfName } : {}),
      });
      localStorage.removeItem(DRAFT_KEY);
      router.push(`/tournament/${docRef.id}`);
    } catch {
      setErrors({ submit: "大会の作成に失敗しました" });
    } finally { setSubmitting(false); }
  };

  // Helpers for preview
  const setsLabel = (s: number) => s === 1 ? "1セット" : s === 2 ? "2セット" : "3セット先取";
  const hasSchedule = openTime || receptionTime || ceremonyTime || matchStartTime || lunchTime || finalsTime || closingTime;

  return (
    <div className="p-6 md:p-8 max-w-[780px] mx-auto animate-fade-in">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-4">
        <Link href="/tournaments" className="hover:text-primary transition-colors">大会一覧</Link>
        <span>/</span>
        <span className="text-foreground font-medium">新規作成</span>
      </div>

      <h1 className="text-2xl font-bold text-foreground mb-1">大会を作成</h1>
      <p className="text-sm text-muted mb-6">テンプレートを選んで簡単にスタートできます</p>

      {/* Draft recovery banner */}
      {hasDraft && (
        <div className="mb-5 p-4 bg-blue-50 border border-blue-200 rounded-xl flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <svg className="w-5 h-5 text-blue-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" /></svg>
            <span className="text-sm font-medium text-blue-700">前回の下書きがあります</span>
          </div>
          <div className="flex gap-2">
            <button onClick={restoreDraft} className="px-3 py-1.5 text-sm font-medium text-blue-700 bg-blue-100 rounded-lg hover:bg-blue-200 transition-colors">復元する</button>
            <button onClick={discardDraft} className="px-3 py-1.5 text-sm font-medium text-gray-500 hover:text-gray-700 transition-colors">破棄</button>
          </div>
        </div>
      )}

      {/* Error banner */}
      {Object.keys(errors).length > 0 && (
        <div className="mb-5 p-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl">
          <div className="flex items-center gap-2 font-bold mb-1">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>
            入力内容を確認してください
          </div>
          <ul className="list-disc list-inside space-y-0.5">
            {Object.values(errors).map((msg, i) => <li key={i}>{msg}</li>)}
          </ul>
        </div>
      )}

      <div className="space-y-5">
        {/* ===== Template Selector ===== */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {templates.map((t) => (
            <button key={t.id} type="button" onClick={() => applyTemplate(t.id)}
              className={`p-4 rounded-xl border-2 text-left transition-all ${
                selectedTemplate === t.id
                  ? "border-primary bg-primary/5 shadow-sm"
                  : "border-gray-200 bg-white hover:border-primary/30"
              }`}>
              <div className={`w-8 h-8 rounded-lg flex items-center justify-center mb-2 ${
                selectedTemplate === t.id ? "bg-primary text-white" : "bg-gray-100 text-gray-400"
              }`}>
                {t.id === "custom" ? (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" /></svg>
                ) : t.id === "small8" ? (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>
                ) : t.id === "large24" ? (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" /></svg>
                ) : (
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172" /></svg>
                )}
              </div>
              <p className={`text-sm font-bold ${selectedTemplate === t.id ? "text-primary" : "text-foreground"}`}>{t.name}</p>
              <p className="text-[11px] text-muted mt-0.5 leading-tight">{t.desc}</p>
              {t.teams && <p className="text-[10px] text-primary/70 font-medium mt-1">{t.teams}</p>}
            </button>
          ))}
        </div>

        {/* ===== 1. 基本情報 ===== */}
        <Section title="基本情報" num={1} hint="大会名と日程を入力しましょう">
          <div className="space-y-4">
            <Field label="大会名" required error={errors.title}>
              <input type="text" value={title} onChange={(e) => { setTitle(e.target.value); setErrors(prev => { const n = {...prev}; delete n.title; return n; }); }}
                className={`input-field ${errors.title ? "border-red-300 focus:ring-red-200" : ""}`} placeholder="例: 第1回 ソフトバレーボール大会" />
            </Field>

            <div className="grid grid-cols-2 gap-4">
              <Field label="開催日" required error={errors.date}>
                <input type="date" value={date} onChange={(e) => { setDate(e.target.value); setErrors(prev => { const n = {...prev}; delete n.date; return n; }); }}
                  className={`input-field ${errors.date ? "border-red-300 focus:ring-red-200" : ""}`} />
              </Field>
              <Field label="エントリー締切" warning={deadlineWarning} error={errors.deadline}>
                <input type="date" value={deadline} onChange={(e) => { setDeadline(e.target.value); setErrors(prev => { const n = {...prev}; delete n.deadline; return n; }); }}
                  className={`input-field ${errors.deadline ? "border-red-300 focus:ring-red-200" : deadlineWarning ? "border-amber-300" : ""}`} />
              </Field>
            </div>

            <Field label="種別">
              <Chips options={["メンズ", "レディース", "混合"]} value={type} onChange={setType} />
            </Field>

            <Field label="大会説明・備考" hint="参加者への注意事項やアピールを自由に記入">
              <textarea value={description} onChange={(e) => setDescription(e.target.value)}
                className="input-field resize-none" rows={3} placeholder="例: 初心者歓迎の親睦大会です。お昼はお弁当を各自ご持参ください。" />
            </Field>

            <Field label="ルールPDF（任意）" hint="大会要項やルールのPDFをアップロードできます">
              {pdfFile ? (
                <div className="flex items-center gap-3 px-4 py-3 bg-green-50 border border-green-200 rounded-xl">
                  <svg className="w-6 h-6 text-red-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" /></svg>
                  <span className="text-sm font-medium text-foreground truncate flex-1">{pdfFile.name}</span>
                  <button type="button" onClick={() => setPdfFile(null)} className="text-gray-400 hover:text-gray-600 transition-colors">
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </div>
              ) : (
                <label className="flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed border-gray-300 rounded-xl cursor-pointer hover:border-primary hover:bg-primary/5 transition-colors">
                  <svg className="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" /></svg>
                  <span className="text-sm text-muted">PDFを選択（10MBまで）</span>
                  <input type="file" accept=".pdf" className="hidden" onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      if (file.size > 10 * 1024 * 1024) {
                        setErrors(prev => ({ ...prev, pdf: "ファイルサイズは10MB以下にしてください" }));
                        return;
                      }
                      setErrors(prev => { const n = { ...prev }; delete n.pdf; return n; });
                      setPdfFile(file);
                    }
                  }} />
                </label>
              )}
              {errors.pdf && <p className="text-xs text-red-500 mt-1">{errors.pdf}</p>}
            </Field>
          </div>
        </Section>

        {/* ===== 2. 会場 ===== */}
        <Section title="会場" num={2} hint="登録済み会場から選択するか、直接入力できます">
          <div className="space-y-4">
            <Field label="会場名" required error={errors.location}>
              <div ref={venueRef} className="relative">
                <div className="relative">
                  <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
                  <input type="text" value={location}
                    onChange={(e) => { setLocation(e.target.value); setSelectedVenueId(""); setShowVenuePicker(true); setErrors(prev => { const n = {...prev}; delete n.location; return n; }); }}
                    onFocus={() => setShowVenuePicker(true)}
                    className={`input-field pl-11 ${errors.location ? "border-red-300 focus:ring-red-200" : ""}`} placeholder="会場名を検索・入力..." />
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
        <Section title="チーム設定" num={3} hint="チーム数とコート数を設定します">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <Field label="最大チーム数" error={errors.maxTeams}>
              <input type="number" value={maxTeams} onChange={(e) => { setMaxTeams(parseInt(e.target.value) || 0); setErrors(prev => { const n = {...prev}; delete n.maxTeams; return n; }); }}
                min={2} className={`input-field text-center ${errors.maxTeams ? "border-red-300" : ""}`} />
            </Field>
            <Field label="コート数" error={errors.courts} warning={courtsVsTeamsWarning}>
              <input type="number" value={courts} onChange={(e) => { setCourts(parseInt(e.target.value) || 0); setErrors(prev => { const n = {...prev}; delete n.courts; return n; }); }}
                min={1} className={`input-field text-center ${errors.courts ? "border-red-300" : courtsVsTeamsWarning ? "border-amber-300" : ""}`} />
            </Field>
            <Field label="チーム/コート" hint="自動計算">
              <div className="input-field bg-gray-50 text-center flex items-center justify-center gap-2 cursor-default">
                <span className="font-bold text-foreground">{courts > 0 ? Math.ceil(maxTeams / courts) : "-"}</span>
                <span className="text-[10px] text-primary bg-primary/10 px-1.5 py-0.5 rounded-full font-medium">自動</span>
              </div>
            </Field>
            <Field label="参加費">
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-muted text-sm font-medium">¥</span>
                <input type="number" value={entryFee} onChange={(e) => setEntryFee(parseInt(e.target.value) || 0)} min={0} step={500}
                  className="input-field pl-7 text-center" />
              </div>
              {entryFee > 0 && <p className="text-xs text-primary font-medium mt-1 text-center">¥{entryFee.toLocaleString()}</p>}
            </Field>
          </div>
          <Field label="大会形式" hint="参加者に伝わる形式名を入力">
            <input type="text" value={format} onChange={(e) => setFormat(e.target.value)} className="input-field" placeholder="例: 予選リーグ+決勝トーナメント" />
          </Field>
        </Section>

        {/* ===== 4. ルール設定 (Collapsible) ===== */}
        <CollapsibleSection title="ルール設定" num={4} open={showRules} onToggle={() => setShowRules(!showRules)}
          summary={`予選: ${setsLabel(prelSets)} / 決勝: ${setsLabel(finalSets)} / 昼休憩: ${lunchBreak}`}>
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
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <Field label="開場"><input type="time" value={openTime} onChange={(e) => setOpenTime(e.target.value)} className="input-field" /></Field>
              <Field label="受付"><input type="time" value={receptionTime} onChange={(e) => setReceptionTime(e.target.value)} className="input-field" /></Field>
              <Field label="開会式"><input type="time" value={ceremonyTime} onChange={(e) => setCeremonyTime(e.target.value)} className="input-field" /></Field>
              <Field label="試合開始"><input type="time" value={matchStartTime} onChange={(e) => setMatchStartTime(e.target.value)} className="input-field" /></Field>
              {lunchBreak !== "なし" && <Field label="昼休憩"><input type="time" value={lunchTime} onChange={(e) => setLunchTime(e.target.value)} className="input-field" /></Field>}
              {finalEnabled && <Field label="決勝"><input type="time" value={finalsTime} onChange={(e) => setFinalsTime(e.target.value)} className="input-field" /></Field>}
              <Field label="閉会・片付け"><input type="time" value={closingTime} onChange={(e) => setClosingTime(e.target.value)} className="input-field" /></Field>
            </div>
            {scheduleWarnings.length > 0 && (
              <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl">
                <div className="flex items-center gap-2 text-amber-700 text-xs font-bold mb-1">
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>
                  時間の順序を確認してください
                </div>
                {scheduleWarnings.map((w, i) => <p key={i} className="text-xs text-amber-600">{w}</p>)}
              </div>
            )}
          </div>
        </CollapsibleSection>

        {/* ===== Submit ===== */}
        <div className="bg-white rounded-2xl border border-gray-200 p-6 mt-2">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-bold text-foreground">準備ができたら作成しましょう</p>
              <p className="text-xs text-muted mt-0.5">ルールとスケジュールは後から変更できます</p>
            </div>
            <div className="flex items-center gap-3">
              <button onClick={() => setShowPreview(true)} type="button"
                className="px-5 py-3 text-sm font-medium text-muted border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
                プレビュー
              </button>
              <button onClick={handleSubmit} disabled={submitting}
                className="btn-accent px-8 py-3 text-base">
                {submitting ? (
                  <><div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" /> 作成中...</>
                ) : "大会を作成"}
              </button>
            </div>
          </div>
          <p className="text-[11px] text-hint mt-3 flex items-center gap-1">
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" /></svg>
            入力内容は自動保存されます
          </p>
        </div>
      </div>

      {/* ===== Preview Modal ===== */}
      {showPreview && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4" onClick={() => setShowPreview(false)}>
          <div className="bg-white rounded-2xl w-full max-w-[560px] max-h-[85vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            {/* Preview Header */}
            <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white rounded-t-2xl z-10">
              <h3 className="text-base font-bold text-foreground">プレビュー</h3>
              <button onClick={() => setShowPreview(false)} className="w-8 h-8 flex items-center justify-center rounded-lg hover:bg-gray-100 transition-colors text-muted">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            {/* Preview Content */}
            <div className="p-6 space-y-5">
              {/* Hero */}
              <div className="gradient-navy rounded-xl p-5 text-white">
                <div className="flex items-center gap-2 mb-3">
                  <span className="px-2.5 py-0.5 bg-green-500/20 text-green-300 text-xs font-bold rounded-full">募集中</span>
                  <span className="px-2.5 py-0.5 bg-white/15 text-white/80 text-xs font-medium rounded-full">{type}</span>
                </div>
                <h2 className="text-lg font-bold mb-3">{title || "（大会名未入力）"}</h2>
                <div className="space-y-1.5 text-sm text-white/70">
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4 text-white/40" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>
                    <span>{date || "未設定"}</span>
                    {deadline && <span className="text-amber-300 text-xs ml-2">(締切: {deadline})</span>}
                  </div>
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4 text-white/40" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    <span>{location || "未設定"}</span>
                  </div>
                </div>
              </div>

              {/* Stats */}
              <div className="grid grid-cols-3 gap-3">
                <div className="text-center p-3 bg-blue-50 rounded-xl">
                  <p className="text-lg font-bold text-blue-700">{maxTeams}</p>
                  <p className="text-[11px] text-blue-500">チーム</p>
                </div>
                <div className="text-center p-3 bg-green-50 rounded-xl">
                  <p className="text-lg font-bold text-green-700">{courts}</p>
                  <p className="text-[11px] text-green-500">コート</p>
                </div>
                <div className="text-center p-3 bg-amber-50 rounded-xl">
                  <p className="text-lg font-bold text-amber-700">{entryFee > 0 ? `¥${entryFee.toLocaleString()}` : "無料"}</p>
                  <p className="text-[11px] text-amber-500">参加費</p>
                </div>
              </div>

              {/* Description */}
              {description && (
                <div className="p-3 bg-gray-50 rounded-xl">
                  <p className="text-xs font-medium text-muted mb-1">大会説明</p>
                  <p className="text-sm text-foreground whitespace-pre-wrap">{description}</p>
                </div>
              )}

              {/* Rules */}
              <div>
                <h4 className="text-xs font-bold text-muted uppercase mb-2">ルール</h4>
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between px-3 py-2 bg-gray-50 rounded-lg text-sm">
                    <span className="text-muted">予選</span>
                    <span className="font-medium text-foreground">
                      {prelRounds > 1 && `${prelRounds}R / `}{setsLabel(prelSets)} / {prelDeuce ? `デュースあり(${prelDeuceCap}点)` : "デュースなし"}
                    </span>
                  </div>
                  {finalEnabled && (
                    <div className="flex items-center justify-between px-3 py-2 bg-gray-50 rounded-lg text-sm">
                      <span className="text-muted">決勝</span>
                      <span className="font-medium text-foreground">
                        {setsLabel(finalSets)} / {finalDeuce ? `デュースあり(${finalDeuceCap}点)` : "デュースなし"}
                      </span>
                    </div>
                  )}
                  <div className="flex items-center justify-between px-3 py-2 bg-gray-50 rounded-lg text-sm">
                    <span className="text-muted">昼休憩</span>
                    <span className="font-medium text-foreground">{lunchBreak}</span>
                  </div>
                </div>
              </div>

              {/* Schedule */}
              {hasSchedule && (
                <div>
                  <h4 className="text-xs font-bold text-muted uppercase mb-2">スケジュール</h4>
                  <div className="space-y-1">
                    {openTime && <PreviewScheduleRow time={openTime} label="開場" />}
                    {receptionTime && <PreviewScheduleRow time={receptionTime} label="受付" />}
                    {ceremonyTime && <PreviewScheduleRow time={ceremonyTime} label="開会式" />}
                    {matchStartTime && <PreviewScheduleRow time={matchStartTime} label="試合開始" />}
                    {lunchTime && <PreviewScheduleRow time={lunchTime} label="昼休憩" />}
                    {finalsTime && <PreviewScheduleRow time={finalsTime} label="決勝" />}
                    {closingTime && <PreviewScheduleRow time={closingTime} label="閉会" />}
                  </div>
                </div>
              )}
            </div>

            {/* Preview Footer */}
            <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-end gap-3 sticky bottom-0 bg-white rounded-b-2xl">
              <button onClick={() => setShowPreview(false)}
                className="px-5 py-2.5 text-sm font-medium text-muted border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
                戻って編集
              </button>
              <button onClick={() => { setShowPreview(false); handleSubmit(); }} disabled={submitting}
                className="btn-accent px-6 py-2.5 text-sm">
                {submitting ? "作成中..." : "大会を作成"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ==============================
   Shared Components
   ============================== */

function Section({ title, num, hint, children }: { title: string; num: number; hint?: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-200">
      <div className="px-6 py-3.5 border-b border-gray-100 bg-gray-50/50 flex items-center gap-3 rounded-t-2xl">
        <span className="w-7 h-7 rounded-lg bg-primary text-white text-xs font-bold flex items-center justify-center">{num}</span>
        <div>
          <h2 className="text-base font-bold text-foreground">{title}</h2>
          {hint && <p className="text-[11px] text-muted mt-0.5">{hint}</p>}
        </div>
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

function Field({ label, required, hint, error, warning, children }: {
  label: string; required?: boolean; hint?: string; error?: string; warning?: string; children: React.ReactNode;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-foreground mb-1.5">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {hint && <p className="text-xs text-muted mb-1.5">{hint}</p>}
      {children}
      {error && (
        <p className="text-xs text-red-500 mt-1 flex items-center gap-1">
          <svg className="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>
          {error}
        </p>
      )}
      {warning && !error && (
        <p className="text-xs text-amber-600 mt-1 flex items-center gap-1">
          <svg className="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>
          {warning}
        </p>
      )}
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

function PreviewScheduleRow({ time, label }: { time: string; label: string }) {
  return (
    <div className="flex items-center gap-3 py-1.5">
      <span className="text-sm font-mono font-bold text-primary w-12 text-center">{time}</span>
      <span className="text-sm text-foreground">{label}</span>
    </div>
  );
}
