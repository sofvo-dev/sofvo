# Googleドライブ → タイムライン 定期自動投稿

Googleドライブを「**親フォルダ → カテゴリ → 投稿**」の3階層で構成しておくと、設定したペース（既定: **月・木 20:00 JST**・画像のみ）で、**カテゴリを交互に回しながら1件ずつ**、Sofvo公式アカウント名義でアプリのタイムライン（`posts`）へ自動投稿する仕組み。

Instagram API（Metaアプリ・ビジネスアカウント・60日で失効するトークン）は使わず、**Firebase Functions の既定サービスアカウントで Google Drive を読む**方式。追加npmパッケージ不要（Sheets連携と同じ `getAccessToken()` を流用）。

## 実体ファイル
- ロジック: `functions/index.js`（`driveSelectNextUnit` / `processOneDrivePost` / `publishDriveScheduledPost` / `runDrivePostNow` / `driveSyncStatus`）
- アプリの動画表示: `lib/widgets/post_video_player.dart`、`lib/screens/home/home_screen.dart`（`_buildMediaGallery`）

---

## ドライブの格納ルール（3階層）

```
📁 (親フォルダ = folderId / サービスアカウントに共有)
├── 📁 通常/                    ← カテゴリ（プールA）
│   ├── 📁 post001/            ← 各サブフォルダ = 1投稿
│   │   ├── 01.jpg             ← フォルダ内はファイル名の昇順＝表示順（複数ならスワイプ）
│   │   └── 02.mp4
│   └── 📁 post002/
├── 📁 実機/                    ← カテゴリ（プールB）
│   ├── 📁 01_bracket_対戦表/  ← 各サブフォルダ = 1投稿
│   └── 📁 02_score_スコア/
└── 📁 リール/                  ← カテゴリ（プールB・動画直置き）
    ├── QR受付.mp4             ← 各ファイル = 1投稿
    └── スコア.mp4
```

- **投稿の単位**
  - カテゴリ内に**サブフォルダがある**（通常・実機）→ **各サブフォルダ = 1投稿**（中の複数メディアはファイル名昇順でスワイプ表示）
  - カテゴリ内に**メディアが直置き**（リール）→ **各ファイル = 1投稿**
- **順番**: カテゴリ内はフォルダ名／ファイル名の**昇順**（`001_`・日付を頭に付ければ制御可）
- **キャプションなし**（画像・動画のみ）
- **アップロード中の誤爆防止**: 直近 `idleMinutes` 分（既定10分）以内に更新されたメディアを含む単位は「アップロード中」とみなし見送り、その回の次の候補へ
- **投稿後**: ドライブのフォルダ構成はそのまま（移動しない）。二重投稿は投稿ドキュメントの `driveSourceId` で防止

## 放出順（cadence）

- `cadence`（既定 `["A","A","B"]`）に従い、`A` スロットは `poolA`、`B` スロットは `poolB` のカテゴリから出す
- 既定: **通常2件 → 実機/リール1件 → 繰り返し**
- `poolB` は `["実機","リール"]` の順で、各カテゴリ内は名前順（実機を出し切ってからリール）
- **その回のスロットのプールが空になったら投稿を止める**（`postIndex` も進めず、そのスロットで待機。新しいフォルダを足せば再開）
- 状態は `config/driveInstagramSyncState.postIndex`（投稿成功ごとに +1）

---

## セットアップ（初回のみ・ダッシュボード作業）

1. **Google Drive API を有効化**（プロジェクト `sofvo-19d84` = 番号 584952056517）
   - https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=584952056517
   - 反映に数分かかることがある（有効化直後は成功/失敗がブレる場合がある）

2. **親フォルダをサービスアカウントに共有**（閲覧者以上）
   ```
   sofvo-19d84@appspot.gserviceaccount.com
   ```

3. （任意）**設定を上書き**（Firestore `config/driveInstagramSync`）

   | フィールド | 型 | 説明 | 既定 |
   |---|---|---|---|
   | `folderId` | string | 親フォルダID | コード内定数 |
   | `enabled` | bool | `false` で停止 | `true` |
   | `officialUid` | string | 投稿者の公式アカウントUID | `zlBy8aWUlCYjyy0NUU9HidrQu983` |
   | `poolA` | string[] | Aスロットのカテゴリ名 | `["通常"]` |
   | `poolB` | string[] | Bスロットのカテゴリ名 | `["実機","リール"]` |
   | `cadence` | string[] | 放出パターン | `["A","A","B"]` |
   | `idleMinutes` | number | アップロード中とみなす分数 | `10` |

4. **動作確認（投稿しない）**
   ```
   https://us-central1-sofvo-19d84.cloudfunctions.net/driveSyncStatus
   ```
   カテゴリ別の投稿済み/残り件数・cadenceの現在位置・次に投稿される単位を返す。フォルダ共有・Drive API・格納ルールの切り分けに使う。

5. **手動で次の1件を即投稿**（テスト用）
   ```
   https://us-central1-sofvo-19d84.cloudfunctions.net/runDrivePostNow
   ```

---

## 投稿ペースの変更

`functions/index.js` の `publishDriveScheduledPost` の cron を変更（`.timeZone("Asia/Tokyo")` 指定なので JST で記述可）。変更後 `main` にマージすれば CI で自動デプロイ。

```js
.schedule("0 20 * * *")   // 毎日20:00起動→ config.postDays(既定 月・木=[1,4]) の日だけ投稿
```

---

## `posts` に追加したフィールド

| フィールド | 内容 |
|---|---|
| `media` | 表示順を保持した `[{type: 'image'|'video', url}]`（新アプリが優先描画） |
| `videos` / `images` | 動画URLのみ / 画像URLのみ（後方互換） |
| `source` | `"driveInstagram"` |
| `driveCategory` | 取り込み元カテゴリ名（通常/実機/リール） |
| `driveSourceId` | 取り込み元のサブフォルダ or ファイルのID（**二重投稿防止の照合キー**） |
| `sourceName` | 取り込み元の名前 |

## デプロイ区分
- **審査不要（即反映）**: `functions/index.js` → `main` マージで自動デプロイ
- **審査必要（ストア再提出）**: `lib/widgets/post_video_player.dart`・`lib/screens/home/home_screen.dart`・`pubspec.yaml`（タイムラインの**動画表示**対応）

## 注意点
- 画像・動画は必ず Storage にコピーしてから投稿する（DriveのURLは直接埋め込まない）
- 動画は Storage 容量を消費する。大量の動画を流す場合は容量に注意
- サービスアカウントのフォルダ共有を外すと即停止する
