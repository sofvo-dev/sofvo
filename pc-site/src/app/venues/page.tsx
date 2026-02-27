"use client";

import { useEffect, useState } from "react";
import {
  collection, query, orderBy, getDocs, addDoc, updateDoc, doc, serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Venue } from "@/types/firestore";

const prefectures = [
  "すべて",
  "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
  "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
  "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
  "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
  "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
  "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
  "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
];

type SortKey = "name" | "address" | "courts" | "rating";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type VenueData = Venue & Record<string, any>;

export default function VenuesPage() {
  const { user } = useAuth();
  const [venues, setVenues] = useState<VenueData[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [prefFilter, setPrefFilter] = useState("すべて");
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [showForm, setShowForm] = useState(false);
  const [editingVenue, setEditingVenue] = useState<VenueData | null>(null);
  const [detailVenue, setDetailVenue] = useState<VenueData | null>(null);

  // Form state
  const [formName, setFormName] = useState("");
  const [formAddress, setFormAddress] = useState("");
  const [formPhone, setFormPhone] = useState("");
  const [formStation, setFormStation] = useState("");
  const [formCourts, setFormCourts] = useState("");
  const [formParking, setFormParking] = useState("");
  const [formHasToilet, setFormHasToilet] = useState(false);
  const [formHasChangeRoom, setFormHasChangeRoom] = useState(false);
  const [formHasShower, setFormHasShower] = useState(false);
  const [formHasGallery, setFormHasGallery] = useState(false);
  const [formHasAC, setFormHasAC] = useState(false);
  const [formEatArea, setFormEatArea] = useState("");
  const [formOpenTime, setFormOpenTime] = useState("8:00");
  const [formCloseTime, setFormCloseTime] = useState("22:00");
  const [formFee, setFormFee] = useState("");
  const [formEquipments, setFormEquipments] = useState<{ name: string; qty: number; fee: number }[]>([]);
  const [eqName, setEqName] = useState("");
  const [eqQty, setEqQty] = useState("");
  const [eqFee, setEqFee] = useState("0");
  const [formSaving, setFormSaving] = useState(false);

  useEffect(() => {
    async function loadVenues() {
      const q = query(collection(db, "venues"), orderBy("name"));
      const snap = await getDocs(q);
      const list = snap.docs.map((d) => ({ id: d.id, ...d.data() } as VenueData));
      setVenues(list);
      setLoading(false);
    }
    loadVenues();
  }, []);

  const matchesPref = (address: string) => {
    if (prefFilter === "すべて") return true;
    return address.includes(prefFilter.replace(/[都道府県]$/, ""));
  };

  const filtered = venues
    .filter((v) => {
      if (searchQuery) {
        const q = searchQuery.toLowerCase();
        if (!v.name.toLowerCase().includes(q) && !v.address.toLowerCase().includes(q)) return false;
      }
      if (!matchesPref(v.address)) return false;
      return true;
    })
    .sort((a, b) => {
      switch (sortKey) {
        case "name": return a.name.localeCompare(b.name, "ja");
        case "address": return a.address.localeCompare(b.address, "ja");
        case "courts": return (b.courts ?? 0) - (a.courts ?? 0);
        case "rating": return (b.rating ?? 0) - (a.rating ?? 0);
        default: return 0;
      }
    });

  const resetForm = () => {
    setFormName(""); setFormAddress(""); setFormPhone(""); setFormStation("");
    setFormCourts(""); setFormParking(""); setFormHasToilet(false); setFormHasChangeRoom(false);
    setFormHasShower(false); setFormHasGallery(false); setFormHasAC(false); setFormEatArea("");
    setFormOpenTime("8:00"); setFormCloseTime("22:00"); setFormFee(""); setFormEquipments([]);
    setEditingVenue(null); setShowForm(false);
  };

  const handleStartEdit = (venue: VenueData) => {
    setFormName(venue.name); setFormAddress(venue.address);
    setFormPhone(venue.phone || ""); setFormStation(venue.station || "");
    setFormCourts(venue.courts?.toString() ?? ""); setFormParking(venue.parking?.toString() ?? "");
    setFormHasToilet(venue.hasToilet ?? false); setFormHasChangeRoom(venue.hasChangeRoom ?? false);
    setFormHasShower(venue.hasShower ?? false); setFormHasGallery(venue.hasGallery ?? false);
    setFormHasAC(venue.hasAC ?? false); setFormEatArea(venue.eatArea || "");
    setFormOpenTime(venue.openTime || "8:00"); setFormCloseTime(venue.closeTime || "22:00");
    setFormFee(venue.fee || ""); setFormEquipments(venue.equipments ? [...venue.equipments] : []);
    setEditingVenue(venue); setShowForm(true); setDetailVenue(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !formName.trim() || !formAddress.trim()) return;
    setFormSaving(true);
    try {
      const venueData = {
        name: formName.trim(), address: formAddress.trim(), phone: formPhone.trim(),
        station: formStation.trim(), courts: formCourts ? parseInt(formCourts) : 0,
        parking: formParking ? parseInt(formParking) : 0,
        hasToilet: formHasToilet, hasChangeRoom: formHasChangeRoom, hasShower: formHasShower,
        hasGallery: formHasGallery, hasAC: formHasAC, eatArea: formEatArea.trim(),
        openTime: formOpenTime.trim(), closeTime: formCloseTime.trim(), fee: formFee.trim(),
        equipments: formEquipments, updatedAt: serverTimestamp(), lastEditedBy: user.uid,
      };
      if (editingVenue) {
        await updateDoc(doc(db, "venues", editingVenue.id), venueData);
        setVenues((prev) => prev.map((v) => v.id === editingVenue.id ? { ...v, ...venueData } as VenueData : v));
      } else {
        const docRef = await addDoc(collection(db, "venues"), {
          ...venueData, rating: 0, reviewCount: 0, registeredBy: user.uid, createdAt: serverTimestamp(),
        });
        setVenues((prev) => [...prev, { id: docRef.id, ...venueData, rating: 0 } as VenueData]);
      }
      resetForm();
    } catch { /* silently fail */ } finally { setFormSaving(false); }
  };

  const addEquipment = () => {
    if (!eqName.trim()) return;
    setFormEquipments([...formEquipments, { name: eqName.trim(), qty: parseInt(eqQty) || 1, fee: parseInt(eqFee) || 0 }]);
    setEqName(""); setEqQty(""); setEqFee("0");
  };

  if (loading) {
    return <div className="flex items-center justify-center py-32"><div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" /></div>;
  }

  return (
    <div className="p-8 max-w-[1200px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">会場一覧</h1>
          <p className="text-sm text-muted mt-1">大会会場を検索・管理</p>
        </div>
        {user && (
          <button onClick={() => { resetForm(); setShowForm(true); }}
            className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors">
            会場を追加
          </button>
        )}
      </div>

      {/* Info banner */}
      <div className="mb-6 p-3 bg-primary/5 border border-primary/15 rounded-xl flex items-center gap-2 text-sm text-primary">
        <svg className="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>
        会場情報は誰でも追加・編集できます。大会に参加して気づいたことがあれば更新してください！
      </div>

      {/* Detail Modal */}
      {detailVenue && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={() => setDetailVenue(null)}>
          <div className="bg-white rounded-2xl w-full max-w-[600px] max-h-[80vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between mb-4">
              <h2 className="text-xl font-bold text-foreground">{detailVenue.name}</h2>
              <button onClick={() => setDetailVenue(null)} className="p-1 text-gray-400 hover:text-gray-600"><svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg></button>
            </div>
            {(detailVenue.rating ?? 0) > 0 && (
              <div className="flex items-center gap-1 mb-3"><svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg><span className="text-sm font-medium">{(detailVenue.rating ?? 0).toFixed(1)} ({detailVenue.reviewCount ?? 0})</span></div>
            )}
            <a href={`https://www.google.com/maps/search/${encodeURIComponent(detailVenue.address)}`} target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 text-primary text-sm underline mb-2">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
              {detailVenue.address}
            </a>
            {detailVenue.phone && <DetailRow icon="phone" text={detailVenue.phone} />}
            {detailVenue.station && <DetailRow icon="train" text={detailVenue.station} />}
            {(detailVenue.openTime || detailVenue.closeTime) && <DetailRow icon="clock" text={`${detailVenue.openTime || ""} 〜 ${detailVenue.closeTime || ""}`} />}
            {detailVenue.fee && <DetailRow icon="money" text={detailVenue.fee} />}
            {detailVenue.eatArea && <DetailRow icon="food" text={detailVenue.eatArea} />}

            <h3 className="text-sm font-bold text-foreground mt-4 mb-2">施設情報</h3>
            <div className="flex flex-wrap gap-2">
              {(detailVenue.courts ?? 0) > 0 && <Chip text={`${detailVenue.courts}コート`} />}
              {(detailVenue.parking ?? 0) > 0 && <Chip text={`駐車場 ${detailVenue.parking}台`} />}
              {detailVenue.hasToilet && <Chip text="トイレあり" />}
              {detailVenue.hasAC && <Chip text="空調あり" />}
              {detailVenue.hasChangeRoom && <Chip text="更衣室あり" />}
              {detailVenue.hasShower && <Chip text="シャワーあり" />}
              {detailVenue.hasGallery && <Chip text="観覧席あり" />}
            </div>

            {(detailVenue.equipments?.length ?? 0) > 0 && (
              <>
                <h3 className="text-sm font-bold text-foreground mt-4 mb-2">貸出備品</h3>
                {(detailVenue.equipments ?? []).map((eq: { name: string; qty: number; fee: number }, i: number) => (
                  <div key={i} className="flex items-center gap-3 py-1.5 text-sm">
                    <span className="flex-1">{eq.name} x {eq.qty}個</span>
                    <span className={eq.fee === 0 ? "text-green-600" : ""}>{eq.fee === 0 ? "無料" : `¥${eq.fee}`}</span>
                  </div>
                ))}
              </>
            )}

            <button onClick={() => handleStartEdit(detailVenue)}
              className="w-full mt-6 px-4 py-3 border border-primary text-primary rounded-xl text-sm font-medium hover:bg-primary/5 transition-colors">
              この会場の情報を編集する
            </button>
          </div>
        </div>
      )}

      {/* Add/Edit Form */}
      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            {editingVenue ? "会場を編集" : "会場を追加"}
          </h2>
          {editingVenue && (
            <div className="mb-4 p-3 bg-primary/5 border border-primary/15 rounded-lg text-sm text-primary">
              会場情報を更新します。実際に利用して気づいた情報を追加してください。
            </div>
          )}
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="text-sm font-bold text-foreground bg-primary/5 px-3 py-2 rounded-lg">基本情報</div>
            <div className="grid grid-cols-2 gap-4">
              <FField label="会場名 *"><input type="text" value={formName} onChange={(e) => setFormName(e.target.value)} placeholder="例: 東京体育館" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" required /></FField>
              <FField label="住所 *"><input type="text" value={formAddress} onChange={(e) => setFormAddress(e.target.value)} placeholder="例: 東京都渋谷区..." className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" required /></FField>
              <FField label="電話番号"><input type="tel" value={formPhone} onChange={(e) => setFormPhone(e.target.value)} placeholder="例: 03-1234-5678" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="最寄り駅・バス停"><input type="text" value={formStation} onChange={(e) => setFormStation(e.target.value)} placeholder="例: JR原宿駅 徒歩10分" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
            </div>

            <div className="text-sm font-bold text-foreground bg-primary/5 px-3 py-2 rounded-lg">施設情報</div>
            <div className="grid grid-cols-2 gap-4">
              <FField label="コート数"><input type="number" value={formCourts} onChange={(e) => setFormCourts(e.target.value)} placeholder="例: 4" min={0} className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="駐車場(台数)"><input type="number" value={formParking} onChange={(e) => setFormParking(e.target.value)} placeholder="例: 100" min={0} className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
            </div>
            <div className="grid grid-cols-5 gap-4">
              <ToggleField label="トイレ" checked={formHasToilet} onChange={setFormHasToilet} />
              <ToggleField label="更衣室" checked={formHasChangeRoom} onChange={setFormHasChangeRoom} />
              <ToggleField label="シャワー" checked={formHasShower} onChange={setFormHasShower} />
              <ToggleField label="観覧席" checked={formHasGallery} onChange={setFormHasGallery} />
              <ToggleField label="空調" checked={formHasAC} onChange={setFormHasAC} />
            </div>
            <FField label="飲食可能エリア"><input type="text" value={formEatArea} onChange={(e) => setFormEatArea(e.target.value)} placeholder="例: 2階控室のみ可" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>

            <div className="text-sm font-bold text-foreground bg-primary/5 px-3 py-2 rounded-lg">利用情報</div>
            <div className="grid grid-cols-3 gap-4">
              <FField label="利用開始"><input type="text" value={formOpenTime} onChange={(e) => setFormOpenTime(e.target.value)} className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="利用終了"><input type="text" value={formCloseTime} onChange={(e) => setFormCloseTime(e.target.value)} className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="利用料金(目安)"><input type="text" value={formFee} onChange={(e) => setFormFee(e.target.value)} placeholder="例: 1時間¥2,000" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" /></FField>
            </div>

            <div className="text-sm font-bold text-foreground bg-primary/5 px-3 py-2 rounded-lg">貸出備品</div>
            {formEquipments.map((eq, i) => (
              <div key={i} className="flex items-center gap-3 text-sm">
                <span className="flex-1">{eq.name}</span><span>{eq.qty}個</span><span>{eq.fee === 0 ? "無料" : `¥${eq.fee}`}</span>
                <button type="button" onClick={() => setFormEquipments(formEquipments.filter((_, j) => j !== i))} className="text-red-400 hover:text-red-600"><svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg></button>
              </div>
            ))}
            <div className="flex gap-2 items-end">
              <FField label="備品名"><input type="text" value={eqName} onChange={(e) => setEqName(e.target.value)} placeholder="備品名" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="数量"><input type="number" value={eqQty} onChange={(e) => setEqQty(e.target.value)} placeholder="1" min={1} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" /></FField>
              <FField label="料金(円)"><input type="number" value={eqFee} onChange={(e) => setEqFee(e.target.value)} placeholder="0" min={0} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" /></FField>
              <button type="button" onClick={addEquipment} className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium">追加</button>
            </div>

            <div className="flex gap-3 pt-4 border-t border-gray-100">
              <button type="submit" disabled={formSaving}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50">
                {formSaving ? "保存中..." : editingVenue ? "更新する" : "追加する"}
              </button>
              <button type="button" onClick={resetForm}
                className="px-6 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground transition-colors">
                キャンセル
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Search & Filters */}
      <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
        <div className="flex flex-wrap gap-4">
          <div className="flex-1 min-w-[240px]">
            <div className="relative">
              <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
              <input type="search" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder="会場名・住所で検索..." className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm" />
            </div>
          </div>
          <select value={prefFilter} onChange={(e) => setPrefFilter(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white">
            {prefectures.map((p) => <option key={p} value={p}>{p === "すべて" ? "都道府県: すべて" : p}</option>)}
          </select>
          <select value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white">
            <option value="name">名前順</option><option value="address">住所順</option><option value="courts">コート数順</option><option value="rating">評価順</option>
          </select>
        </div>
      </div>

      <div className="text-sm text-muted mb-4">{filtered.length}件の会場</div>

      {filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🏟️</div>
          <h3 className="text-lg font-bold text-foreground mb-2">会場が見つかりません</h3>
          <p className="text-sm text-muted">検索条件を変更するか、新しい会場を追加してください</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          {filtered.map((venue) => (
            <div key={venue.id} className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-md hover:border-primary/30 transition-all group cursor-pointer"
              onClick={() => setDetailVenue(venue)}>
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <h3 className="text-base font-bold text-foreground truncate">{venue.name}</h3>
                  <p className="flex items-center gap-1.5 text-sm text-muted mt-1.5">
                    <svg className="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    <span className="truncate">{venue.address}</span>
                  </p>
                </div>
                <button onClick={(e) => { e.stopPropagation(); handleStartEdit(venue); }}
                  className="p-1.5 text-gray-400 hover:text-primary hover:bg-primary/10 rounded-lg transition-colors opacity-0 group-hover:opacity-100"
                  title="編集">
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                </button>
              </div>
              <div className="flex items-center gap-4 mt-4 pt-3 border-t border-gray-100 flex-wrap">
                {(venue.courts ?? 0) > 0 && <MiniChip text={`${venue.courts}コート`} />}
                {venue.phone && <MiniChip text={venue.phone} />}
                {(venue.parking ?? 0) > 0 && <MiniChip text={`P ${venue.parking}台`} />}
                {venue.hasToilet && <MiniChip text="トイレ" />}
                {venue.hasAC && <MiniChip text="空調" />}
                {venue.hasChangeRoom && <MiniChip text="更衣室" />}
                {(venue.rating ?? 0) > 0 && (
                  <div className="flex items-center gap-1">
                    <svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>
                    <span className="text-sm font-medium">{(venue.rating ?? 0).toFixed(1)}</span>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function FField({ label, children }: { label: string; children: React.ReactNode }) {
  return <div><label className="block text-sm font-medium text-foreground mb-1">{label}</label>{children}</div>;
}

function ToggleField({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="w-4 h-4 text-primary rounded" />
      <span className="text-sm">{label}</span>
    </label>
  );
}

function DetailRow({ icon, text }: { icon: string; text: string }) {
  const icons: Record<string, React.ReactNode> = {
    phone: <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z" /></svg>,
    train: <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /></svg>,
    clock: <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
    money: <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" /></svg>,
    food: <svg className="w-4 h-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513M15 8.25v-1.5m-6 1.5v-1.5m12 9.75l-1.5.75a3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0 3.354 3.354 0 00-3 0 3.354 3.354 0 01-3 0L3 16.5m15-3.379a48.474 48.474 0 00-6-.371c-2.032 0-4.034.126-6 .371m12 0c.39.049.777.102 1.163.16 1.07.16 1.837 1.094 1.837 2.175v5.169c0 .621-.504 1.125-1.125 1.125H4.125A1.125 1.125 0 013 20.625v-5.17c0-1.08.768-2.014 1.837-2.174A47.78 47.78 0 016 13.12M12.265 3.11a.375.375 0 11-.53 0L12 2.845l.265.265z" /></svg>,
  };
  return <div className="flex items-center gap-2 py-1.5 text-sm">{icons[icon]}<span>{text}</span></div>;
}

function Chip({ text }: { text: string }) {
  return <span className="px-3 py-1.5 bg-primary/8 text-primary rounded-lg text-sm font-medium">{text}</span>;
}

function MiniChip({ text }: { text: string }) {
  return <span className="text-xs text-muted">{text}</span>;
}
