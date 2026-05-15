"use client";

import { useRef, useState, useEffect } from "react";
import { doc, updateDoc, deleteDoc, setDoc, Timestamp, serverTimestamp } from "firebase/firestore";
import {
  updatePassword,
  reauthenticateWithCredential,
  EmailAuthProvider,
  deleteUser,
} from "firebase/auth";
import { ref as storageRef, uploadBytes, getDownloadURL } from "firebase/storage";
import { db, storage } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import Link from "next/link";
import { useRouter } from "next/navigation";

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

const VALID_GENDERS = ["男性", "女性", "その他"] as const;

function timestampToDateInput(ts: unknown): string {
  if (
    ts != null &&
    typeof ts === "object" &&
    "toDate" in ts &&
    typeof (ts as { toDate: unknown }).toDate === "function"
  ) {
    const d = (ts as { toDate: () => Date }).toDate();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${y}-${m}-${day}`;
  }
  return "";
}

export default function SettingsPage() {
  const router = useRouter();
  const { user, profile, loading: authLoading, signOut } = useAuth();
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const [avatarUrl, setAvatarUrl] = useState(profile?.avatarUrl ?? "");
  const [avatarUploading, setAvatarUploading] = useState(false);
  const [avatarError, setAvatarError] = useState("");

  const [nickname, setNickname] = useState(profile?.nickname ?? "");
  const [bio, setBio] = useState(profile?.bio ?? "");
  const [experience, setExperience] = useState(profile?.experience ?? "");
  const [area, setArea] = useState(
    typeof profile?.area === "string" ? profile.area : ""
  );
  const [gender, setGender] = useState(profile?.gender ?? "");
  const [birthDate, setBirthDate] = useState("");

  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");

  const [profileSaving, setProfileSaving] = useState(false);
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [profileMessage, setProfileMessage] = useState("");
  const [passwordMessage, setPasswordMessage] = useState("");
  const [profileError, setProfileError] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [deleteConfirm, setDeleteConfirm] = useState("");
  const [deletePassword, setDeletePassword] = useState("");

  useEffect(() => {
    if (profile?.birthDate && typeof profile.birthDate.toDate === "function") {
      setBirthDate(timestampToDateInput(profile.birthDate));
    }
  }, [profile]);

  if (authLoading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user || !profile) {
    return (
      <div className="p-8 max-w-[1200px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <div className="text-4xl mb-4">🔒</div>
          <h3 className="text-lg font-bold text-foreground mb-2">ログインが必要です</h3>
          <Link
            href="/login"
            className="inline-flex px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !user) return;
    if (file.size > 5 * 1024 * 1024) {
      setAvatarError("5MB以下の画像を選択してください");
      return;
    }
    setAvatarUploading(true);
    setAvatarError("");
    try {
      const ext = file.name.split(".").pop() || "jpg";
      const path = `avatars/${user.uid}/${Date.now()}.${ext}`;
      const ref = storageRef(storage, path);
      await uploadBytes(ref, file);
      const url = await getDownloadURL(ref);
      await updateDoc(doc(db, "users", user.uid), { avatarUrl: url });
      setAvatarUrl(url);
    } catch {
      setAvatarError("アップロードに失敗しました");
    } finally {
      setAvatarUploading(false);
      if (avatarInputRef.current) avatarInputRef.current.value = "";
    }
  };

  const handleAvatarRemove = async () => {
    if (!user) return;
    if (!confirm("アイコン画像を削除しますか？")) return;
    setAvatarUploading(true);
    try {
      await updateDoc(doc(db, "users", user.uid), { avatarUrl: "" });
      setAvatarUrl("");
    } finally {
      setAvatarUploading(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!user) return;
    if (deleteConfirm !== "アカウントを削除") {
      setDeleteError("確認テキストが一致しません");
      return;
    }
    setDeleting(true);
    setDeleteError("");
    try {
      if (user.providerData[0]?.providerId === "password" && deletePassword) {
        const credential = EmailAuthProvider.credential(user.email!, deletePassword);
        await reauthenticateWithCredential(user, credential);
      }
      await deleteDoc(doc(db, "users", user.uid));
      await deleteUser(user);
      await signOut();
      router.push("/");
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "削除に失敗しました";
      if (msg.includes("requires-recent-login")) {
        setDeleteError("セキュリティ確認のため再ログインが必要です。ログアウト後、再度ログインしてお試しください。");
      } else if (msg.includes("wrong-password")) {
        setDeleteError("パスワードが正しくありません");
      } else {
        setDeleteError("削除に失敗しました");
      }
    } finally {
      setDeleting(false);
    }
  };

  const handleProfileSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setProfileSaving(true);
    setProfileError("");
    setProfileMessage("");

    try {
      if (!gender.trim() || !VALID_GENDERS.includes(gender as (typeof VALID_GENDERS)[number])) {
        setProfileError("性別を選択してください");
        setProfileSaving(false);
        return;
      }
      if (!birthDate.trim()) {
        setProfileError("生年月日を入力してください");
        setProfileSaving(false);
        return;
      }
      const bdParsed = new Date(`${birthDate}T12:00:00`);
      if (Number.isNaN(bdParsed.getTime()) || bdParsed > new Date()) {
        setProfileError("生年月日を正しく入力してください");
        setProfileSaving(false);
        return;
      }

      await updateDoc(doc(db, "users", user.uid), {
        nickname,
        bio,
        experience,
        area,
        gender,
      });
      await setDoc(
        doc(db, "users", user.uid, "private", "info"),
        {
          gender,
          birthDate: Timestamp.fromDate(bdParsed),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      setProfileMessage("プロフィールを更新しました");
    } catch {
      setProfileError("プロフィールの更新に失敗しました");
    } finally {
      setProfileSaving(false);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmNewPassword) {
      setPasswordError("新しいパスワードが一致しません");
      return;
    }
    if (newPassword.length < 6) {
      setPasswordError("パスワードは6文字以上にしてください");
      return;
    }

    setPasswordSaving(true);
    setPasswordError("");
    setPasswordMessage("");

    try {
      const credential = EmailAuthProvider.credential(user.email!, currentPassword);
      await reauthenticateWithCredential(user, credential);
      await updatePassword(user, newPassword);
      setPasswordMessage("パスワードを変更しました");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmNewPassword("");
    } catch {
      setPasswordError("パスワードの変更に失敗しました。現在のパスワードを確認してください");
    } finally {
      setPasswordSaving(false);
    }
  };

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-6">設定</h1>

      {/* Avatar */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
          アイコン画像
        </h2>
        {avatarError && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
            {avatarError}
          </div>
        )}
        <div className="flex items-center gap-5">
          <div className="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-2xl overflow-hidden flex-shrink-0">
            {avatarUrl ? (
              <img src={avatarUrl} alt="" className="w-20 h-20 object-cover" />
            ) : (
              profile.nickname?.charAt(0) || "U"
            )}
          </div>
          <div className="flex gap-2">
            <input
              ref={avatarInputRef}
              type="file"
              accept="image/*"
              onChange={handleAvatarUpload}
              className="hidden"
            />
            <button
              onClick={() => avatarInputRef.current?.click()}
              disabled={avatarUploading}
              className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {avatarUploading ? "アップロード中..." : avatarUrl ? "画像を変更" : "画像をアップロード"}
            </button>
            {avatarUrl && (
              <button
                onClick={handleAvatarRemove}
                disabled={avatarUploading}
                className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-muted hover:text-error hover:border-error/50 transition-colors disabled:opacity-50"
              >
                削除
              </button>
            )}
          </div>
        </div>
        <p className="text-xs text-muted mt-3">JPEG/PNG/GIF、5MB以下</p>
      </div>

      {/* Profile Settings */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
          プロフィール編集
        </h2>

        {profileMessage && (
          <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-lg">
            {profileMessage}
          </div>
        )}
        {profileError && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg">
            {profileError}
          </div>
        )}

        <form onSubmit={handleProfileSave} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">ニックネーム</label>
            <input
              type="text"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">自己紹介</label>
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              rows={3}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm resize-none"
              placeholder="自己紹介を入力..."
            />
          </div>
          <div className="grid grid-cols-3 gap-4">
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
              <label className="block text-sm font-medium text-foreground mb-1.5">性別 <span className="text-error">*</span></label>
              <select
                value={gender}
                onChange={(e) => setGender(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm bg-white"
              >
                <option value="">選択してください</option>
                <option value="男性">男性</option>
                <option value="女性">女性</option>
                <option value="その他">その他</option>
              </select>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-foreground mb-1.5">
              生年月日 <span className="text-error">*</span>
            </label>
            <input
              type="date"
              value={birthDate}
              onChange={(e) => setBirthDate(e.target.value)}
              max={new Date().toISOString().slice(0, 10)}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
            />
          </div>
          <div className="pt-2">
            <button
              type="submit"
              disabled={profileSaving}
              className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
            >
              {profileSaving ? "保存中..." : "プロフィールを保存"}
            </button>
          </div>
        </form>
      </div>

      {/* Password Change */}
      {user.providerData[0]?.providerId === "password" && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
          <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
            パスワード変更
          </h2>

          {passwordMessage && (
            <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 text-sm rounded-lg">
              {passwordMessage}
            </div>
          )}
          {passwordError && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg">
              {passwordError}
            </div>
          )}

          <form onSubmit={handlePasswordChange} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">現在のパスワード</label>
              <input
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">新しいパスワード</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                placeholder="6文字以上"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1.5">新しいパスワード（確認）</label>
              <input
                type="password"
                value={confirmNewPassword}
                onChange={(e) => setConfirmNewPassword(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
                required
              />
            </div>
            <div className="pt-2">
              <button
                type="submit"
                disabled={passwordSaving}
                className="px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
              >
                {passwordSaving ? "変更中..." : "パスワードを変更"}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Account Info */}
      <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
        <h2 className="text-base font-bold text-foreground mb-4 pb-3 border-b border-gray-100">
          アカウント情報
        </h2>
        <div className="space-y-3">
          <div className="flex items-baseline justify-between">
            <span className="text-sm text-muted">メールアドレス</span>
            <span className="text-sm font-medium text-foreground">{user.email}</span>
          </div>
          <div className="flex items-baseline justify-between">
            <span className="text-sm text-muted">ログイン方法</span>
            <span className="text-sm font-medium text-foreground">
              {user.providerData[0]?.providerId === "google.com" ? "Google" : "メール/パスワード"}
            </span>
          </div>
          <div className="flex items-baseline justify-between">
            <span className="text-sm text-muted">ユーザーID</span>
            <span className="text-xs font-mono text-muted">{user.uid}</span>
          </div>
        </div>
      </div>

      {/* Danger zone */}
      <div className="bg-white rounded-xl border border-red-200 p-6">
        <h2 className="text-base font-bold text-error mb-4 pb-3 border-b border-red-100">
          アカウント削除
        </h2>
        <p className="text-sm text-muted mb-4">
          アカウントを削除すると、投稿・チャット履歴・エントリー情報などすべてのデータが削除されます。この操作は取り消せません。
        </p>

        {deleteError && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 text-error text-sm rounded-lg">
            {deleteError}
          </div>
        )}

        <div className="space-y-3">
          <div>
            <label className="block text-xs text-muted mb-1">
              確認のため「<span className="font-mono text-error">アカウントを削除</span>」と入力してください
            </label>
            <input
              type="text"
              value={deleteConfirm}
              onChange={(e) => setDeleteConfirm(e.target.value)}
              className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
              placeholder="アカウントを削除"
            />
          </div>
          {user.providerData[0]?.providerId === "password" && (
            <div>
              <label className="block text-xs text-muted mb-1">現在のパスワード</label>
              <input
                type="password"
                value={deletePassword}
                onChange={(e) => setDeletePassword(e.target.value)}
                className="w-full px-3 py-2.5 border border-gray-300 rounded-lg text-sm"
              />
            </div>
          )}
          <button
            onClick={handleDeleteAccount}
            disabled={deleting || deleteConfirm !== "アカウントを削除"}
            className="px-6 py-2.5 bg-error text-white rounded-lg text-sm font-medium hover:bg-red-700 transition-colors disabled:opacity-50"
          >
            {deleting ? "削除中..." : "アカウントを完全に削除する"}
          </button>
        </div>
      </div>
    </div>
  );
}
