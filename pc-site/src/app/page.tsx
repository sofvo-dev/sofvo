"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  limit,
  where,
  getDocs,
  doc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Tournament } from "@/types/firestore";
import { useAuth } from "@/contexts/AuthContext";
import StatusBadge from "@/components/StatusBadge";
import Link from "next/link";

const typeColor: Record<string, string> = {
  "メンズ": "bg-blue-600",
  "レディース": "bg-pink-400",
  "混合": "bg-green-600",
};

interface Gadget {
  id: string;
  name: string;
  category?: string;
  imageUrl?: string;
  memo?: string;
}

interface PointHistory {
  id: string;
  tournamentId?: string;
  tournamentName?: string;
  points: number;
  reason?: string;
  createdAt?: unknown;
}

// Badge SVG icons matching mobile Material Design filled icons
const badgeSvgs: Record<string, React.ReactNode> = {
  flag: <path d="M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6h-5.6z" />,
  trophy: <path d="M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94.63 1.5 1.98 2.63 3.61 2.96V19H7v2h10v-2h-4v-3.1c1.63-.33 2.98-1.46 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z" />,
  medal: <path d="M17 10.43V2H7v8.43c0 .35.18.68.49.86l4.18 2.51-.99 2.34-3.41.29 2.59 2.24L9.07 22 12 20.23 14.93 22l-.79-3.33 2.59-2.24-3.41-.29-.99-2.34 4.18-2.51c.31-.18.49-.51.49-.86zM13 12.23l-1 .6-1-.6V3h2v9.23z" />,
  star: <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z" />,
  diamond: <path d="M19 3H5L2 9l10 12L22 9l-3-6zm-1.18 5h-3.09l-1.55-3.1L17.64 8zM6.36 8l3.46-3.1L8.27 8H6.36zM12 17.92L7.62 10h8.76L12 17.92z" />,
  devices: <><path d="M3 6h18V4H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h4v-2H3V6z" /><path d="M13 12.5h-3v1c0 1.1.9 2 2 2h6c1.1 0 2-.9 2-2v-3c0-1.1-.9-2-2-2h-5v4zm7-2.5v3h-6v-3h6z" /><path d="M24 6v11.5c0 .83-.67 1.5-1.5 1.5h-1V6h2.5z" /></>,
  people: <><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" /></>,
};

const BADGE_DEFS = [
  { id: "first_tournament", name: "初参加", svgKey: "flag", color: "text-[#4CAF50]", threshold: 1, field: "tournamentsPlayed" as const },
  { id: "5_tournaments", name: "5大会参加", svgKey: "trophy", color: "text-[#2196F3]", threshold: 5, field: "tournamentsPlayed" as const },
  { id: "10_tournaments", name: "10大会参加", svgKey: "trophy", color: "text-[#9C27B0]", threshold: 10, field: "tournamentsPlayed" as const },
  { id: "first_champion", name: "初優勝", svgKey: "medal", color: "text-[#FF9800]", threshold: 1, field: "championships" as const },
  { id: "3_champions", name: "3回優勝", svgKey: "medal", color: "text-[#F44336]", threshold: 3, field: "championships" as const },
  { id: "100_pts", name: "100Pt達成", svgKey: "star", color: "text-[#FFC107]", threshold: 100, field: "totalPoints" as const },
  { id: "500_pts", name: "500Pt達成", svgKey: "star", color: "text-[#FF5722]", threshold: 500, field: "totalPoints" as const },
  { id: "1000_pts", name: "1000Pt達成", svgKey: "diamond", color: "text-[#E91E63]", threshold: 1000, field: "totalPoints" as const },
  { id: "5_gadgets", name: "ガジェット5個", svgKey: "devices", color: "text-[#00BCD4]", threshold: 5, field: "gadgetCount" as const },
  { id: "10_followers", name: "フォロワー10", svgKey: "people", color: "text-[#795548]", threshold: 10, field: "followersCount" as const },
];

