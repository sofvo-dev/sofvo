"use client";

import { useState } from "react";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useRouter } from "next/navigation";

const slides = [
  {
    title: "大会をさがす",
    description:
      "お近くのソフトバレーボール大会を検索してエントリーできます。地域・日程・レベルで絞り込みも可能です。",
    accent: "text-primary",
    bg: "bg-primary/8",
  },
  {
    title: "かんたんエントリー",
    description:
      "気になる大会を見つけたら「エントリー」ボタンをクリックするだけ。チームメンバーを登録して参加しましょう。",
    accent: "text-success",
    bg: "bg-green-500/8",
  },
  {
    title: "タイムライン",
    description:
      "他のプレイヤーの投稿をチェックしたり、自分の活動を共有できます。大会の感想や練習の様子を発信しましょう。",
    accent: "text-purple-600",
    bg: "bg-purple-500/8",
  },
  {
    title: "仲間とつながる",
    description:
      "フォロー機能で仲間とつながれます。友達招待リンクを送って一緒にSofvoを楽しみましょう！",
    accent: "text-accent",
    bg: "bg-accent/8",
  },
];

const prefectures = [
  "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
  "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
  "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
  "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
  "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
  "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
  "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
];

const experienceLevels = ["1年未満", "1〜3年", "3〜5年", "5〜10年", "10年以上"];

export default function OnboardingPage() {
  const router = useRouter();
  const { user, profile, loading: authLoading } = useAuth();
  const [step, setStep] = useState(0);
  const [nickname, setNickname] = useState(profile?.nickname ?? "");
  const [area, setArea] = useState(typeof profile?.area === "string" ? profile.area : "");
  const [experience, setExperience] = useState(profile?.experience ?? "");
  const [gender, setGender] = useState(profile?.gender ?? "");
  const [bio, setBio] = useState(profile?.bio ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const totalSteps = slides.length + 1;

  const finish = async () => {
    if (!user) {
      router.push("/login");
      return;
    }
    if (!nickname.trim()) {
      setError("ニックネームを入力してください");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await updateDoc(doc(db, "users", user.uid), {
        nickname: nickname.trim(),
        area,
        experience,
        gender,
        bio: bio.trim(),
        profileCompleted: true,
      });
      router.push("/");
    } catch {
      setError("プロフィールの保存に失敗しました");
      setSaving(false);
    }
  };

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-gray-50">
      <div className="w-full max-w-[540px] bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        {/* Progress dots */}
        <div className="flex gap-1.5 px-6 pt-6">
          {Array.from({ length: totalSteps }).map((_, i) => (
            <div
              key={i}
              className={`flex-1 h-1 rounded-full transition-colors ${
                i <= step ? "bg-primary" : "bg-gray-200"
              }`}
            />
          ))}
        </div>

        {step < slides.length ? (
          <div className="p-8">
            <div
              className={`w-24 h-24 mx-auto rounded-2xl ${slides[step].bg} flex items-center justify-center mb-6`}
            >
              <svg className={`w-12 h-12 ${slides[step].accent}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21a3.745 3.745 0 01-3.068-1.593 3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12a3.745 3.745 0 011.593-3.068 3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3a3.746 3.746 0 013.068 1.593 3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />
              </svg>
            </div>
            <h1 className="text-2xl font-bold text-foreground text-center mb-3">
              {slides[step].title}
            </h1>
            <p className="text-sm text-muted text-center leading-relaxed mb-8 whitespace-pre-wrap">
              {slides[step].description}
            </p>
            <div className="flex items-center justify-between gap-3">
              <button
                onClick={() => setStep(totalSteps - 1)}
                className="text-sm text-muted hover:text-foreground"
              >
                スキップ
              </button>
              <button
                onClick={() => setStep((s) => s + 1)}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
              >
                次へ
              </button>
            </div>
          </div>
        ) : (
          <div className="p-8">
            <div className="text-center mb-6">
              <div className="w-16 h-16 mx-auto rounded-2xl bg-accent/10 flex items-center justify-center mb-4">
                <svg className="w-8 h-8 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                </svg>
              </div>
              <h2 className="text-xl font-bold text-foreground">プロフィール設定</h2>
              <p className="text-sm text-muted mt-1">あとから変更できます</p>
            </div>

            {error && (
              <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
                {error}
              </div>
            )}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">
                  ニックネーム <span className="text-error">*</span>
                </label>
                <input
                  type="text"
                  value={nickname}
                  onChange={(e) => setNickname(e.target.value)}
                  placeholder="表示名"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">自己紹介</label>
                <textarea
                  value={bio}
                  onChange={(e) => setBio(e.target.value)}
                  rows={3}
                  placeholder="プレイスタイルや好きなポジションなど"
                  className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">エリア</label>
                  <select
                    value={area}
                    onChange={(e) => setArea(e.target.value)}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
                  >
                    <option value="">選択</option>
                    {prefectures.map((p) => (
                      <option key={p} value={p}>{p}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-foreground mb-1.5">経験年数</label>
                  <select
                    value={experience}
                    onChange={(e) => setExperience(e.target.value)}
                    className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
                  >
                    <option value="">選択</option>
                    {experienceLevels.map((l) => (
                      <option key={l} value={l}>{l}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-foreground mb-1.5">性別</label>
                <div className="flex gap-2">
                  {["男性", "女性", "その他"].map((g) => (
                    <button
                      key={g}
                      type="button"
                      onClick={() => setGender(g)}
                      className={`flex-1 py-2 text-sm font-medium rounded-lg transition-colors ${
                        gender === g
                          ? "bg-primary text-white"
                          : "bg-gray-100 text-muted hover:bg-gray-200"
                      }`}
                    >
                      {g}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="flex items-center justify-between gap-3 mt-8">
              <button
                onClick={() => setStep((s) => Math.max(0, s - 1))}
                className="text-sm text-muted hover:text-foreground"
              >
                戻る
              </button>
              <div className="flex gap-2">
                {!user && (
                  <Link
                    href="/login"
                    className="px-4 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-foreground hover:border-gray-400 transition-colors"
                  >
                    ログイン
                  </Link>
                )}
                <button
                  onClick={finish}
                  disabled={saving}
                  className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
                >
                  {saving ? "保存中..." : user ? "Sofvoを始める" : "次へ"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
