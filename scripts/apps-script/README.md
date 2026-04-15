# Sofvo App Review Notifier (Google Apps Script)

`info@sofvo.com` に届く Apple / Google Play からの審査関連メールを
Gmail から自動で拾って、`sofvo-dev/sofvo` リポジトリに GitHub Issue を
作成するスクリプト。

これにより、審査通過・リジェクト・審査中などのステータスが GitHub Issue として
記録され、Claude Code からも GitHub MCP 経由で確認できるようになる。

## セットアップ手順

### 1. GitHub Personal Access Token を発行

1. GitHub → Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
2. 「Generate new token」
3. Token name: `sofvo-app-review-notifier`
4. Expiration: お好みで（1年推奨）
5. Repository access: **Only select repositories** → `sofvo-dev/sofvo`
6. Repository permissions: **Issues: Read and write**
7. Generate → 表示されたトークンをコピー（`github_pat_...`）

### 2. Google Apps Script プロジェクトを作成

1. `info@sofvo.com` で Google にログイン
2. https://script.google.com にアクセス
3. **新しいプロジェクト** をクリック
4. プロジェクト名: `Sofvo App Review Notifier`

### 3. スクリプトを貼り付け

1. デフォルトの `Code.gs` を開く
2. `scripts/apps-script/app-review-notifier.gs` の内容を丸ごとコピペ
3. Ctrl+S で保存

### 4. GitHub Token を Script Properties に登録

1. 左メニュー → **プロジェクトの設定**（歯車アイコン）
2. 下部の「スクリプト プロパティ」→ **スクリプト プロパティを追加**
3. プロパティ: `GITHUB_TOKEN`
4. 値: さっき発行したトークン
5. **スクリプト プロパティを保存**

### 5. 初回実行して権限許可

1. エディタに戻る
2. 関数選択で `testCreateIssueFromLatest` を選択
3. **実行** をクリック
4. 「承認が必要です」ダイアログ → **権限を確認** → Google アカウント選択
5. 「このアプリは Google で確認されていません」→ **詳細** → **`Sofvo App Review Notifier` （安全ではないページ）に移動**
6. Gmail 読み取り・外部サービス接続の権限を承認
7. 実行ログに `HTTP 201` と出ればテスト成功（GitHub に `[App Review TEST]` Issue が作成される）

### 6. 定期実行トリガーを設定

1. 左メニュー → **トリガー**（時計アイコン）
2. **トリガーを追加**
3. 設定:
   - 実行する関数: `checkAppReviewEmails`
   - 実行するデプロイ: Head
   - イベントのソース: **時間主導型**
   - 時間ベースのトリガー: **時間ベースのタイマー**
   - 時間の間隔: **1時間ごと**（お好みで）
4. **保存**

以降、1時間ごとに Gmail がスキャンされ、該当メールが見つかれば自動で Issue が作成される。

## 動作確認

### 手動実行
- エディタで関数 `checkAppReviewEmails` を選び **実行**
- 実行ログに `Done. Created: N, Skipped: M` と出れば正常

### Issue の確認
- `sofvo-dev/sofvo` のIssue一覧で `app-review` ラベルを確認
- または Claude Code に「最近の app-review Issue を見せて」と聞けば取得してくれる

## 重複防止の仕組み

処理済みメールには Gmail 側で `AppReview/Processed` ラベルが付与され、
次回以降の検索から除外される。ラベルは Apps Script が自動作成する。

間違って同じメールを再処理したい場合は、Gmail で該当スレッドから
`AppReview/Processed` ラベルを手動で外せば再度処理される。

## カスタマイズ

- **監視期間**: `newer_than:7d` を変更（例: `newer_than:3d`）
- **送信元追加**: `SENDER_QUERY` 配列に追加
- **件名フィルタ**: `SUBJECT_REGEX` を調整
- **Issue ラベル**: `ISSUE_LABELS` を変更

## トラブルシューティング

### `GITHUB_TOKEN is not set`
→ Script Properties に `GITHUB_TOKEN` を登録していない。手順4を実施。

### HTTP 401 / 403
→ GitHub Token の権限不足または期限切れ。`Issues: Read and write` を
  `sofvo-dev/sofvo` に対して付与しているか確認。

### HTTP 404
→ リポジトリ名が間違っている。スクリプト冒頭の `GITHUB_OWNER` / `GITHUB_REPO` を確認。

### Issueが作成されない
→ 実行ログ（左メニューの「実行数」）を開いてエラー内容を確認。
  件名が `SUBJECT_REGEX` にマッチしていない可能性もあり。
