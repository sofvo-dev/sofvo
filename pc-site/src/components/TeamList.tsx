"use client";

import { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import type { Entry } from "@/types/firestore";

interface TeamListProps {
  entries: Entry[];
  tournamentId: string;
}

interface TeamMember {
  name: string;
  uid?: string;
}

export default function TeamList({ entries, tournamentId }: TeamListProps) {
  if (entries.length === 0) {
    return (
      <div className="text-center py-16 text-muted bg-white rounded-xl border border-gray-200">
        まだ参加チームがありません
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-5 py-4 bg-gray-50 border-b border-gray-100 flex items-center justify-between">
        <h3 className="text-sm font-bold text-foreground">参加チーム一覧</h3>
        <span className="text-sm text-muted">{entries.length}チーム</span>
      </div>
      <div className="divide-y divide-gray-100">
        {entries.map((entry, i) => (
          <div key={entry.teamId || i} className="px-5 py-4 flex items-center gap-4 hover:bg-gray-50 transition-colors">
            <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0">
              {i + 1}
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-semibold text-foreground">{entry.teamName}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
