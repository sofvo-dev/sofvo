# Instagram → アプリ公式ページ 自動同期（セットアップ手順）

@**sofvo.official** の投稿を、アプリの**公式アカウントの投稿**として自動で取り込む仕組み。
取り込まれた投稿は **公式プロフィールの「投稿」タブ** と、**（公式を自動フォロー済みの）全ユーザーのホーム**に自動で並ぶ。

- 実装: `functions/index.js`（`syncInstagramCore` ほか）
- 認証情報の保存先: Firestore `secrets/instagram`（**クライアントからは読めない**・Functions と Firebase 管理コンソールのみ）
- 取り込み先: `posts` コレクション（ドキュメントID `ig_{メディアID}` で重複防止）
- 画像: IG の一時URLは失効するため、**Firebase Storage（`official_instagram/`）に再保存**して表示

---

## 仕組み（コード側は実装済み・デプロイで有効）

| 関数 | 種別 | 役割 |
|---|---|---|
| `scheduledSyncInstagram` | 定期（6時間ごと） | 新着投稿を取得して `posts` に保存 |
| `syncInstagramNow` | URL（手動） | すぐ同期したいとき。ブラウザで開くだけ |
| `refreshInstagramToken` | 定期（10日ごと） | 長期トークンを自動延長（60日期限切れ防止） |
| `setInstagramConfig` | 管理者呼び出し | トークン等の登録（コンソール直編集でも可） |

---

## あなたがやること（Meta 側の準備 → トークン登録）

### 1. @sofvo.official を「ビジネス」か「クリエイター」に変更
Instagram アプリ → 設定 → アカウントの種類とツール → プロアカウントに切り替え。
（旧 Basic Display API は2024年末に廃止されたため、ビジネス/クリエイター＋Graph API が必須）

### 2. Meta 開発者アプリを作成してトークンを取得
1. https://developers.facebook.com/ でアプリを作成（タイプ: 「ビジネス」）
2. プロダクト「**Instagram**（Instagram API setup with Instagram login）」を追加
3. @sofvo.official を接続し、**長期アクセストークン（long-lived token）**を発行
   - 権限は最低 `instagram_business_basic`（投稿の読み取り）
   - 短期トークンしか出ない場合は長期トークンへ交換（`ig_exchange_token`）
4. 発行された**アクセストークン文字列**を控える

> 詳細な画面手順は Meta 側の UI 改訂が多いため、公式ドキュメント「Instagram API with Instagram Login」を参照。要は **@sofvo.official の長期ユーザーアクセストークン**が1本あればOK。

### 3. トークンをアプリに登録（どちらか）
**方法A（かんたん・推奨）: Firebase コンソールで直接入力**
1. Firebase コンソール → Firestore → コレクション `secrets` → ドキュメント `instagram` を作成
2. フィールドを追加:
   - `accessToken`（文字列）= 取得したトークン
   - （任意）`officialUid`（文字列）= 投稿主にする公式アカウントのUID。未指定なら `isOfficial==true` の先頭アカウントを使用
   - ※ `secrets` はセキュリティルールで全クライアント遮断済み。コンソール（オーナー権限）はルールをバイパスするので入力できる

**方法B: 関数 `setInstagramConfig` を管理者アカウントで呼ぶ**
`{ accessToken: "...", officialUid: "..." }`

### 4. 初回同期を実行（すぐ反映したいとき）
ブラウザで以下を開く（`main` マージ後、デプロイ完了後）:
```
https://us-central1-sofvo-19d84.cloudfunctions.net/syncInstagramNow
```
`{"fetched":N,"created":M}` が返れば成功。以降は6時間ごとに自動同期。
`{"skipped":true,"reason":"アクセストークン未設定"}` が返る場合は手順3が未完。

---

## 動作・仕様メモ
- **重複防止**: `posts/ig_{メディアID}`。同じ投稿は二重に作られない。
- **カルーセル**: 全スライドを画像として取り込む。**動画**はサムネイルを画像として取り込む（本編はIGで視聴）。
- **キャプション**: そのまま投稿本文に入る。
- **並び順**: IG の投稿日時で `createdAt` を設定するので、時系列が保たれる。
- **アプリ改修は不要**: 通常の `posts` として保存するため、既存のタイムライン表示でそのまま出る。
- **トークン期限**: 長期トークンは約60日。`refreshInstagramToken` が10日ごとに自動延長するので基本は放置でOK。もし長期間アプリが動かずトークンが失効したら、手順3でトークンを入れ直す。
- **エラー確認**: `secrets/instagram` の `lastError` / `lastSyncedAt` フィールドで最終結果を確認できる。
