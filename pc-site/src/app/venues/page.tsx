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
  const [formFloorType, setFormFloorType] = useState("");
  const [formPoleType, setFormPoleType] = useState("");
  const [formPoleAdjustable, setFormPoleAdjustable] = useState("");
  const [formNotes, setFormNotes] = useState("");
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
      return matchesPref(v.address);
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
    setFormFloorType(""); setFormPoleType(""); setFormPoleAdjustable(""); setFormNotes("");
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
    setFormFloorType(venue.floorType || ""); setFormPoleType(venue.poleType || "");
    setFormPoleAdjustable(venue.poleAdjustable || ""); setFormNotes(venue.notes || "");
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
        floorType: formFloorType, poleType: formPoleType, poleAdjustable: formPoleAdjustable,
        notes: formNotes.trim(),
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

  // Facility chips for detail/cards
  const facilityList = (v: VenueData) => {
    const items: string[] = [];
    if ((v.courts ?? 0) > 0) items.push(`${v.courts}コート`);
    if ((v.parking ?? 0) > 0) items.push(`駐車場 ${v.parking}台`);
    if (v.hasToilet) items.push("トイレ");
    if (v.hasAC) items.push("空調");
    if (v.hasChangeRoom) items.push("更衣室");
    if (v.hasShower) items.push("シャワー");
    if (v.hasGallery) items.push("観覧席");
    if (v.floorType) items.push(`床: ${v.floorType}`);
    if (v.poleType) items.push(`ポール: ${v.poleType}`);
    if (v.poleAdjustable) items.push(`高さ調節: ${v.poleAdjustable}`);
    return items;
  };

  return (
    <div className="p-6 md:p-8 max-w-[1200px] mx-auto animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">会場一覧</h1>
          <p className="text-sm text-muted mt-1">{venues.length}件の会場が登録されています</p>
        </div>
        {user && (
          <button onClick={() => { resetForm(); setShowForm(true); }}
            className="btn-primary">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
            会場を追加
          </button>
        )}
      </div>

      {/* Info banner */}
      <div className="mb-6 p-3.5 bg-blue-50 border border-blue-100 rounded-xl flex items-start gap-3 text-sm text-blue-700">
        <svg className="w-5 h-5 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>
        <div>
          <p className="font-medium">会場情報は誰でも追加・編集できます</p>
          <p className="text-blue-600 mt-0.5">大会に参加して気づいたことがあれば、ぜひ情報を更新してください。</p>
        </div>
      </div>

      {/* ===== Detail Modal ===== */}
      {detailVenue && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={() => setDetailVenue(null)}>
          <div className="bg-white rounded-2xl w-full max-w-[560px] max-h-[85vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            {/* Modal Header */}
            <div className="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between rounded-t-2xl">
              <h2 className="text-lg font-bold text-foreground">{detailVenue.name}</h2>
              <button onClick={() => setDetailVenue(null)} className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <div className="p-6 space-y-5">
              {/* Rating */}
              {(detailVenue.rating ?? 0) > 0 && (
                <div className="flex items-center gap-2 text-sm">
                  <div className="flex items-center gap-1 text-yellow-500">
                    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>
                    <span className="font-bold text-foreground">{(detailVenue.rating ?? 0).toFixed(1)}</span>
                  </div>
                  <span className="text-muted">({detailVenue.reviewCount ?? 0}件の評価)</span>
                </div>
              )}

              {/* Address with map link */}
              <a href={`https://www.google.com/maps/search/${encodeURIComponent(detailVenue.address)}`} target="_blank" rel="noopener noreferrer"
                className="flex items-start gap-3 p-3 bg-gray-50 rounded-xl hover:bg-primary/5 transition-colors group">
                <svg className="w-5 h-5 text-primary flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                <div>
                  <p className="text-sm font-medium text-foreground">{detailVenue.address}</p>
                  <p className="text-xs text-primary mt-0.5 group-hover:underline">Google Mapで開く</p>
                </div>
              </a>

              {/* Detail rows */}
              <div className="space-y-0 divide-y divide-gray-100">
                {detailVenue.phone && (
                  <DetailRow label="電話番号" value={detailVenue.phone} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 6.75c0 8.284 6.716 15 15 15h2.25a2.25 2.25 0 002.25-2.25v-1.372c0-.516-.351-.966-.852-1.091l-4.423-1.106c-.44-.11-.902.055-1.173.417l-.97 1.293c-.282.376-.769.542-1.21.38a12.035 12.035 0 01-7.143-7.143c-.162-.441.004-.928.38-1.21l1.293-.97c.363-.271.527-.734.417-1.173L6.963 3.102a1.125 1.125 0 00-1.091-.852H4.5A2.25 2.25 0 002.25 4.5v2.25z" /></svg>} />
                )}
                {detailVenue.station && (
                  <DetailRow label="最寄り駅" value={detailVenue.station} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M8.25 18.75a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0h6m-9 0H3.375a1.125 1.125 0 01-1.125-1.125V14.25m17.25 4.5a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m3 0H6.375c-.621 0-1.125-.504-1.125-1.125V11.25m17.25 7.5v-4.5a2.25 2.25 0 00-2.25-2.25H5.25a2.25 2.25 0 00-2.25 2.25v4.5" /></svg>} />
                )}
                {(detailVenue.openTime || detailVenue.closeTime) && (
                  <DetailRow label="利用時間" value={`${detailVenue.openTime || ""} 〜 ${detailVenue.closeTime || ""}`} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>} />
                )}
                {detailVenue.fee && (
                  <DetailRow label="利用料金" value={detailVenue.fee} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>} />
                )}
                {detailVenue.eatArea && (
                  <DetailRow label="飲食エリア" value={detailVenue.eatArea} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 8.25v-1.5m0 1.5c-1.355 0-2.697.056-4.024.166C6.845 8.51 6 9.473 6 10.608v2.513m6-4.871c1.355 0 2.697.056 4.024.166C17.155 8.51 18 9.473 18 10.608v2.513m0 0V19.5a2.25 2.25 0 01-2.25 2.25H8.25A2.25 2.25 0 016 19.5v-6.379" /></svg>} />
                )}
                {detailVenue.floorType && (
                  <DetailRow label="床の種類" value={detailVenue.floorType} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" /></svg>} />
                )}
                {detailVenue.poleType && (
                  <DetailRow label="ネットポール" value={detailVenue.poleType} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m0 0l-6-6m6 6l6-6" /></svg>} />
                )}
                {detailVenue.poleAdjustable && (
                  <DetailRow label="ポール高さ調節" value={detailVenue.poleAdjustable} icon={<svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M3 7.5L7.5 3m0 0L12 7.5M7.5 3v13.5m13.5-4.5L16.5 16.5m0 0L12 12m4.5 4.5V7.5" /></svg>} />
                )}
              </div>

              {/* 備考 */}
              {detailVenue.notes && (
                <div>
                  <h3 className="text-sm font-bold text-foreground mb-2">備考</h3>
                  <p className="text-sm text-foreground whitespace-pre-wrap bg-gray-50 rounded-xl p-3">{detailVenue.notes}</p>
                </div>
              )}

              {/* Facilities */}
              {facilityList(detailVenue).length > 0 && (
                <div>
                  <h3 className="text-sm font-bold text-foreground mb-3">施設情報</h3>
                  <div className="flex flex-wrap gap-2">
                    {facilityList(detailVenue).map((item) => (
                      <span key={item} className="px-3 py-1.5 bg-primary/8 text-primary rounded-lg text-sm font-medium border border-primary/10">{item}</span>
                    ))}
                  </div>
                </div>
              )}

              {/* Equipment */}
              {(detailVenue.equipments?.length ?? 0) > 0 && (
                <div>
                  <h3 className="text-sm font-bold text-foreground mb-3">貸出備品</h3>
                  <div className="space-y-2">
                    {(detailVenue.equipments ?? []).map((eq: { name: string; qty: number; fee: number }, i: number) => (
                      <div key={i} className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg text-sm">
                        <span className="font-medium">{eq.name} <span className="text-muted">x{eq.qty}個</span></span>
                        <span className={`font-medium ${eq.fee === 0 ? "text-green-600" : "text-foreground"}`}>
                          {eq.fee === 0 ? "無料" : `¥${eq.fee.toLocaleString()}`}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Edit button */}
              {user && (
                <button onClick={() => handleStartEdit(detailVenue)}
                  className="w-full px-4 py-3.5 border-2 border-primary text-primary rounded-xl text-sm font-bold hover:bg-primary hover:text-white transition-all">
                  この会場の情報を編集する
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ===== Add/Edit Form Modal ===== */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={resetForm}>
          <div className="bg-white rounded-2xl w-full max-w-[640px] max-h-[85vh] overflow-y-auto shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between rounded-t-2xl z-10">
              <h2 className="text-lg font-bold text-foreground">
                {editingVenue ? "会場を編集" : "新しい会場を追加"}
              </h2>
              <button onClick={resetForm} className="p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-6">
              {/* Basic Info */}
              <FormSection title="基本情報">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <FormField label="会場名" required>
                    <input type="text" value={formName} onChange={(e) => setFormName(e.target.value)} placeholder="例: 東京体育館" className="form-input" required />
                  </FormField>
                  <FormField label="住所" required>
                    <input type="text" value={formAddress} onChange={(e) => setFormAddress(e.target.value)} placeholder="例: 東京都渋谷区..." className="form-input" required />
                  </FormField>
                  <FormField label="電話番号">
                    <input type="tel" value={formPhone} onChange={(e) => setFormPhone(e.target.value)} placeholder="例: 03-1234-5678" className="form-input" />
                  </FormField>
                  <FormField label="最寄り駅・バス停">
                    <input type="text" value={formStation} onChange={(e) => setFormStation(e.target.value)} placeholder="例: JR原宿駅 徒歩10分" className="form-input" />
                  </FormField>
                </div>
              </FormSection>

              {/* Facility Info */}
              <FormSection title="施設情報">
                <div className="grid grid-cols-2 gap-4 mb-4">
                  <FormField label="コート数">
                    <input type="number" value={formCourts} onChange={(e) => setFormCourts(e.target.value)} placeholder="例: 4" min={0} className="form-input" />
                  </FormField>
                  <FormField label="駐車場(台数)">
                    <input type="number" value={formParking} onChange={(e) => setFormParking(e.target.value)} placeholder="例: 100" min={0} className="form-input" />
                  </FormField>
                </div>
                <div className="flex flex-wrap gap-3">
                  <FacilityToggle label="トイレ" checked={formHasToilet} onChange={setFormHasToilet} />
                  <FacilityToggle label="更衣室" checked={formHasChangeRoom} onChange={setFormHasChangeRoom} />
                  <FacilityToggle label="シャワー" checked={formHasShower} onChange={setFormHasShower} />
                  <FacilityToggle label="観覧席" checked={formHasGallery} onChange={setFormHasGallery} />
                  <FacilityToggle label="空調" checked={formHasAC} onChange={setFormHasAC} />
                </div>
                <div className="mt-4">
                  <FormField label="飲食可能エリア">
                    <input type="text" value={formEatArea} onChange={(e) => setFormEatArea(e.target.value)} placeholder="例: 2階控室のみ可" className="form-input" />
                  </FormField>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-4">
                  <FormField label="床の種類">
                    <select value={formFloorType} onChange={(e) => setFormFloorType(e.target.value)} className="form-input">
                      <option value="">未選択</option>
                      <option value="板張り">板張り</option>
                      <option value="ゴム">ゴム</option>
                      <option value="その他">その他</option>
                    </select>
                  </FormField>
                  <FormField label="ネットポールの種類">
                    <select value={formPoleType} onChange={(e) => setFormPoleType(e.target.value)} className="form-input">
                      <option value="">未選択</option>
                      <option value="床差し込み式">床差し込み式</option>
                      <option value="置き型">置き型</option>
                      <option value="不明">不明</option>
                    </select>
                  </FormField>
                  <FormField label="ポール高さ調節">
                    <select value={formPoleAdjustable} onChange={(e) => setFormPoleAdjustable(e.target.value)} className="form-input">
                      <option value="">未選択</option>
                      <option value="可">可</option>
                      <option value="不可">不可</option>
                      <option value="不明">不明</option>
                    </select>
                  </FormField>
                </div>
              </FormSection>

              {/* Usage Info */}
              <FormSection title="利用情報">
                <div className="grid grid-cols-3 gap-4">
                  <FormField label="利用開始">
                    <input type="text" value={formOpenTime} onChange={(e) => setFormOpenTime(e.target.value)} className="form-input" />
                  </FormField>
                  <FormField label="利用終了">
                    <input type="text" value={formCloseTime} onChange={(e) => setFormCloseTime(e.target.value)} className="form-input" />
                  </FormField>
                  <FormField label="利用料金(目安)">
                    <input type="text" value={formFee} onChange={(e) => setFormFee(e.target.value)} placeholder="例: 1時間¥2,000" className="form-input" />
                  </FormField>
                </div>
              </FormSection>

              {/* Equipment */}
              <FormSection title="貸出備品">
                {formEquipments.length > 0 && (
                  <div className="space-y-2 mb-4">
                    {formEquipments.map((eq, i) => (
                      <div key={i} className="flex items-center justify-between py-2 px-3 bg-gray-50 rounded-lg text-sm">
                        <span>{eq.name} x{eq.qty}個 — {eq.fee === 0 ? "無料" : `¥${eq.fee}`}</span>
                        <button type="button" onClick={() => setFormEquipments(formEquipments.filter((_, j) => j !== i))}
                          className="p-1 text-red-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors">
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                        </button>
                      </div>
                    ))}
                  </div>
                )}
                <div className="flex gap-2 items-end">
                  <FormField label="備品名"><input type="text" value={eqName} onChange={(e) => setEqName(e.target.value)} placeholder="備品名" className="form-input" /></FormField>
                  <FormField label="数量"><input type="number" value={eqQty} onChange={(e) => setEqQty(e.target.value)} placeholder="1" min={1} className="form-input w-20" /></FormField>
                  <FormField label="料金"><input type="number" value={eqFee} onChange={(e) => setEqFee(e.target.value)} placeholder="0" min={0} className="form-input w-24" /></FormField>
                  <button type="button" onClick={addEquipment} className="px-4 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors flex-shrink-0">追加</button>
                </div>
              </FormSection>

              {/* Notes */}
              <FormSection title="備考">
                <textarea value={formNotes} onChange={(e) => setFormNotes(e.target.value)}
                  placeholder="例: ネットは持ち込み必要、照明がやや暗め、受付は正面入口の事務室 等"
                  rows={3} className="form-input w-full resize-y" />
              </FormSection>

              {/* Submit */}
              <div className="flex gap-3 pt-4 border-t border-gray-100">
                <button type="submit" disabled={formSaving}
                  className="btn-primary flex-1 py-3 justify-center">
                  {formSaving ? "保存中..." : editingVenue ? "更新する" : "追加する"}
                </button>
                <button type="button" onClick={resetForm}
                  className="px-6 py-3 border border-gray-300 rounded-xl text-sm font-medium text-muted hover:text-foreground transition-colors">
                  キャンセル
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ===== Search & Filters ===== */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 mb-6">
        <div className="flex flex-wrap gap-3 items-center">
          <div className="flex-1 min-w-[240px] relative">
            <svg className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}><path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" /></svg>
            <input type="search" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder="会場名・住所で検索..."
              className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:border-primary focus:ring-2 focus:ring-primary/10" />
          </div>
          <select value={prefFilter} onChange={(e) => setPrefFilter(e.target.value)} className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm bg-white">
            {prefectures.map((p) => <option key={p} value={p}>{p === "すべて" ? "都道府県: すべて" : p}</option>)}
          </select>
          <select value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)} className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm bg-white">
            <option value="name">名前順</option><option value="address">住所順</option><option value="courts">コート数順</option><option value="rating">評価順</option>
          </select>
        </div>
      </div>

      <p className="text-sm text-muted mb-4">{filtered.length}件の会場</p>

      {/* ===== Venue Cards ===== */}
      {filtered.length === 0 ? (
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-gray-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 21h19.5m-18-18v18m10.5-18v18m6-13.5V21M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 7.5h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z" /></svg>
          <h3 className="text-lg font-bold text-foreground mb-2">会場が見つかりません</h3>
          <p className="text-sm text-muted">検索条件を変更するか、新しい会場を追加してください</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filtered.map((venue) => (
            <div key={venue.id}
              className="bg-white rounded-xl border border-gray-200 p-5 hover:shadow-lg hover:border-primary/20 transition-all cursor-pointer group"
              onClick={() => setDetailVenue(venue)}>
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <h3 className="text-base font-bold text-foreground truncate">{venue.name}</h3>
                  <p className="flex items-center gap-1.5 text-sm text-muted mt-1.5">
                    <svg className="w-4 h-4 flex-shrink-0 text-primary/60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" /></svg>
                    <span className="truncate">{venue.address}</span>
                  </p>
                </div>
                {user && (
                  <button onClick={(e) => { e.stopPropagation(); handleStartEdit(venue); }}
                    className="p-2 text-gray-400 hover:text-primary hover:bg-primary/10 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                    title="編集">
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                  </button>
                )}
              </div>

              {/* Facility chips */}
              {facilityList(venue).length > 0 && (
                <div className="flex items-center gap-2 mt-3 pt-3 border-t border-gray-100 flex-wrap">
                  {facilityList(venue).slice(0, 4).map((item) => (
                    <span key={item} className="px-2 py-1 bg-gray-100 text-gray-600 rounded-md text-xs font-medium">{item}</span>
                  ))}
                  {facilityList(venue).length > 4 && (
                    <span className="text-xs text-muted">+{facilityList(venue).length - 4}</span>
                  )}
                  {(venue.rating ?? 0) > 0 && (
                    <div className="flex items-center gap-1 ml-auto">
                      <svg className="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" /></svg>
                      <span className="text-sm font-medium text-foreground">{(venue.rating ?? 0).toFixed(1)}</span>
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ==============================
   Sub Components
   ============================== */

function FormSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h3 className="text-sm font-bold text-foreground mb-3 pb-2 border-b border-gray-100">{title}</h3>
      {children}
    </div>
  );
}

function FormField({ label, required, children }: { label: string; required?: boolean; children: React.ReactNode }) {
  return (
    <div className="flex-1">
      <label className="block text-xs font-medium text-muted mb-1.5">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );
}

function FacilityToggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button type="button" onClick={() => onChange(!checked)}
      className={`px-4 py-2 rounded-xl text-sm font-medium transition-all border ${
        checked
          ? "bg-primary text-white border-primary"
          : "bg-white text-muted border-gray-200 hover:border-primary/30"
      }`}>
      {checked && <span className="mr-1">✓</span>}
      {label}
    </button>
  );
}

function DetailRow({ label, value, icon }: { label: string; value: string; icon: React.ReactNode }) {
  return (
    <div className="flex items-center gap-3 py-3">
      <div className="text-primary flex-shrink-0">{icon}</div>
      <div className="flex-1 min-w-0">
        <p className="text-xs text-muted">{label}</p>
        <p className="text-sm font-medium text-foreground">{value}</p>
      </div>
    </div>
  );
}
