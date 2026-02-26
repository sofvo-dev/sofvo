"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Venue } from "@/types/firestore";

const AREAS = ["すべて", "北海道", "東北", "関東", "中部", "近畿", "中国", "四国", "九州"];

type SortKey = "name" | "address" | "courts" | "rating";

function matchesArea(address: string, area: string): boolean {
  if (area === "すべて") return true;
  const areaMap: Record<string, string[]> = {
    北海道: ["北海道"],
    東北: ["青森", "岩手", "宮城", "秋田", "山形", "福島"],
    関東: ["茨城", "栃木", "群馬", "埼玉", "千葉", "東京", "神奈川"],
    中部: ["新潟", "富山", "石川", "福井", "山梨", "長野", "岐阜", "静岡", "愛知"],
    近畿: ["三重", "滋賀", "京都", "大阪", "兵庫", "奈良", "和歌山"],
    中国: ["鳥取", "島根", "岡山", "広島", "山口"],
    四国: ["徳島", "香川", "愛媛", "高知"],
    九州: ["福岡", "佐賀", "長崎", "熊本", "大分", "宮崎", "鹿児島", "沖縄"],
  };
  const prefectures = areaMap[area] || [];
  return prefectures.some((p) => address.includes(p));
}

export default function VenuesPage() {
  const { user } = useAuth();
  const [venues, setVenues] = useState<Venue[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [areaFilter, setAreaFilter] = useState("すべて");
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [showForm, setShowForm] = useState(false);
  const [editingVenue, setEditingVenue] = useState<Venue | null>(null);

  // Form state
  const [formName, setFormName] = useState("");
  const [formAddress, setFormAddress] = useState("");
  const [formCourts, setFormCourts] = useState("");
  const [formSaving, setFormSaving] = useState(false);

  useEffect(() => {
    async function loadVenues() {
      const q = query(collection(db, "venues"), orderBy("name"));
      const snap = await getDocs(q);
      const list = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as Venue)
      );
      setVenues(list);
      setLoading(false);
    }
    loadVenues();
  }, []);

  const filtered = venues
    .filter((v) => {
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        if (
          !v.name.toLowerCase().includes(q) &&
          !v.address.toLowerCase().includes(q)
        ) {
          return false;
        }
      }
      if (!matchesArea(v.address, areaFilter)) return false;
      return true;
    })
    .sort((a, b) => {
      switch (sortKey) {
        case "name":
          return a.name.localeCompare(b.name, "ja");
        case "address":
          return a.address.localeCompare(b.address, "ja");
        case "courts":
          return (b.courts ?? 0) - (a.courts ?? 0);
        case "rating":
          return (b.rating ?? 0) - (a.rating ?? 0);
        default:
          return 0;
      }
    });

  const resetForm = () => {
    setFormName("");
    setFormAddress("");
    setFormCourts("");
    setEditingVenue(null);
    setShowForm(false);
  };

  const handleStartEdit = (venue: Venue) => {
    setFormName(venue.name);
    setFormAddress(venue.address);
    setFormCourts(venue.courts?.toString() ?? "");
    setEditingVenue(venue);
    setShowForm(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !formName.trim() || !formAddress.trim()) return;

    setFormSaving(true);

    try {
      if (editingVenue) {
        // Update existing
        await updateDoc(doc(db, "venues", editingVenue.id), {
          name: formName.trim(),
          address: formAddress.trim(),
          courts: formCourts ? parseInt(formCourts) : null,
        });
        setVenues((prev) =>
          prev.map((v) =>
            v.id === editingVenue.id
              ? {
                  ...v,
                  name: formName.trim(),
                  address: formAddress.trim(),
                  courts: formCourts ? parseInt(formCourts) : undefined,
                }
              : v
          )
        );
      } else {
        // Create new
        const docRef = await addDoc(collection(db, "venues"), {
          name: formName.trim(),
          address: formAddress.trim(),
          courts: formCourts ? parseInt(formCourts) : null,
          rating: 0,
          createdBy: user.uid,
          createdAt: serverTimestamp(),
        });
        setVenues((prev) => [
          ...prev,
          {
            id: docRef.id,
            name: formName.trim(),
            address: formAddress.trim(),
            courts: formCourts ? parseInt(formCourts) : undefined,
            rating: 0,
            createdBy: user.uid,
          },
        ]);
      }
      resetForm();
    } catch {
      // silently fail
    } finally {
      setFormSaving(false);
    }
  };

  const handleDelete = async (venueId: string) => {
    if (!confirm("この会場を削除しますか？")) return;
    await deleteDoc(doc(db, "venues", venueId));
    setVenues((prev) => prev.filter((v) => v.id !== venueId));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">会場一覧</h1>
          <p className="text-sm text-muted mt-1">大会会場を検索・管理</p>
        </div>
        {user && (
          <button
            onClick={() => {
              resetForm();
              setShowForm(true);
            }}
            className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            会場を追加
          </button>
        )}
      </div>

      {/* Add/Edit Form Modal */}
      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            {editingVenue ? "会場を編集" : "会場を追加"}
          </h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                会場名 <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder="例: 東京体育館"
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                住所 <span className="text-red-500">*</span>
              </label>
              <input
                type="text"
                value={formAddress}
                onChange={(e) => setFormAddress(e.target.value)}
                placeholder="例: 東京都渋谷区千駄ヶ谷1-17-1"
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">
                コート数
              </label>
              <input
                type="number"
                value={formCourts}
                onChange={(e) => setFormCourts(e.target.value)}
                placeholder="例: 4"
                min={1}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
              />
            </div>
            <div className="flex gap-3 pt-2">
              <button
                type="submit"
                disabled={formSaving}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {formSaving
                  ? "保存中..."
                  : editingVenue
                  ? "更新する"
                  : "追加する"}
              </button>
              <button
                type="button"
                onClick={resetForm}
                className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
              >
                キャンセル
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Search & Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
        <div className="flex flex-wrap gap-4">
          {/* Search */}
          <div className="flex-1 min-w-[240px]">
            <div className="relative">
              <svg
                className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={1.5}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
                />
              </svg>
              <input
                type="search"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="会場名・住所で検索..."
                className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          </div>

          {/* Area Filter */}
          <select
            value={areaFilter}
            onChange={(e) => setAreaFilter(e.target.value)}
            className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
          >
            {AREAS.map((a) => (
              <option key={a} value={a}>
                {a === "すべて" ? "エリア: すべて" : a}
              </option>
            ))}
          </select>

          {/* Sort */}
          <select
            value={sortKey}
            onChange={(e) => setSortKey(e.target.value as SortKey)}
            className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
          >
            <option value="name">名前順</option>
            <option value="address">住所順</option>
            <option value="courts">コート数順</option>
            <option value="rating">評価順</option>
          </select>
        </div>
      </div>

      {/* Results count */}
      <div className="text-sm text-muted mb-4">{filtered.length}件の会場</div>

      {/* Venue List */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🏟️</div>
          <h3 className="text-lg font-bold text-foreground mb-2">
            会場が見つかりません
          </h3>
          <p className="text-sm text-muted">
            検索条件を変更するか、新しい会場を追加してください
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {filtered.map((venue) => {
            const isOwner = user && venue.createdBy === user.uid;
            return (
              <div
                key={venue.id}
                className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-md hover:border-primary/30 transition-all group"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <h3 className="text-base font-bold text-foreground truncate">
                      {venue.name}
                    </h3>
                    <p className="flex items-center gap-1.5 text-sm text-muted mt-1.5">
                      <svg
                        className="w-4 h-4 flex-shrink-0"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={1.5}
                          d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
                        />
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={1.5}
                          d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
                        />
                      </svg>
                      <span className="truncate">{venue.address}</span>
                    </p>
                  </div>

                  {/* Owner actions */}
                  {isOwner && (
                    <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                      <button
                        onClick={() => handleStartEdit(venue)}
                        className="p-1.5 text-gray-400 hover:text-primary hover:bg-primary/10 rounded-lg transition-colors"
                        title="編集"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                          />
                        </svg>
                      </button>
                      <button
                        onClick={() => handleDelete(venue.id)}
                        className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                        title="削除"
                      >
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                          />
                        </svg>
                      </button>
                    </div>
                  )}
                </div>

                {/* Stats */}
                <div className="flex items-center gap-4 mt-4 pt-3 border-t border-gray-100">
                  {venue.courts != null && (
                    <div className="flex items-center gap-1.5">
                      <svg
                        className="w-4 h-4 text-muted"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={1.5}
                          d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
                        />
                      </svg>
                      <span className="text-sm text-muted">
                        <span className="font-bold text-foreground">{venue.courts}</span> コート
                      </span>
                    </div>
                  )}
                  {venue.rating != null && venue.rating > 0 && (
                    <div className="flex items-center gap-1">
                      <svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                      <span className="text-sm font-medium text-foreground">
                        {venue.rating.toFixed(1)}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
