# Googleドライブ → タイムライン 定期自動投稿

Googleドライブに「1投稿=1フォルダ」で画像・動画を溜めておくと、設定したペース（既定: **月・水・金 12:00 JST**）で **フォルダ名の古い順に1件ずつ**、Sofvo公式アカウント名義でアプリのタイムライン（`posts`）へ自動投稿する仕組み。投稿後のフォルダは `投稿済み/` へ自動で移動する（＝二重投稿防止）。

Instagram API（Metaアプリ・ビジネスアカウント・60日で失効するトークン）を使わず、**Firebase Functions の既定サービスアカウントで Google Drive を読む**方式。追加npmパッケージ不要（Sheets連携と同じ `getAccessToken()` を流用）。

## 実体ファイル
- 取り込み・投稿ロジック: `functions/index.js`（`processOneDrivePost` / `publishDriveScheduledPost` / `runDrivePostNow`）
- アプリの動画表示: `lib/widgets/post_video_player.dart`、`lib/screens/home/home_screen.dart`（`_buildMediaGallery`）

---

## Googleドライブの格納ルール

```
📁 Sofvo投稿/              ← この親フォルダをサービスアカウントに「編集者」で共有する
├── 📁 001_大会告知/        ← 1フォルダ = 1投稿。フォルダ名の昇順で投稿される
│   ├── 01.jpg             ← フォルダ内はファイル名の昇順＝投稿での表示順
│   ├── 02.jpg
│   └── 03.mp4             ← 画像・動画の混在OK（番号順に並ぶ）
├── 📁 002_優勝報告/
│   ├── 01.jpg
│   └── 02.mp4
└── 📁 投稿済み/            ← 投稿後、フォルダが自動でここへ移動する（手動作成不要）
```

- **1フォルダ = 1投稿**。中に投稿したい画像・動画をまとめて入れる
- **投稿順**: 親フォルダ直下のサブフォルダを **フォルダ名の昇順** で処理。`001_` や日付を頭に付ければ順番を完全に制御できる
- **表示順**: フォルダ内は **ファイル名の昇順**（`01` `02` `03`…）
- **キャプションなし**（画像・動画のみ）
- **アップロード中の誤爆防止**: 直近 `idleMinutes` 分（既定10分）以内に更新されたファイルがあるフォルダは「まだアップロード中」とみなして見送り、次の候補へ回す
- **投稿後**: フォルダは `投稿済み/` へ移動（`投稿済み` フォルダは自動生成）

---

## セットアップ（初回のみ・ダッシュボード作業）

1. **Google Drive API を有効化**
   - [Google Cloud Console](https://console.cloud.google.com/) → プロジェクト `sofvo-19d84` → 「APIとサービス」→「ライブラリ」→ **Google Drive API** を有効化

2. **投稿用フォルダをサービスアカウントに共有**
   - Googleドライブで親フォルダ（例 `Sofvo投稿`）を作成
   - そのフォルダを右クリック →「共有」→ 下記を **編集者** で追加（`投稿済み/` への移動に編集権限が必要）
     ```
     sofvo-19d84@appspot.gserviceaccount.com
     ```

3. **設定ドキュメントを作成**（Firestore `config/driveInstagramSync`）

   | フィールド | 型 | 説明 | 既定 |
   |---|---|---|---|
   | `folderId` | string | 投稿用の親フォルダID（DriveのURL `.../folders/●●●` の●●● 部分）。**必須** | （なし＝無効） |
   | `enabled` | bool | `false` で停止 | `true` |
   | `officialUid` | string | 投稿者にする公式アカウントのUID | `zlBy8aWUlCYjyy0NUU9HidrQu983` |
   | `postedFolderName` | string | 投稿済みの移動先フォルダ名 | `投稿済み` |
   | `idleMinutes` | number | この分数以内に更新されたフォルダは見送る | `10` |

   ※ `folderId` を設定した時点で有効化される。停止したいときは `enabled: false`。

4. **動作確認**（任意）
   - 次の1件を即投稿できる確認用エンドポイント:
     ```
     https://us-central1-sofvo-19d84.cloudfunctions.net/runDrivePostNow
     ```
   - 返り値の `result` に `posted`（投稿ID）や `skipped`（理由）が入る。Drive権限・設定の切り分けに使う

---

## 投稿ペースの変更

`functions/index.js` の `publishDriveScheduledPost` の cron を変更する（`.timeZone("Asia/Tokyo")` 指定なので JST で書ける）。

```js
.schedule("0 12 * * 1,3,5")   // 月・水・金 12:00（既定）
// .schedule("0 9 * * *")      // 毎日 9:00
// .schedule("0 19 * * 1-5")   // 平日 19:00
```

変更後 `main` にマージすれば CI で自動デプロイされる。

---

## データ構造（`posts` に追加したフィールド）

| フィールド | 内容 |
|---|---|
| `media` | 表示順を保持した `[{type: 'image'|'video', url}]`。新アプリはこれを優先描画 |
| `videos` | 動画URLのみの配列（補助） |
| `images` | 画像URLのみの配列（旧アプリ・他リーダーとの後方互換） |
| `source` | `"driveInstagram"`（出所メタデータ） |
| `sourceFolderId` / `sourceFolderName` | 取り込み元フォルダのID・名前（二重投稿防止の照合に使用） |

---

## デプロイ区分
- **審査不要（即反映）**: `functions/index.js`（取り込み・投稿ロジック）→ `main` マージで自動デプロイ
- **審査必要（ストア再提出）**: `lib/widgets/post_video_player.dart`・`lib/screens/home/home_screen.dart`・`pubspec.yaml`（タイムラインの**動画表示**対応）→ 動画を再生するにはアプリの再提出が必要

## 注意点
- **画像・動画は必ず Storage にコピーしてから投稿**している（DriveのURLは直接埋め込まない）
- 動画は Storage 容量を消費する。大きなリール等を大量に流す場合は容量に注意
- サービスアカウントのトークンで Drive API を読むため、**フォルダ共有を外すと即停止**する
