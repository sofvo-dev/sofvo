/** 大会 Firestore `status` の正規化（旧 `試合準備中` / `試合準備` → `大会準備中` など） */
export function normalizeTournamentStatus(
  raw: string | null | undefined,
  emptyAsPreparing = true
): string {
  if (raw == null || raw === "") {
    return emptyAsPreparing ? "準備中" : "";
  }
  if (raw === "試合準備中" || raw === "試合準備") return "大会準備中";
  if (raw === "エントリー締め切") return "エントリー締切";
  return raw;
}
