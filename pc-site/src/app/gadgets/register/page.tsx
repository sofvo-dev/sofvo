"use client";

import { useState } from "react";
import {
  collection, addDoc, doc, updateDoc, increment, serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useRouter } from "next/navigation";

const AMAZON_API = "https://us-central1-sofvo-19d84.cloudfunctions.net";

interface AmazonProduct {
  asin: string;
  title: string;
  imageUrl: string;
  detailPageUrl: string;
  affiliateUrl: string;
  price?: string;
}

const categories = [
  "シューズ", "ボール", "ウェア", "サポーター", "バッグ", "プロテクター", "トレーニング用品", "その他",
];

export default function GadgetRegisterPage() {
  const router = useRouter();
  const { user, profile, loading: authLoading } = useAuth();

  // Amazon search
  const [searchKeyword, setSearchKeyword] = useState("");
  const [searchResults, setSearchResults] = useState<AmazonProduct[]>([]);
  const [totalResults, setTotalResults] = useState(0);
  const [isSearching, setIsSearching] = useState(false);
  const [searchPage, setSearchPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [showEmptyHint, setShowEmptyHint] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  // Amazon URL fetch
  const [urlInput, setUrlInput] = useState("");
  const [isFetchingUrl, setIsFetchingUrl] = useState(false);

  // Form
  const [name, setName] = useState("");
  const [category, setCategory] = useState("カテゴリなし");
  const [memo, setMemo] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [amazonUrl, setAmazonUrl] = useState("");
  const [amazonAffiliateUrl, setAmazonAffiliateUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const searchAmazon = async () => {
    if (!searchKeyword.trim()) return;
    setIsSearching(true);
    setSearchResults([]);
    setSearchPage(1);
    setHasMore(false);
    setShowEmptyHint(false);
    try {
      const res = await fetch(`${AMAZON_API}/amazonSearch?q=${encodeURIComponent(searchKeyword.trim())}&page=1`);
      if (res.ok) {
        const data = await res.json();
        if (data && typeof data === "object" && Array.isArray(data.items)) {
          setSearchResults(data.items);
          setTotalResults(data.totalResults ?? data.items.length);
          setHasMore(data.items.length >= 10);
          setShowEmptyHint(data.items.length === 0);
        } else if (Array.isArray(data)) {
          // 後方互換
          setSearchResults(data);
          setTotalResults(data.length);
          setHasMore(data.length >= 10);
          setShowEmptyHint(data.length === 0);
        }
      } else {
        setShowEmptyHint(true);
      }
    } catch {
      setShowEmptyHint(true);
    } finally {
      setIsSearching(false);
    }
  };

  const loadMore = async () => {
    if (isLoadingMore || !hasMore) return;
    setIsLoadingMore(true);
    try {
      const nextPage = searchPage + 1;
      const res = await fetch(`${AMAZON_API}/amazonSearch?q=${encodeURIComponent(searchKeyword.trim())}&page=${nextPage}`);
      if (res.ok) {
        const data = await res.json();
        const items = data && Array.isArray(data.items) ? data.items : Array.isArray(data) ? data : [];
        if (items.length > 0) {
          setSearchPage(nextPage);
          setSearchResults((prev) => [...prev, ...items]);
          setHasMore(items.length >= 10);
        }
      }
    } catch { /* ignore */ } finally { setIsLoadingMore(false); }
  };

  const selectProduct = (product: AmazonProduct) => {
    setName(product.title);
    setImageUrl(product.imageUrl);
    setAmazonUrl(product.detailPageUrl);
    setAmazonAffiliateUrl(product.affiliateUrl);
    setSearchResults([]);
    setSearchKeyword("");
  };

  const fetchByUrl = async () => {
    if (!urlInput.trim()) return;
    const asinMatch = urlInput.match(/\/dp\/([A-Z0-9]{10})/) || urlInput.match(/\/gp\/product\/([A-Z0-9]{10})/) || urlInput.match(/\/([A-Z0-9]{10})(?:[/?]|$)/);
    if (!asinMatch) {
      setError("有効なAmazon商品URLを入力してください");
      return;
    }
    setIsFetchingUrl(true);
    setError("");
    try {
      const res = await fetch(`${AMAZON_API}/amazonProduct?asin=${asinMatch[1]}`);
      if (res.ok) {
        const data = await res.json();
        if (data.title) setName(data.title);
        setImageUrl(data.imageUrl || "");
        setAmazonUrl(data.detailPageUrl || `https://www.amazon.co.jp/dp/${asinMatch[1]}`);
        setAmazonAffiliateUrl(data.affiliateUrl || data.detailPageUrl || "");
        setUrlInput("");
      }
    } catch {
      setError("商品情報の取得に失敗しました");
    } finally {
      setIsFetchingUrl(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    if (!name.trim()) { setError("商品名を入力してください"); return; }
    setSubmitting(true);
    setError("");
    try {
      await addDoc(collection(db, "users", user.uid, "gadgets"), {
        name: name.trim(),
        category,
        amazonUrl,
        amazonAffiliateUrl,
        imageUrl,
        memo: memo.trim() || null,
        createdAt: serverTimestamp(),
      });
      await updateDoc(doc(db, "users", user.uid), { gadgetCount: increment(1) });
      router.push("/gadgets");
    } catch {
      setError("ガジェットの登録に失敗しました");
      setSubmitting(false);
    }
  };

  if (authLoading) {
    return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  }

  if (!user || !profile) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <p className="text-sm text-muted mb-6">ガジェット登録にはログインが必要です</p>
          <Link href="/login" className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">ログイン</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      <nav className="flex items-center gap-2 text-sm text-muted mb-6">
        <Link href="/gadgets" className="hover:text-primary transition-colors">ガジェット</Link>
        <svg className="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" /></svg>
        <span className="text-foreground font-medium">登録</span>
      </nav>

      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">ガジェット登録</h1>
        <p className="text-sm text-muted mt-1">使用している用具・装備を登録します</p>
      </div>

      {/* Amazon Search */}
      <div className="bg-amber-50 rounded-xl border border-amber-200/50 p-5 mb-6">
        <div className="flex items-center gap-2 mb-1">
          <svg className="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
          <span className="text-sm font-semibold text-foreground">キーワードで検索</span>
        </div>
        <p className="text-xs text-muted mb-3">商品名やブランド名で検索できます</p>
        <div className="flex gap-2">
          <input type="text" value={searchKeyword} onChange={(e) => setSearchKeyword(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && searchAmazon()}
            placeholder="例: ミカサ バレーボール" className="flex-1 px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <button onClick={searchAmazon} disabled={isSearching}
            className="px-5 py-2.5 bg-amber-500 text-white rounded-lg text-sm font-medium hover:bg-amber-600 disabled:opacity-50 transition-colors">
            {isSearching ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> : "検索"}
          </button>
        </div>

        {/* Search Results */}
        {searchResults.length > 0 && (
          <div className="mt-4 border-t border-amber-200/50 pt-3">
            <p className="text-xs font-semibold text-muted mb-1">{totalResults}件見つかりました</p>
            <p className="text-xs text-hint mb-2">タップして商品を選択してください</p>
            <div className="space-y-2 max-h-[400px] overflow-y-auto">
              {searchResults.map((product, i) => (
                <button key={i} onClick={() => selectProduct(product)}
                  className="w-full flex items-center gap-3 p-2.5 bg-white rounded-lg border border-gray-200 hover:border-amber-400 transition-colors text-left">
                  <div className="w-14 h-14 rounded-lg border border-gray-200 bg-white flex-shrink-0 overflow-hidden">
                    {product.imageUrl && <img src={product.imageUrl} alt="" className="w-full h-full object-contain" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground line-clamp-2">{product.title}</p>
                    {product.price && <p className="text-xs font-bold text-red-500 mt-0.5">{product.price}</p>}
                  </div>
                  <svg className="w-5 h-5 text-amber-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </button>
              ))}
            </div>
            {hasMore && (
              <button onClick={loadMore} disabled={isLoadingMore}
                className="w-full mt-3 px-4 py-2.5 border border-amber-400 text-amber-600 rounded-lg text-sm font-medium hover:bg-amber-50 disabled:opacity-50 transition-colors">
                {isLoadingMore ? "読み込み中..." : "さらに読み込む"}
              </button>
            )}
          </div>
        )}

        {/* Empty hint - URL fallback */}
        {showEmptyHint && (
          <div className="mt-4 border-t border-amber-200/50 pt-3 space-y-3">
            <p className="text-sm text-muted">商品が見つかりませんでした。以下の方法で登録できます：</p>
            <div className="bg-white rounded-lg border border-gray-200 p-3">
              <p className="text-xs font-semibold text-foreground mb-2">Amazon URLを貼り付け</p>
              <div className="flex gap-2">
                <input type="text" value={urlInput} onChange={(e) => setUrlInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && fetchByUrl()}
                  placeholder="https://www.amazon.co.jp/dp/..." className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-xs" />
                <button onClick={fetchByUrl} disabled={isFetchingUrl}
                  className="px-4 py-2 bg-amber-500 text-white rounded-lg text-xs font-bold hover:bg-amber-600 disabled:opacity-50">
                  {isFetchingUrl ? "..." : "取得"}
                </button>
              </div>
            </div>
            <a href={`https://www.amazon.co.jp/s?k=${encodeURIComponent(searchKeyword)}`} target="_blank" rel="noopener noreferrer"
              className="block w-full px-4 py-2.5 border border-amber-400 text-amber-600 rounded-lg text-sm font-medium text-center hover:bg-amber-50 transition-colors">
              Amazonで商品を探す ↗
            </a>
          </div>
        )}
      </div>

      {/* Image Preview */}
      {imageUrl && (
        <div className="flex justify-center mb-6">
          <div className="w-28 h-28 rounded-xl border border-gray-200 bg-white overflow-hidden">
            <img src={imageUrl} alt="" className="w-full h-full object-contain" />
          </div>
        </div>
      )}

      {/* Form */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
        {error && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">商品名 <span className="text-error">*</span></label>
            <p className="text-xs text-muted mb-2">検索から自動入力されますが、手動で変更もできます</p>
            <input type="text" value={name} onChange={(e) => setName(e.target.value)}
              placeholder="例: ヨネックス ナノフレア700" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" required />
          </div>

          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">カテゴリ</label>
            <div className="flex flex-wrap gap-2">
              {["カテゴリなし", ...categories].map((c) => (
                <button key={c} type="button" onClick={() => setCategory(c)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${category === c ? "bg-primary text-white" : "bg-gray-100 text-muted hover:bg-gray-200"}`}>
                  {c}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">メモ</label>
            <textarea value={memo} onChange={(e) => setMemo(e.target.value)} rows={3}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
              placeholder="使用感や気に入っているポイントなど..." />
          </div>

          <div className="flex gap-3 pt-4 border-t border-gray-100">
            <button type="submit" disabled={submitting}
              className="px-8 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50">
              {submitting ? "登録中..." : "ガジェットを登録"}
            </button>
            <Link href="/gadgets"
              className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors">
              キャンセル
            </Link>
          </div>
        </form>
      </div>
    </div>
  );
}
