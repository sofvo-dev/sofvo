const statusConfig: Record<string, { bg: string; text: string; dot?: boolean }> = {
  "募集中": { bg: "bg-blue-100", text: "text-blue-700" },
  "満員": { bg: "bg-orange-100", text: "text-orange-700" },
  "開催中": { bg: "bg-green-100", text: "text-green-700", dot: true },
  "決勝中": { bg: "bg-purple-100", text: "text-purple-700", dot: true },
  "終了": { bg: "bg-gray-100", text: "text-gray-600" },
  "準備中": { bg: "bg-yellow-100", text: "text-yellow-700" },
};

export default function StatusBadge({ status }: { status: string }) {
  // Handle statuses that contain "完了" (e.g., "予選1完了")
  const config = statusConfig[status] ?? (
    status.includes("完了")
      ? { bg: "bg-teal-100", text: "text-teal-700" }
      : { bg: "bg-gray-100", text: "text-gray-600" }
  );

  return (
    <span
      className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold ${config.bg} ${config.text}`}
    >
      {config.dot && (
        <span className="w-1.5 h-1.5 rounded-full bg-current animate-live-pulse" />
      )}
      {status}
    </span>
  );
}
