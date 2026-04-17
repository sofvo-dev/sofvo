"use client";

import { Suspense, useState } from "react";
import Link from "next/link";
import { useSearchParams, useRouter } from "next/navigation";

const AMAZON_API = "https://us-central1-sofvo-19d84.cloudfunctions.net";

interface AmazonProduct {
  asin: string;
  title: string;
  imageUrl: string;
  detailPageUrl: string;
  affiliateUrl: string;
  price?: string;
}

export default function PrizeSearchPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>}>
      <PrizeSearchContent />
    </Suspense>
  );
}

function PrizeSearchContent() {
  const params = useSearchParams();
  const router = useRouter();
  const returnTo = params.get("return") ?? "";

  const [keyword, setKeyword] = useState("");
  const [results, setResults] = useState<AmazonProduct[]>([]);
  const [searching, setSearching] = useState(false);
  const [empty, setEmpty] = useState(false);

  const search = async () => {
    if (!keyword.trim()) return;
    setSearching(true);
    setResults([]);
    setEmpty(false);
    try {
      const res = await fetch(`${AMAZON_API}/amazonSearch?q=${encodeURIComponent(keyword.trim())}&page=1`);
      if (res.ok) {
        const data = await res.json();
        const items = (Array.isArray(data.items) ? data.items : Array.isArray(data) ? data : []) as AmazonProduct[];
        setResults(items);
        setEmpty(items.length === 0);
      } else {
        setEmpty(true);
      }
    } catch {
      setEmpty(true);
    } finally {
      setSearching(false);
    }
  };

  const choose = (p: AmazonProduct) => {
    if (returnTo) {
      // Pass selected back via URL params
      const u = new URL(returnTo, window.location.origin);
      u.searchParams.set("prizeTitle", p.title);
      u.searchParams.set("prizeImage", p.imageUrl);
      u.searchParams.set("prizeUrl", p.affiliateUrl || p.detailPageUrl);
      router.push(u.pathname + u.search);
    }
  };

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-1">景品検索</h1>
      <p className="text-sm text-muted mb-6">Amazonから景品を検索して大会に紐づけられます</p>

      <div className="bg-amber-50 border border-amber-200 rounded-xl p-5 mb-6">
        <div className="flex gap-2">
          <input
            type="text"
            value={keyword}
            onChange={(e) => setKeyword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && search()}
            placeholder="例: ソフトバレーボール"
            className="flex-1 px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
          />
          <button
            onClick={search}
            disabled={searching}
            className="px-5 py-2.5 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600 disabled:opacity-50"
          >
            {searching ? "検索中..." : "検索"}
          </button>
        </div>
      </div>

      {empty && (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200 mb-4">
          <p className="text-sm text-muted mb-3">商品が見つかりませんでした</p>
          <a
            href={`https://www.amazon.co.jp/s?k=${encodeURIComponent(keyword)}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex px-4 py-2 border border-amber-400 text-amber-600 rounded-lg text-xs font-medium hover:bg-amber-50 transition-colors"
          >
            Amazonで直接検索 ↗
          </a>
        </div>
      )}

      {results.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {results.map((p) => (
            <div key={p.asin} className="bg-white rounded-xl border border-gray-200 p-4 flex gap-3">
              <div className="w-20 h-20 rounded-lg border border-gray-200 bg-white flex-shrink-0 overflow-hidden flex items-center justify-center">
                {p.imageUrl ? (
                  <img src={p.imageUrl} alt="" className="w-full h-full object-contain" />
                ) : (
                  <span className="text-xs text-muted">No image</span>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm text-foreground line-clamp-2 mb-2">{p.title}</p>
                {p.price && <p className="text-xs font-bold text-red-500 mb-2">{p.price}</p>}
                <div className="flex gap-2">
                  {returnTo && (
                    <button
                      onClick={() => choose(p)}
                      className="px-3 py-1 bg-primary text-white rounded text-xs font-medium hover:bg-primary-dark"
                    >
                      選択
                    </button>
                  )}
                  <a
                    href={p.detailPageUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="px-3 py-1 border border-gray-300 rounded text-xs text-muted hover:text-foreground"
                  >
                    詳細 ↗
                  </a>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {!returnTo && (
        <p className="text-xs text-muted mt-6">
          Tip: 大会作成画面から景品を検索すると、選択した商品が自動で入力されます
        </p>
      )}

      <div className="mt-8">
        <Link href="/tournaments" className="text-sm text-primary hover:underline">
          ← 大会一覧に戻る
        </Link>
      </div>
    </div>
  );
}
