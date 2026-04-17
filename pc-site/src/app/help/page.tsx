"use client";

import { useState } from "react";
import {
  collection,
  query,
  where,
  getDocs,
  addDoc,
  serverTimestamp,
  doc,
  getDoc,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";

interface FaqItem {
  q: string;
  a: string;
}

interface Category {
  title: string;
  items: FaqItem[];
}

const OFFICIAL_UID = "zlBy8aWUlCYjyy0NUU9HidrQu983";

const CATEGORIES: Category[] = [
  {
    title: "アカウント",
    items: [
      {
        q: "アカウントの作成方法は？",
        a: "トップ画面の「新規登録」から、メールアドレス・Google・Appleアカウントのいずれかで登録できます。\n\nメール登録の場合は確認メールが届きますので、メール内のリンクをクリックして認証を完了してください。",
      },
      {
        q: "パスワードを忘れました",
        a: "ログイン画面の「パスワードをお忘れですか？」をタップし、登録メールアドレスを入力してください。パスワードリセット用のメールが届きます。\n\nGoogle・Appleログインの場合はパスワードリセットは不要です。",
      },
      {
        q: "プロフィールを変更したい",
        a: "マイページ → 設定から、ニックネーム・アイコン・自己紹介・経験年数・地域などを変更できます。",
      },
      {
        q: "メールアドレスを変更したい",
        a: "設定画面の「アカウント」セクションからメールアドレスを変更できます。\n\n※ Google・Appleログインの場合は認証メールの変更はできません。",
      },
      {
        q: "アカウントを削除したい",
        a: "設定画面の最下部にある「アカウント削除」から手続きできます。\n\n削除すると、投稿・チャット履歴・エントリー情報などすべてのデータが削除されます。この操作は取り消せません。",
      },
    ],
  },
  {
    title: "大会",
    items: [
      {
        q: "大会の作成方法は？",
        a: "サイドバーの「大会作成」から新しい大会を作成できます。\n\n大会名・日程・会場・コート数・募集チーム数・参加費・カテゴリ・ルールなどを設定します。",
      },
      {
        q: "大会にエントリーするには？",
        a: "「大会一覧」から大会を探し、大会詳細ページの「エントリーする」ボタンからエントリーできます。\n\nチーム名とメンバーを入力して送信してください。",
      },
      {
        q: "エントリーの締め切りは変更できますか？",
        a: "はい。大会管理 → 対象の大会 → 「大会を編集」から締切日を変更できます。",
      },
      {
        q: "エントリーをキャンセルしたい",
        a: "大会詳細ページの自分のエントリーから「エントリー取消」ができます。\n\n※ 大会主催者にはキャンセルの通知が届きます。",
      },
      {
        q: "大会のステータスとは？",
        a: "大会には以下のステータスがあります：\n\n• 準備中：大会の設定中\n• 募集中：エントリー受付中\n• エントリー締切：募集終了\n• 開催中：大会進行中\n• 終了：大会終了\n\n主催者は大会管理画面からステータスを変更できます。",
      },
      {
        q: "対戦表・スコアの入力方法は？",
        a: "大会詳細 → 主催者メニュー → 対戦表管理から、予選リーグや決勝トーナメントの対戦表を作成・スコア入力できます。\n\nCSVインポートにも対応しています。",
      },
    ],
  },
  {
    title: "メンバー募集",
    items: [
      {
        q: "メンバー募集の作成方法は？",
        a: "「メンバー募集」ページから新しい募集を作成できます。\n\n募集内容・日時・場所・レベル・人数などを入力してください。",
      },
      {
        q: "募集に応募するには？",
        a: "募集詳細ページの「応募する」ボタンから応募できます。主催者が承認すると参加が確定します。",
      },
    ],
  },
  {
    title: "チャット",
    items: [
      {
        q: "チャットの始め方は？",
        a: "チャット画面の「新しいチャット」ボタンからDMまたはグループチャットを作成できます。\n\nフォロー中のユーザーから相手を選択してください。",
      },
      {
        q: "グループチャットの作成方法は？",
        a: "チャット → 新しいチャット → 「グループチャット」タブから作成できます。\n\nフォロー中のユーザーをメンバーに追加できます。",
      },
      {
        q: "メッセージを削除できますか？",
        a: "自分が送信したメッセージを右クリック/長押しすると削除できます。",
      },
    ],
  },
  {
    title: "フォロー・つながり",
    items: [
      {
        q: "フォローするには？",
        a: "「マイページ → ユーザーを探す」からフォローしたいユーザーを検索し、「フォロー」ボタンをクリックしてください。",
      },
      {
        q: "フォロワー・フォロー中の確認方法は？",
        a: "マイページのフォロワー数・フォロー中数をクリックすると一覧が表示されます。",
      },
    ],
  },
  {
    title: "投稿・タイムライン",
    items: [
      {
        q: "投稿の作成方法は？",
        a: "タイムライン画面の投稿フォームからテキストと画像を投稿できます。",
      },
      {
        q: "投稿を削除したい",
        a: "自分の投稿の右上メニューから削除できます。",
      },
    ],
  },
  {
    title: "その他",
    items: [
      {
        q: "Web版とアプリ版の違いは？",
        a: "基本機能は同じです。アプリ版ではプッシュ通知が届くため、リアルタイムで情報を受け取れます。\n\nApp Store / Google Play からインストールできます。",
      },
      {
        q: "不具合を報告したい",
        a: "このページの「公式アカウントにチャット」ボタンからお問い合わせいただけます。",
      },
      {
        q: "利用規約・プライバシーポリシーはどこで確認できますか？",
        a: "公式サイトの「利用規約」「プライバシーポリシー」ページをご確認ください。",
      },
    ],
  },
];

export default function HelpPage() {
  const router = useRouter();
  const { user, profile } = useAuth();
  const [openCategory, setOpenCategory] = useState<number>(0);
  const [openItems, setOpenItems] = useState<Set<string>>(new Set());
  const [contacting, setContacting] = useState(false);

  const toggleItem = (key: string) => {
    setOpenItems((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const openOfficialChat = async () => {
    if (!user || !profile) {
      router.push("/login");
      return;
    }
    setContacting(true);
    try {
      const existing = await getDocs(
        query(
          collection(db, "chats"),
          where("type", "==", "dm"),
          where("members", "array-contains", user.uid)
        )
      );
      let chatId: string | null = null;
      for (const d of existing.docs) {
        const members = (d.data().members as string[]) ?? [];
        if (members.includes(OFFICIAL_UID)) {
          chatId = d.id;
          break;
        }
      }
      if (!chatId) {
        const offSnap = await getDoc(doc(db, "users", OFFICIAL_UID));
        const offName = (offSnap.data()?.nickname as string) || "【公式】Sofvo";
        const refChat = await addDoc(collection(db, "chats"), {
          type: "dm",
          members: [user.uid, OFFICIAL_UID],
          memberNames: { [user.uid]: profile.nickname, [OFFICIAL_UID]: offName },
          lastMessage: "",
          lastMessageAt: serverTimestamp(),
          lastRead: { [user.uid]: serverTimestamp() },
          createdAt: serverTimestamp(),
        });
        chatId = refChat.id;
      }
      router.push(`/chat/${chatId}`);
    } catch {
      alert("チャットの起動に失敗しました");
    } finally {
      setContacting(false);
    }
  };

  return (
    <div className="p-6 md:p-8 max-w-[900px] mx-auto animate-fade-in">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-foreground">よくある質問</h1>
        <p className="text-sm text-muted mt-1">
          Sofvoの使い方やよくある疑問についてお答えします
        </p>
      </div>

      <div className="flex gap-2 flex-wrap mb-6">
        {CATEGORIES.map((cat, i) => (
          <button
            key={i}
            onClick={() => setOpenCategory(i)}
            className={`px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
              openCategory === i
                ? "bg-primary text-white"
                : "bg-white border border-gray-200 text-muted hover:text-foreground hover:border-gray-300"
            }`}
          >
            {cat.title}
          </button>
        ))}
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden mb-6">
        <div className="px-5 py-3 border-b border-gray-100 bg-primary/5">
          <h2 className="text-sm font-bold text-primary">
            {CATEGORIES[openCategory].title}
          </h2>
        </div>
        <ul className="divide-y divide-gray-100">
          {CATEGORIES[openCategory].items.map((item, i) => {
            const key = `${openCategory}-${i}`;
            const open = openItems.has(key);
            return (
              <li key={key}>
                <button
                  onClick={() => toggleItem(key)}
                  className="w-full flex items-start gap-3 px-5 py-4 text-left hover:bg-gray-50 transition-colors"
                >
                  <svg
                    className="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={1.5}
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z"
                    />
                  </svg>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium text-foreground">{item.q}</div>
                    {open && (
                      <p className="text-sm text-muted mt-3 whitespace-pre-wrap leading-relaxed">
                        {item.a}
                      </p>
                    )}
                  </div>
                  <svg
                    className={`w-4 h-4 text-muted flex-shrink-0 transition-transform ${open ? "rotate-180" : ""}`}
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    strokeWidth={2}
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                  </svg>
                </button>
              </li>
            );
          })}
        </ul>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6 text-center">
        <svg className="w-10 h-10 text-primary mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M8.625 9.75a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375m-13.5 3.01c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 01.865-.501 48.172 48.172 0 003.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.848 0-5.643.175-8.384.513-1.584.233-2.707 1.626-2.707 3.228v9.021z" />
        </svg>
        <h3 className="text-base font-bold text-foreground mb-2">解決しない場合はお問い合わせ</h3>
        <p className="text-sm text-muted mb-4">
          公式アカウントにチャットでお気軽にお問い合わせください
        </p>
        <button
          onClick={openOfficialChat}
          disabled={contacting}
          className="inline-flex items-center gap-2 px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          {contacting ? "起動中..." : "公式アカウントにチャット"}
        </button>
      </div>
    </div>
  );
}
