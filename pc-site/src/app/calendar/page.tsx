"use client";

import { useEffect, useState, useMemo } from "react";
import { collection, query, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Tournament } from "@/types/firestore";
import Link from "next/link";

const DAY_LABELS = ["日", "月", "火", "水", "木", "金", "土"];

function getStatusColor(status: string): string {
  switch (status) {
    case "募集中":
      return "bg-green-100 text-green-700";
    case "開催中":
      return "bg-blue-100 text-blue-700";
    case "終了":
      return "bg-gray-100 text-gray-500";
    case "準備中":
      return "bg-yellow-100 text-yellow-700";
    case "決勝中":
      return "bg-purple-100 text-purple-700";
    default:
      return "bg-gray-100 text-gray-500";
  }
}

function isSameDay(d1: Date, d2: Date): boolean {
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}

function parseDate(dateStr: string): Date | null {
  // Handle formats like "2026-02-28", "2026/02/28", "2026年2月28日"
  const cleaned = dateStr.replace(/年|月/g, "-").replace(/日/g, "");
  const d = new Date(cleaned);
  if (isNaN(d.getTime())) return null;
  return d;
}

export default function CalendarPage() {
  const { user } = useAuth();
  const [tournaments, setTournaments] = useState<Tournament[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentMonth, setCurrentMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [selectedDate, setSelectedDate] = useState<Date>(new Date());

  useEffect(() => {
    async function loadTournaments() {
      const q = query(collection(db, "tournaments"));
      const snap = await getDocs(q);
      const all = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as Tournament)
      );

      if (user) {
        // Show tournaments where user is organizer or has entry
        const userTournaments: Tournament[] = [];
        for (const t of all) {
          if (t.organizerId === user.uid) {
            userTournaments.push(t);
            continue;
          }
          // Check entries subcollection
          const entriesSnap = await getDocs(
            collection(db, "tournaments", t.id, "entries")
          );
          const hasEntry = entriesSnap.docs.some((e) => {
            const data = e.data();
            return (
              data.enteredBy === user.uid ||
              (data.memberUids && data.memberUids.includes(user.uid))
            );
          });
          if (hasEntry) {
            userTournaments.push(t);
          }
        }
        setTournaments(userTournaments);
      } else {
        setTournaments(all);
      }

      setLoading(false);
    }
    loadTournaments();
  }, [user]);

  const today = new Date();

  // Calendar grid data
  const calendarDays = useMemo(() => {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const startOffset = firstDay.getDay(); // 0=Sunday
    const totalDays = lastDay.getDate();

    const days: (Date | null)[] = [];

    // Leading empty days
    for (let i = 0; i < startOffset; i++) {
      days.push(null);
    }

    // Actual days
    for (let d = 1; d <= totalDays; d++) {
      days.push(new Date(year, month, d));
    }

    // Trailing empty days to fill 6 rows
    while (days.length < 42) {
      days.push(null);
    }

    return days;
  }, [currentMonth]);

  // Map: date string -> tournaments
  const tournamentsByDate = useMemo(() => {
    const map: Record<string, Tournament[]> = {};
    for (const t of tournaments) {
      const d = parseDate(t.date);
      if (!d) continue;
      const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
      if (!map[key]) map[key] = [];
      map[key].push(t);
    }
    return map;
  }, [tournaments]);

  const getTournamentsForDate = (date: Date): Tournament[] => {
    const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
    return tournamentsByDate[key] || [];
  };

  const selectedEvents = selectedDate ? getTournamentsForDate(selectedDate) : [];

  // Upcoming tournaments (next 5)
  const upcomingTournaments = useMemo(() => {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return tournaments
      .filter((t) => {
        const d = parseDate(t.date);
        return d && d >= now;
      })
      .sort((a, b) => {
        const da = parseDate(a.date);
        const db2 = parseDate(b.date);
        return (da?.getTime() ?? 0) - (db2?.getTime() ?? 0);
      })
      .slice(0, 5);
  }, [tournaments]);

  const goToPrevMonth = () => {
    setCurrentMonth(
      new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1)
    );
  };

  const goToNextMonth = () => {
    setCurrentMonth(
      new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1)
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-foreground">カレンダー</h1>
        <p className="text-sm text-muted mt-1">
          {user ? "参加・主催する大会のスケジュール" : "すべての大会のスケジュール"}
        </p>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Calendar */}
        <div className="col-span-2">
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            {/* Month navigation */}
            <div className="flex items-center justify-between mb-6">
              <button
                onClick={goToPrevMonth}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg className="w-5 h-5 text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                </svg>
              </button>
              <h2 className="text-lg font-bold text-foreground">
                {currentMonth.getFullYear()}年{currentMonth.getMonth() + 1}月
              </h2>
              <button
                onClick={goToNextMonth}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <svg className="w-5 h-5 text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                </svg>
              </button>
            </div>

            {/* Day headers */}
            <div className="grid grid-cols-7 mb-2">
              {DAY_LABELS.map((label, i) => (
                <div
                  key={label}
                  className={`text-center text-xs font-medium py-2 ${
                    i === 0 ? "text-red-500" : i === 6 ? "text-blue-500" : "text-muted"
                  }`}
                >
                  {label}
                </div>
              ))}
            </div>

            {/* Calendar grid */}
            <div className="grid grid-cols-7">
              {calendarDays.map((day, idx) => {
                if (!day) {
                  return <div key={`empty-${idx}`} className="h-14" />;
                }

                const isToday = isSameDay(day, today);
                const isSelected = selectedDate && isSameDay(day, selectedDate);
                const dayOfWeek = day.getDay();
                const hasTournaments = getTournamentsForDate(day).length > 0;

                return (
                  <button
                    key={`day-${day.getDate()}`}
                    onClick={() => setSelectedDate(day)}
                    className={`h-14 flex flex-col items-center justify-center rounded-lg transition-all relative ${
                      isSelected
                        ? "bg-primary/10 ring-2 ring-primary"
                        : isToday
                        ? "bg-primary text-white"
                        : "hover:bg-gray-50"
                    }`}
                  >
                    <span
                      className={`text-sm font-medium ${
                        isToday && !isSelected
                          ? "text-white"
                          : isSelected
                          ? "text-primary font-bold"
                          : dayOfWeek === 0
                          ? "text-red-500"
                          : dayOfWeek === 6
                          ? "text-blue-500"
                          : "text-foreground"
                      }`}
                    >
                      {day.getDate()}
                    </span>
                    {hasTournaments && (
                      <div
                        className={`w-1.5 h-1.5 rounded-full mt-0.5 ${
                          isToday && !isSelected ? "bg-white" : "bg-primary"
                        }`}
                      />
                    )}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Selected date events */}
          <div className="mt-6">
            <h3 className="text-base font-bold text-foreground mb-3">
              {selectedDate
                ? `${selectedDate.getMonth() + 1}月${selectedDate.getDate()}日の大会`
                : "日付を選択してください"}
            </h3>
            {selectedEvents.length === 0 ? (
              <div className="text-center py-10 bg-white rounded-xl border border-gray-200 text-muted text-sm">
                この日の大会はありません
              </div>
            ) : (
              <div className="space-y-3">
                {selectedEvents.map((t) => (
                  <Link
                    key={t.id}
                    href={`/tournament/${t.id}`}
                    className="flex items-center gap-4 bg-white rounded-xl border border-gray-200 p-4 hover:shadow-md hover:border-primary/30 transition-all group"
                  >
                    <div className="flex-1 min-w-0">
                      <h4 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">
                        {t.title}
                      </h4>
                      <span className="text-xs text-muted">{t.location}</span>
                    </div>
                    <span
                      className={`text-xs font-medium px-2.5 py-1 rounded-full flex-shrink-0 ${getStatusColor(
                        t.status
                      )}`}
                    >
                      {t.status}
                    </span>
                    <svg
                      className="w-4 h-4 text-muted group-hover:text-primary transition-colors flex-shrink-0"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                    </svg>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Sidebar: Upcoming */}
        <div>
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h3 className="text-base font-bold text-foreground mb-4">直近の大会</h3>
            {upcomingTournaments.length === 0 ? (
              <p className="text-sm text-muted text-center py-6">
                予定されている大会はありません
              </p>
            ) : (
              <div className="space-y-4">
                {upcomingTournaments.map((t) => {
                  const d = parseDate(t.date);
                  return (
                    <Link
                      key={t.id}
                      href={`/tournament/${t.id}`}
                      className="block p-3 rounded-lg hover:bg-gray-50 transition-colors group"
                    >
                      <div className="flex items-start gap-3">
                        <div className="flex-shrink-0 w-12 text-center">
                          <div className="text-xs text-muted">
                            {d ? `${d.getMonth() + 1}月` : ""}
                          </div>
                          <div className="text-lg font-bold text-foreground">
                            {d ? d.getDate() : ""}
                          </div>
                        </div>
                        <div className="flex-1 min-w-0">
                          <h4 className="text-sm font-bold text-foreground group-hover:text-primary transition-colors truncate">
                            {t.title}
                          </h4>
                          <p className="text-xs text-muted mt-0.5 truncate">
                            {t.location}
                          </p>
                          <span
                            className={`inline-block text-xs font-medium px-2 py-0.5 rounded-full mt-1.5 ${getStatusColor(
                              t.status
                            )}`}
                          >
                            {t.status}
                          </span>
                        </div>
                      </div>
                    </Link>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
