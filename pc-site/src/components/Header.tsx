"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export default function Header() {
  const pathname = usePathname();
  const isHome = pathname === "/";

  return (
    <header className="sticky top-0 z-50 bg-white/95 backdrop-blur border-b border-gray-200">
      <div className="max-w-[1400px] mx-auto px-6 h-14 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2">
          <span className="text-xl font-bold text-primary">Sofvo</span>
          <span className="text-xs text-muted bg-gray-100 px-2 py-0.5 rounded">
            PC
          </span>
        </Link>
        {!isHome && (
          <Link
            href="/"
            className="text-sm text-muted hover:text-primary transition-colors"
          >
            大会一覧に戻る
          </Link>
        )}
      </div>
    </header>
  );
}