export default function HomePage() {
  const { user, profile } = useAuth();
  const [recentTournaments, setRecentTournaments] = useState<Tournament[]>([]);
  const [gadgets, setGadgets] = useState<Gadget[]>([]);
  const [pointHistory, setPointHistory] = useState<PointHistory[]>([]);
  const [loading, setLoading] = useState(true);

  // Fetch tournaments
  useEffect(() => {
    const q = query(collection(db, "tournaments"), orderBy("date", "desc"), limit(50));
    const unsub = onSnapshot(q, (snap) => {
      setRecentTournaments(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Tournament)));
      setLoading(false);
    });
    return () => unsub();
  }, []);

  // Fetch user's gadgets
  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, "users", user.uid, "gadgets"), orderBy("sortOrder", "asc"), limit(10));
    const unsub = onSnapshot(q, (snap) => {
      setGadgets(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Gadget)));
    }, () => {
      // If sortOrder field doesn't exist, try without it
      const q2 = query(collection(db, "users", user.uid, "gadgets"), limit(10));
      onSnapshot(q2, (snap) => {
        setGadgets(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Gadget)));
      });
    });
    return () => unsub();
  }, [user]);

  // Fetch point history
  useEffect(() => {
    if (!user) return;
    const q = query(collection(db, "users", user.uid, "pointHistory"), orderBy("createdAt", "desc"), limit(20));
    const unsub = onSnapshot(q, (snap) => {
      setPointHistory(snap.docs.map((d) => ({ id: d.id, ...d.data() } as PointHistory)));
    }, () => { /* no pointHistory collection yet */ });
    return () => unsub();
  }, [user]);

  // Separate tournaments by status
  const liveTournaments = recentTournaments.filter((t) => ["開催中", "決勝中"].includes(t.status));
  const finishedTournaments = recentTournaments.filter((t) => t.status === "終了").slice(0, 6);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Badge calculation
  const badgeValues = {
    tournamentsPlayed: profile?.stats?.tournamentsPlayed ?? 0,
    championships: profile?.stats?.championships ?? 0,
    totalPoints: profile?.totalPoints ?? 0,
    gadgetCount: profile?.gadgetCount ?? gadgets.length,
    followersCount: profile?.followersCount ?? 0,
  };
  const earnedBadges = BADGE_DEFS.filter((b) => badgeValues[b.field] >= b.threshold);

  return (
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">

      {/* ===== Profile Header (logged in) ===== */}
      {user && profile ? (
        <>
          <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
            <div className="gradient-navy px-8 pt-6 pb-14 relative">
              <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
              <div className="absolute bottom-[-25px] left-[30%] w-32 h-32 rounded-full bg-white/5" />
              <div className="flex items-center gap-5 relative z-10">
                <div className="w-16 h-16 rounded-2xl bg-white/15 flex items-center justify-center text-white font-bold text-2xl overflow-hidden ring-[3px] ring-white/30 shadow-lg">
                  {profile.avatarUrl ? (
                    <img src={profile.avatarUrl} alt="" className="w-16 h-16 object-cover" />
                  ) : (
                    profile.nickname?.charAt(0) || "U"
                  )}
                </div>
                <div>
                  <h1 className="text-xl font-bold text-white">{profile.nickname}さん、おかえりなさい</h1>
                  {profile.searchId && (
                    <p className="text-sm text-white/50 mt-0.5">@{profile.searchId}</p>
                  )}
                </div>
              </div>
            </div>

            {/* Stats bar */}
            <div className="bg-white px-8 py-3 -mt-8 relative z-10 mx-6 rounded-xl border border-gray-200 shadow-sm flex items-center">
              <div className="flex items-center gap-5 flex-1">
                <StatItem label="シーズンPt" value={profile.seasonPoints ?? 0} color="text-accent" />
                <div className="w-px h-6 bg-gray-200" />
                <StatItem label="通算Pt" value={profile.totalPoints ?? 0} color="text-primary" />
                <div className="w-px h-6 bg-gray-200" />
                <StatItem label="大会参加" value={profile.stats?.tournamentsPlayed ?? 0} color="text-success" />
                <div className="w-px h-6 bg-gray-200" />
                <StatItem label="優勝" value={profile.stats?.championships ?? 0} color="text-accent" />
              </div>
              <Link href="/settings" className="text-xs text-muted hover:text-primary transition-colors flex items-center gap-1">
                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" /><path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                設定
              </Link>
            </div>

            {/* Followers / Following */}
            <div className="flex items-center gap-4 mx-6 mt-3 mb-1">
              <Link href={`/follows?uid=${user.uid}&tab=followers`} className="flex items-center gap-1.5 hover:opacity-70 transition-opacity">
                <svg className="w-4 h-4 text-muted" fill="currentColor" viewBox="0 0 24 24"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" /></svg>
                <span className="text-sm font-bold text-foreground">{profile.followersCount ?? 0}</span>
                <span className="text-xs text-muted">フォロワー</span>
              </Link>
              <Link href={`/follows?uid=${user.uid}&tab=following`} className="flex items-center gap-1.5 hover:opacity-70 transition-opacity">
                <span className="text-sm font-bold text-foreground">{profile.followingCount ?? 0}</span>
                <span className="text-xs text-muted">フォロー中</span>
              </Link>
            </div>
            <div className="h-2" />
          </div>

          {/* Quick Links */}
          <div className="grid grid-cols-4 lg:grid-cols-7 gap-2 mb-6">
            <QuickLink href="/tournaments/manage" label="大会管理" color="text-primary" bg="bg-primary/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15" />} />
            <QuickLink href="/tournaments/create" label="大会作成" color="text-accent" bg="bg-accent/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />} />
            <QuickLink href="/teams" label="チーム" color="text-green-600" bg="bg-green-500/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />} />
            <QuickLink href="/gadgets" label="ガジェット" color="text-purple-600" bg="bg-purple-500/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M20.25 14.15v4.25c0 1.094-.787 2.036-1.872 2.18-2.087.277-4.216.42-6.378.42s-4.291-.143-6.378-.42c-1.085-.144-1.872-1.086-1.872-2.18v-4.25m16.5 0a2.18 2.18 0 00.75-1.661V8.706c0-1.081-.768-2.015-1.837-2.175a48.114 48.114 0 00-3.413-.387m4.5 8.006c-.194.165-.42.295-.673.38A23.978 23.978 0 0112 15.75c-2.648 0-5.195-.429-7.577-1.22a2.016 2.016 0 01-.673-.38m0 0A2.18 2.18 0 013 12.489V8.706c0-1.081.768-2.015 1.837-2.175a48.111 48.111 0 013.413-.387m7.5 0V5.25A2.25 2.25 0 0013.5 3h-3a2.25 2.25 0 00-2.25 2.25v.894m7.5 0a48.667 48.667 0 00-7.5 0" />} />
            <QuickLink href="/badges" label="バッジ" color="text-amber-600" bg="bg-amber-500/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21a3.745 3.745 0 01-3.068-1.593 3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12a3.745 3.745 0 011.593-3.068 3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3a3.746 3.746 0 013.068 1.593 3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />} />
            <QuickLink href="/bookmarks" label="ブックマーク" color="text-blue-600" bg="bg-blue-500/8"
              icon={<path strokeLinecap="round" strokeLinejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z" />} />
            <QuickLink href="/rankings" label="ランキング" color="text-red-600" bg="bg-red-500/8"
              icon={<><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" /></>} />
          </div>

          {/* Two-column layout for badges & gadgets */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-6">
            {/* Badges */}
            <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
                <h2 className="text-sm font-bold text-foreground flex items-center gap-2">
                  <svg className="w-4 h-4 text-amber-500" fill="currentColor" viewBox="0 0 24 24"><path d="M9.68 13.69L12 11.93l2.31 1.76-.88-2.85L15.75 9H12.91l-.91-2.95L11.09 9H8.25l2.31 1.84-.88 2.85zM20 2H4c-1.1 0-2 .9-2 2v15.59c0 .89 1.08 1.34 1.71.71L6 18h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z" /></svg>
                  バッジコレクション
                  <span className="text-xs text-muted font-normal">{earnedBadges.length}/{BADGE_DEFS.length}</span>
                </h2>
                <Link href="/badges" className="text-xs text-primary font-medium hover:underline">すべて見る</Link>
              </div>
              <div className="p-4 grid grid-cols-5 gap-2">
                {BADGE_DEFS.map((b) => {
                  const val = badgeValues[b.field];
                  const earned = val >= b.threshold;
                  return (
                    <div key={b.id} className={`flex flex-col items-center gap-1 p-2 rounded-lg ${earned ? "bg-amber-50" : "bg-gray-50 opacity-40"}`}>
                      <svg className={`w-6 h-6 ${earned ? b.color : "text-gray-400"}`} fill="currentColor" viewBox="0 0 24 24">{badgeSvgs[b.svgKey]}</svg>
                      <span className="text-[9px] font-medium text-center leading-tight truncate w-full">{b.name}</span>
                      {!earned && <span className="text-[8px] text-muted">{val}/{b.threshold}</span>}
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Gadgets */}
            <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
                <h2 className="text-sm font-bold text-foreground flex items-center gap-2">
                  <svg className="w-4 h-4 text-purple-500" fill="currentColor" viewBox="0 0 24 24"><path d="M3 6h18V4H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h4v-2H3V6z" /><path d="M13 12.5h-3v1c0 1.1.9 2 2 2h6c1.1 0 2-.9 2-2v-3c0-1.1-.9-2-2-2h-5v4zm7-2.5v3h-6v-3h6z" /><path d="M24 6v11.5c0 .83-.67 1.5-1.5 1.5h-1V6h2.5z" /></svg>
                  マイガジェット
                </h2>
                <Link href="/gadgets" className="text-xs text-primary font-medium hover:underline">すべて見る</Link>
              </div>
              {gadgets.length === 0 ? (
                <div className="p-6 text-center">
                  <p className="text-sm text-muted mb-3">ガジェットを登録しよう</p>
                  <Link href="/gadgets/register" className="text-xs text-primary font-medium hover:underline">登録する</Link>
                </div>
              ) : (
                <div className="p-4 flex gap-3 overflow-x-auto">
                  {gadgets.map((g) => (
                    <Link key={g.id} href="/gadgets" className="flex-shrink-0 w-24 text-center group">
                      <div className="w-24 h-24 rounded-lg bg-gray-100 mb-1.5 overflow-hidden flex items-center justify-center">
                        {g.imageUrl ? (
                          <img src={g.imageUrl} alt={g.name} className="w-full h-full object-cover" />
                        ) : (
                          <svg className="w-8 h-8 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5" /></svg>
                        )}
                      </div>
                      <span className="text-[10px] font-medium text-foreground truncate block group-hover:text-primary transition-colors">{g.name}</span>
                      {g.category && <span className="text-[9px] text-muted">{g.category}</span>}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Point History */}
          {pointHistory.length > 0 && (
            <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
              <div className="flex items-center justify-between px-5 py-3 border-b border-gray-100">
                <h2 className="text-sm font-bold text-foreground flex items-center gap-2">
                  <svg className="w-4 h-4 text-accent" fill="currentColor" viewBox="0 0 24 24"><path d="M13 3a9 9 0 00-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0013 21a9 9 0 000-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z" /></svg>
                  ポイント履歴
                </h2>
              </div>
              <div className="divide-y divide-gray-50">
                {pointHistory.slice(0, 5).map((p) => (
                  <div key={p.id} className="px-5 py-2.5 flex items-center justify-between">
                    <div>
                      <span className="text-sm text-foreground">{p.tournamentName || p.reason || "ポイント付与"}</span>
                    </div>
                    <span className={`text-sm font-bold ${p.points > 0 ? "text-success" : "text-error"}`}>
                      {p.points > 0 ? "+" : ""}{p.points} pt
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

        </>
      ) : (
        /* ===== Hero Banner (not logged in) ===== */
        <div className="gradient-navy rounded-xl p-8 pb-10 mb-6 text-white relative overflow-hidden">
          <div className="absolute top-[-40px] right-[-40px] w-48 h-48 rounded-full bg-white/5" />
          <div className="absolute bottom-[-30px] left-[20%] w-32 h-32 rounded-full bg-white/5" />
          <div className="relative z-10">
            <h1 className="text-2xl font-bold mb-1">Sofvo</h1>
            <p className="text-white/60 text-sm mb-6">ソフトバレーボール大会管理プラットフォーム</p>
            <div className="flex gap-3">
              <Link href="/tournaments" className="inline-flex items-center gap-2 px-5 py-2.5 bg-white text-primary rounded-xl text-sm font-semibold hover:bg-white/90 transition-colors">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
                大会を探す
              </Link>
              <Link href="/login" className="inline-flex items-center gap-2 px-5 py-2.5 bg-accent text-white rounded-xl text-sm font-semibold hover:bg-[#B89B52] transition-colors">
                ログイン
              </Link>
            </div>
          </div>
        </div>
      )}

      {/* ===== Live Tournaments ===== */}
      {liveTournaments.length > 0 && (
        <section className="mb-6">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-bold text-foreground flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-success animate-pulse" />
              開催中の大会
            </h2>
            <Link href="/tournaments" className="text-xs text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {liveTournaments.map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* ===== Recent Tournaments ===== */}
      {finishedTournaments.length > 0 && (
        <section className="mb-6">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-sm font-bold text-foreground flex items-center gap-2">
              <svg className="w-4 h-4 text-primary" fill="currentColor" viewBox="0 0 24 24"><path d="M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94.63 1.5 1.98 2.63 3.61 2.96V19H7v2h10v-2h-4v-3.1c1.63-.33 2.98-1.46 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z" /></svg>
              最近の大会
            </h2>
            <Link href="/tournaments" className="text-xs text-primary font-medium hover:underline">すべて見る</Link>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {finishedTournaments.map((t) => (
              <TournamentCard key={t.id} tournament={t} />
            ))}
          </div>
        </section>
      )}

      {/* Empty state */}
      {recentTournaments.length === 0 && (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-gray-50 flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497" /></svg>
          </div>
          <h3 className="text-lg font-bold text-foreground mb-2">大会がまだありません</h3>
          <p className="text-sm text-muted mb-6">大会を作成して、ソフトバレーを始めましょう</p>
          {user ? (
            <Link href="/tournaments/create" className="btn-primary">大会を作成する</Link>
          ) : (
            <Link href="/login" className="btn-primary">ログインして始める</Link>
          )}
        </div>
      )}
    </div>
  );
}

function StatItem({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="text-center">
      <div className={`text-lg font-bold ${color}`}>{value}</div>
      <div className="text-[11px] text-muted">{label}</div>
    </div>
  );
}

function TournamentCard({ tournament: t }: { tournament: Tournament }) {
  return (
    <Link href={`/tournament/${t.id}`} className="bg-white rounded-xl border border-gray-200 block group overflow-hidden hover:shadow-lg hover:border-primary/20 transition-all">
      <div className="gradient-navy px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-2 text-white text-sm font-medium">
          <svg className="w-3.5 h-3.5 text-white/60" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5" /></svg>
          {t.date}
        </div>
        <div className="flex items-center gap-1.5">
          <span className={`text-[10px] text-white px-2 py-0.5 rounded-full font-medium ${typeColor[t.type] ?? "bg-gray-500"}`}>{t.type}</span>
          <StatusBadge status={t.status} />
        </div>
      </div>
      <div className="p-4">
        <h3 className="text-base font-bold text-foreground group-hover:text-primary transition-colors line-clamp-1 mb-3">{t.title}</h3>
        <div className="space-y-1.5 text-sm text-muted">
          <div className="flex items-center gap-2">
            <svg className="w-3.5 h-3.5 text-primary/40 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
            <span className="truncate text-xs">{t.location}</span>
          </div>
          {t.organizerName && (
            <div className="flex items-center gap-2">
              <svg className="w-3.5 h-3.5 text-primary/40 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0" /></svg>
              <span className="text-xs">{t.organizerName}</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}

function QuickLink({ href, label, color, bg, icon }: { href: string; label: string; color: string; bg: string; icon: React.ReactNode }) {
  return (
    <Link href={href} className="bg-white rounded-xl border border-gray-200 flex flex-col items-center gap-2 p-3 group hover:shadow-md hover:border-primary/20 transition-all">
      <div className={`w-9 h-9 rounded-xl ${bg} flex items-center justify-center ${color} group-hover:scale-110 transition-transform`}>
        <svg className="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          {icon}
        </svg>
      </div>
      <span className="text-[11px] font-semibold text-foreground">{label}</span>
    </Link>
  );
}
