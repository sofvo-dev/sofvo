const statusConfig: Record<string, { bg: string; text: string; border: string; dot?: boolean }> = {
  "募集中": { bg: "bg-[#1B3A5C]/10", text: "text-[#1B3A5C]", border: "border-[#1B3A5C]/20" },
  "満員": { bg: "bg-amber-500/10", text: "text-amber-700", border: "border-amber-500/20" },
  "エントリー締切": { bg: "bg-[#C4A962]/10", text: "text-[#8A7220]", border: "border-[#C4A962]/25" },
  "試合準備": { bg: "bg-sky-500/10", text: "text-sky-800", border: "border-sky-500/20" },
  "開催中": { bg: "bg-[#2E7D32]/10", text: "text-[#2E7D32]", border: "border-[#2E7D32]/20", dot: true },
  "決勝中": { bg: "bg-amber-400/10", text: "text-amber-700", border: "border-amber-400/20", dot: true },
  "終了": { bg: "bg-gray-100", text: "text-gray-500", border: "border-gray-200" },
  "準備中": { bg: "bg-[#F9A825]/10", text: "text-[#B88A00]", border: "border-[#F9A825]/20" },
};

export default function StatusBadge({ status }: { status: string }) {
  const config = statusConfig[status] ?? (
    status.includes("完了")
      ? { bg: "bg-teal-500/10", text: "text-teal-700", border: "border-teal-500/20" }
      : { bg: "bg-gray-100", text: "text-gray-500", border: "border-gray-200" }
  );

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-[10px] text-[11px] font-bold border ${config.bg} ${config.text} ${config.border}`}
    >
      {config.dot && (
        <span className="w-1.5 h-1.5 rounded-full bg-current animate-live-pulse" />
      )}
      {status}
    </span>
  );
}
