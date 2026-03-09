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

// Badge SVG icons matching mobile app (flag, trophy, medal, star, diamond, devices, people)
const badgeSvgs: Record<string, React.ReactNode> = {
  flag: <path strokeLinecap="round" strokeLinejoin="round" d="M3 3v1.5M3 21v-6m0 0l2.77-.693a9 9 0 016.208.682l.108.054a9 9 0 006.086.71l3.114-.732a48.524 48.524 0 01-.005-10.499l-3.11.732a9 9 0 01-6.085-.711l-.108-.054a9 9 0 00-6.208-.682L3 4.5M3 15V4.5" />,
  trophy: <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772" />,
  medal: <><path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></>,
  star: <path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" />,
  diamond: <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />,
  devices: <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />,
  people: <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />,
};

const BADGE_DEFS = [
  { id: "first_tournament", name: "初参加", svgKey: "flag", color: "text-green-600", threshold: 1, field: "tournamentsPlayed" as const },
  { id: "5_tournaments", name: "5大会参加", svgKey: "trophy", color: "text-blue-600", threshold: 5, field: "tournamentsPlayed" as const },
  { id: "10_tournaments", name: "10大会参加", svgKey: "trophy", color: "text-purple-600", threshold: 10, field: "tournamentsPlayed" as const },
  { id: "first_champion", name: "初優勝", svgKey: "medal", color: "text-amber-500", threshold: 1, field: "championships" as const },
  { id: "3_champions", name: "3回優勝", svgKey: "medal", color: "text-amber-600", threshold: 3, field: "championships" as const },
  { id: "100_pts", name: "100Pt達成", svgKey: "star", color: "text-red-500", threshold: 100, field: "totalPoints" as const },
  { id: "500_pts", name: "500Pt達成", svgKey: "star", color: "text-amber-500", threshold: 500, field: "totalPoints" as const },
  { id: "1000_pts", name: "1000Pt達成", svgKey: "diamond", color: "text-cyan-500", threshold: 1000, field: "totalPoints" as const },
  { id: "5_gadgets", name: "ガジェット5個", svgKey: "devices", color: "text-pink-500", threshold: 5, field: "gadgetCount" as const },
  { id: "10_followers", name: "フォロワー10", svgKey: "people", color: "text-indigo-500", threshold: 10, field: "followersCount" as const },
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
              <Link href={`/profile/${user.uid}?tab=followers`} className="flex items-center gap-1.5 hover:opacity-70 transition-opacity">
                <svg className="w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>
                <span className="text-sm font-bold text-foreground">{profile.followersCount ?? 0}</span>
                <span className="text-xs text-muted">フォロワー</span>
              </Link>
              <Link href={`/profile/${user.uid}?tab=following`} className="flex items-center gap-1.5 hover:opacity-70 transition-opacity">
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
                  <svg className="w-4 h-4 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-4.5A3.375 3.375 0 0012.75 10.5h-.75m-6 8.25a3 3 0 01-3-3V6.75m0 0A2.25 2.25 0 015.25 4.5h13.5A2.25 2.25 0 0121 6.75m-18 0v10.5" /></svg>
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
                      <svg className={`w-6 h-6 ${earned ? b.color : "text-gray-400"}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>{badgeSvgs[b.svgKey]}</svg>
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
                  <svg className="w-4 h-4 text-purple-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" /></svg>
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
                  <svg className="w-4 h-4 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
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
              <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M16.5 18.75h-9m9 0a3 3 0 013 3h-15a3 3 0 013-3m9 0v-3.375c0-.621-.503-1.125-1.125-1.125h-.871M7.5 18.75v-3.375c0-.621.504-1.125 1.125-1.125h.872m5.007 0H9.497m5.007 0a7.454 7.454 0 01-.982-3.172M9.497 14.25a7.454 7.454 0 00.981-3.172M5.25 4.236c-.982.143-1.954.317-2.916.52A6.003 6.003 0 007.73 9.728M5.25 4.236V4.5c0 2.108.966 3.99 2.48 5.228M5.25 4.236V2.721C7.456 2.41 9.71 2.25 12 2.25c2.291 0 4.545.16 6.75.47v1.516M18.75 4.236c.982.143 1.954.317 2.916.52A6.003 6.003 0 0016.27 9.728M18.75 4.236V4.5c0 2.108-.966 3.99-2.48 5.228m0 0a6.003 6.003 0 01-4.52 1.772 6.003 6.003 0 01-4.52-1.772" /></svg>
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
  const fillPct = t.maxTeams > 0 ? Math.min(100, ((t.currentTeams ?? 0) / t.maxTeams) * 100) : 0;
  const isFull = (t.currentTeams ?? 0) >= t.maxTeams;
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
        <div className="space-y-1.5 text-sm text-muted mb-3">
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
        <div className="flex items-center gap-3">
          <div className="flex-1 h-2 bg-gray-100 rounded-full overflow-hidden">
            <div className={`h-full rounded-full transition-all ${isFull ? "bg-red-400" : "bg-primary"}`} style={{ width: `${fillPct}%` }} />
          </div>
          <span className={`text-xs font-bold whitespace-nowrap ${isFull ? "text-red-500" : "text-foreground"}`}>
            {t.currentTeams ?? 0}/{t.maxTeams}
          </span>
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
