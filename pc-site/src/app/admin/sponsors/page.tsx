"use client";

import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

interface Sponsor {
  id: string;
  name: string;
  logoUrl?: string;
  websiteUrl?: string;
  tier?: string;
  description?: string;
  active?: boolean;
  sortOrder?: number;
}

const tiers = ["Platinum", "Gold", "Silver", "Bronze", "Partner"];

export default function AdminSponsorsPage() {
  const [items, setItems] = useState<Sponsor[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [name, setName] = useState("");
  const [logoUrl, setLogoUrl] = useState("");
  const [websiteUrl, setWebsiteUrl] = useState("");
  const [tier, setTier] = useState("Partner");
  const [description, setDescription] = useState("");
  const [active, setActive] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const q = query(collection(db, "sponsors"), orderBy("sortOrder", "asc"));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Sponsor)));
        setLoading(false);
      },
      () => {
        const q2 = query(collection(db, "sponsors"), orderBy("name", "asc"));
        const unsub2 = onSnapshot(
          q2,
          (snap) => {
            setItems(snap.docs.map((d) => ({ id: d.id, ...d.data() } as Sponsor)));
            setLoading(false);
          },
          () => setLoading(false)
        );
        return unsub2;
      }
    );
    return () => unsub();
  }, []);

  const resetForm = () => {
    setEditingId(null);
    setName("");
    setLogoUrl("");
    setWebsiteUrl("");
    setTier("Partner");
    setDescription("");
    setActive(true);
    setShowForm(false);
  };

  const startEdit = (s: Sponsor) => {
    setEditingId(s.id);
    setName(s.name);
    setLogoUrl(s.logoUrl ?? "");
    setWebsiteUrl(s.websiteUrl ?? "");
    setTier(s.tier ?? "Partner");
    setDescription(s.description ?? "");
    setActive(s.active ?? true);
    setShowForm(true);
  };

  const submit = async () => {
    if (!name.trim()) { alert("スポンサー名を入力してください"); return; }
    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        logoUrl: logoUrl.trim() || null,
        websiteUrl: websiteUrl.trim() || null,
        tier,
        description: description.trim() || null,
        active,
        updatedAt: serverTimestamp(),
      };
      if (editingId) {
        await updateDoc(doc(db, "sponsors", editingId), payload);
      } else {
        await addDoc(collection(db, "sponsors"), {
          ...payload,
          sortOrder: items.length,
          createdAt: serverTimestamp(),
        });
      }
      resetForm();
    } catch {
      alert("保存に失敗しました");
    } finally {
      setSaving(false);
    }
  };

  const remove = async (s: Sponsor) => {
    if (!confirm(`「${s.name}」を削除しますか？`)) return;
    await deleteDoc(doc(db, "sponsors", s.id));
  };

  return (
    <div className="p-8 max-w-[900px] mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">スポンサー管理</h1>
          <p className="text-sm text-muted mt-1">スポンサー・パートナー企業の掲載</p>
        </div>
        <button
          onClick={() => (showForm ? resetForm() : setShowForm(true))}
          className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
        >
          {showForm ? "閉じる" : "新規追加"}
        </button>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6 shadow-sm space-y-3">
          <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="スポンサー名" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <input type="text" value={logoUrl} onChange={(e) => setLogoUrl(e.target.value)} placeholder="ロゴ画像URL" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <input type="text" value={websiteUrl} onChange={(e) => setWebsiteUrl(e.target.value)} placeholder="WebサイトURL" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm" />
          <select value={tier} onChange={(e) => setTier(e.target.value)} className="px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white">
            {tiers.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={3} placeholder="説明 (任意)" className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none" />
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
            掲載する
          </label>
          <div className="flex gap-2">
            <button onClick={submit} disabled={saving} className="px-6 py-2 bg-primary text-white rounded-lg text-sm font-medium disabled:opacity-50">
              {saving ? "保存中..." : "保存"}
            </button>
            <button onClick={resetForm} className="px-6 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground">キャンセル</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-7 h-7 border-3 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : items.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-200">
          <p className="text-sm text-muted">スポンサーがまだ登録されていません</p>
        </div>
      ) : (
        <div className="space-y-2">
          {items.map((s) => (
            <div key={s.id} className="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3">
              <div className="w-12 h-12 rounded-lg bg-gray-50 overflow-hidden flex-shrink-0 flex items-center justify-center">
                {s.logoUrl ? (
                  <img src={s.logoUrl} alt={s.name} className="w-full h-full object-contain" />
                ) : (
                  <span className="text-xs text-muted">No logo</span>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-foreground">{s.name}</span>
                  {s.tier && (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
                      {s.tier}
                    </span>
                  )}
                  {!s.active && (
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-muted font-medium">非掲載</span>
                  )}
                </div>
                {s.websiteUrl && <div className="text-xs text-muted truncate">{s.websiteUrl}</div>}
              </div>
              <div className="flex gap-2 flex-shrink-0">
                <button onClick={() => startEdit(s)} className="text-xs text-primary hover:underline">編集</button>
                <button onClick={() => remove(s)} className="text-xs text-error hover:underline">削除</button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
