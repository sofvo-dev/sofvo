"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import {
  doc,
  getDoc,
  collection,
  getDocs,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import Link from "next/link";

interface Survey {
  id: string;
  title: string;
  description?: string;
  questions?: { q: string; type?: string }[];
  responseCount?: number;
  status?: string;
}

interface Response {
  id: string;
  userId?: string;
  userNickname?: string;
  answers?: string[];
  createdAt?: unknown;
}

function formatDate(ts: unknown): string {
  if (!ts) return "-";
  let d: Date | null = null;
  if (ts instanceof Timestamp) d = ts.toDate();
  else if (typeof ts === "object" && ts !== null && "seconds" in ts)
    d = new Date((ts as { seconds: number }).seconds * 1000);
  if (!d) return "-";
  return d.toLocaleString("ja-JP");
}

export default function SurveyResultsPage() {
  const params = useParams<{ id: string }>();
  const id = (params?.id ?? "") as string;
  const [survey, setSurvey] = useState<Survey | null>(null);
  const [responses, setResponses] = useState<Response[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const [sSnap, rSnap] = await Promise.all([
        getDoc(doc(db, "surveys", id)),
        getDocs(collection(db, "surveys", id, "responses")).catch(() => null),
      ]);
      if (sSnap.exists()) {
        setSurvey({ id: sSnap.id, ...(sSnap.data() as Omit<Survey, "id">) });
      }
      if (rSnap) {
        setResponses(rSnap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Response, "id">) })));
      }
      setLoading(false);
    }
    load();
  }, [id]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!survey) {
    return (
      <div className="p-8 max-w-[900px] mx-auto text-center py-20">
        <p className="text-sm text-muted">アンケートが見つかりません</p>
        <Link href="/admin/surveys" className="inline-block mt-4 text-primary text-sm hover:underline">
          アンケート一覧
        </Link>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/admin/surveys" className="hover:text-primary transition-colors">
          アンケート
        </Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
        </svg>
        <span className="text-foreground font-medium truncate">{survey.title}</span>
      </nav>

      <h1 className="text-2xl font-bold text-foreground mb-1">{survey.title}</h1>
      {survey.description && <p className="text-sm text-muted mb-6">{survey.description}</p>}

      <div className="grid grid-cols-3 gap-3 mb-6">
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">設問数</div>
          <div className="text-xl font-bold text-foreground">{survey.questions?.length ?? 0}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">回答数</div>
          <div className="text-xl font-bold text-primary">{responses.length}</div>
        </div>
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-xs text-muted mb-1">ステータス</div>
          <div className="text-lg font-bold text-foreground">{survey.status ?? "-"}</div>
        </div>
      </div>

      {/* Per-question breakdown */}
      <div className="space-y-4 mb-6">
        {survey.questions?.map((q, qIdx) => {
          const answers = responses
            .map((r) => r.answers?.[qIdx])
            .filter((a): a is string => !!a && a.trim() !== "");

          // Count duplicates
          const counts = new Map<string, number>();
          answers.forEach((a) => counts.set(a, (counts.get(a) ?? 0) + 1));
          const sorted = Array.from(counts.entries()).sort((a, b) => b[1] - a[1]);

          return (
            <div key={qIdx} className="bg-white rounded-xl border border-gray-200 overflow-hidden">
              <div className="px-5 py-3 border-b border-gray-100 bg-gray-50/50">
                <div className="text-xs text-muted">設問 {qIdx + 1}</div>
                <div className="text-sm font-semibold text-foreground">{q.q}</div>
              </div>
              {sorted.length === 0 ? (
                <div className="p-5 text-sm text-muted text-center">回答がありません</div>
              ) : (
                <div className="divide-y divide-gray-50">
                  {sorted.slice(0, 20).map(([text, count]) => {
                    const pct = Math.round((count / answers.length) * 100);
                    return (
                      <div key={text} className="px-5 py-3">
                        <div className="flex items-center justify-between gap-3 mb-1">
                          <p className="text-sm text-foreground flex-1 min-w-0 truncate">{text}</p>
                          <span className="text-xs text-muted flex-shrink-0">{count}件 ({pct}%)</span>
                        </div>
                        <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                          <div className="h-full bg-primary" style={{ width: `${pct}%` }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Raw responses */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-5 py-3 border-b border-gray-100">
          <h2 className="text-sm font-bold text-foreground">回答一覧</h2>
        </div>
        {responses.length === 0 ? (
          <div className="p-8 text-center text-sm text-muted">回答がまだありません</div>
        ) : (
          <ul className="divide-y divide-gray-50 max-h-[600px] overflow-y-auto">
            {responses.map((r) => (
              <li key={r.id} className="px-5 py-3">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-medium text-foreground">
                    {r.userNickname ?? "匿名"}
                  </span>
                  <span className="text-xs text-muted">{formatDate(r.createdAt)}</span>
                </div>
                {r.answers?.map((a, i) => (
                  <div key={i} className="text-xs text-muted mb-1">
                    <span className="text-[10px] text-muted/70">Q{i + 1}:</span>{" "}
                    <span className="text-foreground">{a}</span>
                  </div>
                ))}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
