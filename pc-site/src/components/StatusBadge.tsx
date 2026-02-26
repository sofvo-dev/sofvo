const statusConfig: Record<string, { bg: string; text: string; border: string; dot?: boolean }> = {
  "募集中": { bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  "満員": { bg: "bg-orange-50", text: "text-orange-700", border: "border-orange-200" },
  "開催中": { bg: "bg-green-50", text: "text-green-700", border: "border-green-200", dot: true },
  "決勝中": { bg: "bg-purple-50", text: "text-purple-700", border: "border-purple-200", dot: true },
  "終了": { bg: "bg-gray-50", text: "text-gray-600", border: "border-gray-200" },
  "準備中": { bg: "bg-yellow-50", text: "text-yellow-700", border: "border-yellow-200" },
};

export default function StatusBadge({ status }: { status: string }) {
  const config = statusConfig[status] ?? (
    status.includes("完了")
      ? { bg: "bg-teal-50", text: "text-teal-700", border: "border-teal-200" }
      : { bg: "bg-gray-50", text: "text-gray-600", border: "border-gray-200" }
  );

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold border ${config.bg} ${config.text} ${config.border}`}
    >
      {config.dot && (
        <span className="w-1.5 h-1.5 rounded-full bg-current animate-live-pulse" />
      )}
      {status}
    </span>
  );
}
