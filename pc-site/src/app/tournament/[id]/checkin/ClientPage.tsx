"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  setDoc,
  deleteDoc,
  getDoc,
  serverTimestamp,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { CheckIn, Entry } from "@/types/firestore";
import Link from "next/link";

function formatTime(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" });
}

export default function CheckinPage() {
  const params = useParams<{ id: string }>();
  const id = (params?.id ?? "") as string;
  const { user } = useAuth();
  const [tournamentTitle, setTournamentTitle] = useState("");
  const [organizerId, setOrganizerId] = useState("");
  const [entries, setEntries] = useState<(Entry & { id: string })[]>([]);
  const [checkins, setCheckins] = useState<Record<string, CheckIn>>({});
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");

  useEffect(() => {
    async function loadTournament() {
      const snap = await getDoc(doc(db, "tournaments", id));
      if (snap.exists()) {
        setOrganizerId(snap.data().organizerId ?? "");
        setTournamentTitle(snap.data().title ?? "");
      }
    }
    loadTournament();
  }, [id]);

  useEffect(() => {
    const q = query(collection(db, "tournaments", id, "entries"), orderBy("enteredAt", "asc"));
    const unsub = onSnapshot(q, (snap) => {
      setEntries(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Entry) })));
      setLoading(false);
    }, () => setLoading(false));
    return () => unsub();
  }, [id]);

  useEffect(() => {
    const unsub = onSnapshot(collection(db, "tournaments", id, "checkins"), (snap) => {
      const map: Record<string, CheckIn> = {};
      snap.docs.forEach((d) => { map[d.id] = d.data() as CheckIn; });
      setCheckins(map);
    }, () => {});
    return () => unsub();
  }, [id]);

  const isOrganizer = user?.uid === organizerId;

  const toggleCheckin = async (entry: Entry & { id: string }) => {
    const ref = doc(db, "tournaments", id, "checkins", entry.teamId);
    if (checkins[entry.teamId]) {
      await deleteDoc(ref);
    } else {
      await setDoc(ref, {
        teamId: entry.teamId,
        teamName: entry.teamName,
        checkedInAt: serverTimestamp(),
      });
    }
  };

  const filtered = entries.filter((e) => !search.trim() || e.teamName.toLowerCase().includes(search.toLowerCase()));
  const checkedCount = Object.keys(checkins).length;

  if (!isOrganizer) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">主催者のみが受付できます</p>
        <Link href={`/tournament/${id}`} className="inline-block mt-4 text-primary text-sm hover:underline">
          大会詳細に戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href={`/tournament/${id}`} className="hover:text-primary transition-colors">
          {tournamentTitle || "大会"}
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium">受付</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">受付（チェックイン）</h1>
      <p className="text-sm text-muted mb-6">
        到着したチームをチェックしてください ({checkedCount}/{entries.length})
      </p>

      <div className="relative mb-4">
        <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
        </svg>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="チーム名で検索"
          className="w-full pl-10 pr-4 py-2.5 text-sm bg-white border border-gray-200 rounded-xl focus:outline-none focus:border-primary"
        />
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">該当するチームがありません</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden divide-y divide-gray-100">
          {filtered.map((entry) => {
            const checked = !!checkins[entry.teamId];
            return (
              <div key={entry.id} className="flex items-center gap-3 px-5 py-3">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${checked ? "bg-success/10 text-success" : "bg-gray-100 text-muted"}`}>
                  {checked ? (
                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.704 5.292a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-3-3a1 1 0 111.414-1.414L9 11.586l6.293-6.294a1 1 0 011.411 0z" clipRule="evenodd" />
                    </svg>
                  ) : (
                    <span className="text-xs font-bold">{entry.teamName.charAt(0)}</span>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className={`text-sm font-medium truncate ${checked ? "text-muted line-through" : "text-foreground"}`}>
                    {entry.teamName}
                  </div>
                  {checked && (
                    <div className="text-xs text-success">
                      受付済 {formatTime(checkins[entry.teamId].checkedInAt)}
                    </div>
                  )}
                </div>
                <button
                  onClick={() => toggleCheckin(entry)}
                  className={`px-4 py-1.5 text-xs font-semibold rounded-lg transition-colors flex-shrink-0 ${
                    checked
                      ? "bg-gray-100 text-muted hover:bg-gray-200"
                      : "bg-primary text-white hover:bg-primary-dark"
                  }`}
                >
                  {checked ? "取消" : "受付"}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
