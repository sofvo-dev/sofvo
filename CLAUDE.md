# Sofvo プロジェクト設定メモ

## 開発ルール

### 修正完了時のデプロイ判定ルール
- **修正が完了したら、変更ファイルを「審査必要（ストア再提出）」と「審査不要（即反映）」に分類して報告すること**
- 判定基準:
  - **審査必要**: `lib/**`, `pubspec.yaml`, `android/**`, `ios/**`（Dartコード・ネイティブ設定 → ストア再提出が必要）
  - **審査不要**: `functions/**`, `firestore.rules`, `storage.rules`, `website/**`, `.github/**`（サーバー側・ルール・CI → mainマージで即反映）
- 報告フォーマット例:
  ```
  ✅ 審査不要（即反映）: storage.rules, functions/index.js
  📱 審査必要（ストア再提出）: lib/screens/auth/login_screen.dart
  ```
- **ストア提出手順・AABビルドの案内はユーザーから求められたときのみ行う（毎回自動で案内しない）**

### 審査提出リクエスト時の対応ルール
- ユーザーが「審査に提出したい」と言ったら、以下を即座に用意すること：
  1. **`pubspec.yaml`** のバージョンを+1（例: `1.0.5+18` → `1.0.6+19`）
  2. **`ios/fastlane/Fastfile`** の `release_notes` を最新の変更内容に書き換え
  3. **`ios/fastlane/metadata/ja/`** の説明文・キーワード等も必要に応じて更新（fastlane が自動反映する）
  4. コミット＆プッシュ（mainにマージ）
- ユーザーはMacで `cd ~/Desktop/sofvo/ios && fastlane release` を実行するだけで審査提出まで全自動
- **次回審査時リマインド**: App Store Connectで年齢制限レーティングを16+ → 12+に変更する（アプリ情報 → 年齢制限レーティング → 編集 → 「無制限のWebアクセス」を「いいえ」に変更）

### 審査通過時の対応ルール
- ユーザーが「審査通過」「審査通った」等のメッセージを送ったら、以下を即座に実行すること：
  1. **バージョン履歴表**（CLAUDE.md 下部）と **リリース状況**（アプリ化 進捗セクション）を「リリース済み」に更新
  2. **`syncStoreVersionsNow` エンドポイントにバージョン番号を直接指定して Firestore を更新**：
     ```bash
     curl -s -m 30 "https://us-central1-sofvo-19d84.cloudfunctions.net/syncStoreVersionsNow?iosVersion=X.Y.Z"
     ```
     - `?iosVersion=X.Y.Z` で iTunes API の CDN キャッシュ遅延を回避して直接 Firestore に書き込む
     - パラメータなしで叩くと iTunes/Play Store から自動取得するが、Apple CDN は反映まで最大24-48時間かかる場合がある
     - Android も同時に更新する場合: `?iosVersion=X.Y.Z&androidVersion=A.B.C`
  3. **ユーザーに以下のURLを提示する**（デプロイ後にブラウザで開いてもらう）：
     ```
     https://us-central1-sofvo-19d84.cloudfunctions.net/syncStoreVersionsNow?iosVersion=X.Y.Z
     ```
     ※ X.Y.Z はリリースしたバージョン番号に置き換える
  4. コミット＆プッシュ

### fastlane メタデータ自動反映（v1.0.9で導入）
- `ios/fastlane/metadata/ja/` に以下のファイルを配置済み:
  - `description.txt` — App Store 説明文
  - `keywords.txt` — 検索キーワード
  - `promotional_text.txt` — プロモーションテキスト
  - `name.txt` — アプリ名
  - `subtitle.txt` — サブタイトル
  - `support_url.txt` — サポートURL
  - `privacy_url.txt` — プライバシーポリシーURL
- `fastlane release` 実行時に `skip_metadata: false` で自動的にApp Store Connectに反映される
- 説明文やキーワードを変更したい場合は、これらのファイルを編集してコミットするだけでOK
- `fastlane release` 内で自動的に `git pull` されるのでMac側の手動pull不要

### ストア提出手順（審査必要な変更がある場合に案内）

#### Android（全自動）
1. GitHub → **Actions** タブ
2. 「**Build Android AAB**」を選択
3. 右側の「**Run workflow**」をクリック
4. 「**Google Play 製品版にアップロード**」に**チェック**を入れる
5. 「**Run workflow**」で実行
- ビルド → Google Play 製品版アップロードまで全自動

#### iOS（ローカルMacで1コマンド）
```bash
cd ~/Desktop/sofvo/ios
fastlane release
```
- git pull → flutter clean → flutter pub get → pod install → ビルド → App Store Connect アップロード → 審査提出まで全自動
- 未コミットの変更がある場合は先に `git stash` してから実行、完了後 `git stash pop`
- **App用パスワード（App-Specific Password）が必要**: `~/.zshrc` に以下を設定済み
  ```bash
  export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="wilr-bfjb-mhlo-aulp"
  ```
  - Apple Account（info@sofvo.com）→ サインインとセキュリティ → アプリ用パスワード で生成
  - パスワードが無効になった場合は再生成して `~/.zshrc` を更新する

#### 注意事項
- **バージョンコード（pubspec.yaml の `+` 以降の数字）を上げてからmainにマージすること**
- 細かい修正はまとめて1回で提出するのが効率的（審査は数時間〜数日かかるため）

### クロスプラットフォーム統一ルール
- **修正・実装は必ず Android / iPhone / iPad / Web の全プラットフォームで同じ動作になるようにすること**
- プラットフォーム分岐は「Web vs ネイティブ」の2分岐に留める。Android / iOS / iPad で別々のコードパスを作らない
- 認証は Firebase Auth の `signInWithProvider` / `reauthenticateWithProvider`（ネイティブ）と `signInWithPopup`（Web）に統一済み
- ネイティブ固有のSDK（`google_sign_in`, `sign_in_with_apple` 等）は使わない。`firebase_auth` に統一する

## Mac ローカル環境
- **プロジェクトパス**: `~/Desktop/sofvo`
- **Xcodeワークスペース (iOS)**: `~/Desktop/sofvo/ios/Runner.xcworkspace`
- **ユーザー名**: shusuke
- **Mac**: MacBook-Pro-2

## ローカルデータを最新にする手順
```bash
cd ~/Desktop/sofvo
git stash
git pull origin main --rebase
git stash pop
```
- 必ず `cd` でプロジェクトディレクトリに移動してから実行すること
- `git stash` で未コミットの変更を退避してからpullし、`git stash pop` で戻す

## iOS ビルド & App Store Connect アップロード手順

### 前提
- **Xcode**: `ios/Runner.xcworkspace` を使う（`.xcodeproj` ではない）
- **署名**: Automatically manage signing → Team: SHUSUKE NAKAMURA
- **Bundle ID**: com.sofvo.app

### 手順

#### Step 1: コード最新化
```bash
cd ~/Desktop/sofvo
git checkout main
git checkout -- .
git pull origin main --rebase
```
- `unstaged changes` エラー時: `git checkout -- .` でローカル変更を破棄してからpull
- コンフリクト時: `git rebase --abort && git fetch origin main && git reset --hard origin/main`

#### Step 2: Flutter クリーン & 依存関係取得
```bash
flutter clean
flutter pub get
```

#### Step 3: CocoaPods インストール
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
```
- `Module 'cloud_firestore' not found` → この手順が抜けている可能性大

#### Step 4: Xcode でビルド & Archive
1. `open ios/Runner.xcworkspace` でXcodeを開く
2. 上部のデバイスを **「Any iOS Device (arm64)」** に変更
3. **Product → Clean Build Folder** (Shift+Cmd+K)
4. **Product → Archive** (アーカイブ作成、数分かかる)

#### Step 5: App Store Connect にアップロード
1. Archive完了後 **Organizer** が自動で開く（開かない場合: Window → Organizer）
2. 最新のArchiveを選択 → **Distribute App**
3. **App Store Connect** → **Upload**
4. オプションはデフォルトのまま **Next** → **Upload**
5. アップロード完了まで待つ（数分）

#### Step 6: App Store Connect で審査提出
1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン
2. アプリ「Sofvo」→ 新しいビルドが処理完了するまで待つ（5〜30分）
3. バージョンページでアップロードしたビルドを選択
4. 審査に関する情報を確認（テストアカウント、審査メモ）
5. **審査に提出** をクリック

### バージョン番号の更新（必要な場合）
- **App Storeで承認済み or 配信準備完了のバージョンと同じバージョンでは新ビルドを提出できない**
- 機能追加・バグ修正時はマイナーバージョンを上げる（例: `1.0.2` → `1.0.3`）
- 同じバージョンで再提出する場合、ビルド番号だけ上げればOK（例: `1.0.3+16` → `1.0.3+17`）
```bash
# pubspec.yaml の version を変更
# "+" の前がバージョン、"+" の後がビルド番号
```

### バージョン履歴
| バージョン | ビルド | 状態 | 内容 |
|---|---|---|---|
| 1.0.0 | 5-13 | 承認済み | 初回リリース |
| 1.0.1 | 14 | 配信準備完了 | バグ修正 |
| 1.0.2 | 15 | 配信準備完了 | プッシュ通知・バッジ・タブバー改善 |
| 1.0.3 | 16 | 審査提出済み | 未読カウント修正・ステータスバー白統一・管理メニュー全画面化 |
| 1.0.4 | 17 | 審査提出済み | 公式アカウント・管理者機能・FAQ・紹介リンク・プッシュ通知改善 |
| 1.0.5 | 18 | 審査提出済み | サムネイル・リリースノート自動化 |
| 1.0.6 | 19 | 審査提出済み | アップデートチェック機能・ボタンデザイン統一・ドメイン統一 |
| 1.0.7 | 20 | 審査提出済み | 大会作成フロー改善 |
| 1.0.8 | 21 | 配信準備完了 | 大会編集修正・ヘッダーデザイン統一・エラーハンドリング強化 |
| 1.0.9 | 22 | 審査待ち | App Storeメタデータ大幅改善（説明文充実・キーワード最適化・URL統一） |
| 1.0.10 | ? | 配信準備完了 | （以前のセッションで提出済み） |
| 1.0.11 | 24 | 配信準備完了 | iOSバッジ同期の根本原因修正（build 24 はアップロード済みだが未リリース） |
| 1.0.12 | 26 | リリース済み | 1.0.11 + チャット既読時のバッジ同期レース修正（でも MethodChannel 未登録バグで無効化） |
| 1.0.13 | 27 | 審査提出準備 | **真の根本原因修正**: AppDelegate の MethodChannel 登録を didInitializeImplicitFlutterEngine に移動（1.0.10〜1.0.12 ではバッジ同期コードが一切動いていなかった） |
| 1.0.14 | 28 | 審査提出準備 | お知らせ配信にリンク機能・予約配信・OS別配信対象を追加（バージョン番号が既に使用済みのため 1.0.15 で再提出） |
| 1.0.15 | 29 | リリース済み | お知らせ配信にリンクボタン・予約配信・OS別配信対象（iOS/Android/全員）を追加 |
| 1.0.18 | 32 | リリース済み | チェックイン Universal Links・対戦表生成と大会ステータス・公式向けマイ大会/閲覧・収支修正・大会準備中表記等 |
| 1.0.19 | 33 | リリース済み | 安定性・信頼性の向上、チェックイン・大会運営・収支まわりの細かな改善・利用しやすさの調整 |

### iOS提出時のリリースノート
- **iOSアップロード時は必ず「このバージョンの最新情報」も一緒に出すこと**

### Macローカルでの提出時の注意
- **unstaged changesエラー**: `git checkout -- .` で変更を破棄してからpull
- **`flutter clean && flutter pub get` を必ず実行する**: pubspec.yamlの変更がビルドに反映されない
- **fastlaneがない場合**: Xcodeで手動Archive → Distribute App で提出可能（fastlaneなしでOK）

### 大会の見え方（クイック表・全項目）

一覧の判定は、可能なら `lib/utils/tournament_status.dart` の `normalizeTournamentStatus` で旧表記を正規化したあとの `status` を前提とする（未導入のブランチでは Firestore の `status` 文字列そのまま）。コードとの差分があれば `lib/screens/tournament/tournament_search_screen.dart` の `_buildTournamentList` を正とし、本節を追従する。

#### 前提・アカウント

| 項目 | 内容 |
|------|------|
| **一般** | `users.isOfficial` が **true でない** |
| **公式** | `isOfficial == true` |
| **正規化後** | 以下の「ステータス正規化」表を適用した `status` で判定 |

#### ステータス正規化（DBの表記ゆれ）

| 正しい値（正規化後） | 吸収する旧値 |
|----------------------|--------------|
| **エントリー締切** | `エントリー締め切` |
| **大会準備中** | `試合準備中`, `試合準備` |
| （その他） | そのまま |

#### さがす — フォロー中／みんな（大会・メンバー募集共通）

| タブ | 一覧に出る主催者／募集者 |
|------|---------------------------|
| **フォロー中** | **フォローしている人** ＋ **自分** |
| **みんな** | **まだフォローしていない人**（自分が主催する大会は「みんな」側の対象外） |

#### さがす — 大会タブ（ステータス × 一般／公式）

| 正規化後の `status` | 一般 | 公式 |
|---------------------|------|------|
| 準備中 | × | ○ |
| 終了（「過去の大会を表示」オフ） | × | ○ |
| 終了（オン） | ○ | ○ |
| 募集中 | ○ | ○ |
| 満員 | ○ | ○ |
| エントリー締切 | × | ○ |
| 大会準備中 | ○ | ○ |
| 開催中 | × | ○ |
| 決勝中 | × | ○ |
| 順位決定中 | × | ○ |
| 上記以外の文字列 | 上記の×条件に当てはまらなければ一覧に出る（未使用値はコード確認） | ○（ステータスでは除外しない） |

（**一般**: **○**＝ステータス条件を満たし、かつ **フォロー中／みんな・種目・エリア・日付・検索** などのフィルターも満たすと一覧に出る。**×**＝大会一覧のフィルターで除外。）  
（**公式**: **ステータスによる一覧からの除外は行わない**。○＝**フォロー中／みんな・種目・エリア・日付・検索** などのフィルターを満たせば一覧に出る。）

#### さがす — メンバー募集タブ

| 項目 | 内容 |
|------|------|
| 大会の `status` で隠すか | **隠さない**（募集ドキュメント単位） |
| 絞り込み | **フォロー中／みんな** ＋ **検索・エリア・日付・種目** |

#### マイ大会

| 項目 | 一般 | 公式 |
|------|------|------|
| 一覧に載る条件 | 自分が **主催** または **エントリー参加** | **主催のみ**（参加者としての想定なし） |
| 「これから」タブ | `status` が **終了** 以外（正規化後） | 同じ |
| 「これまで」タブ | `status` が **終了**（正規化後） | 同じ |
| 詳細へ渡す `status` 等 | 正規化してから渡す想定 | 同じ |

#### 大会詳細（一般 vs 公式）

| 項目 | 一般 | 公式 |
|------|------|------|
| フォロー案内バナー | フォロー前提の文言 | 閲覧は可能・エントリー等はフォローが必要、といった文言 |
| 下部（メンバー募集／エントリー） | フォロー前提の操作が中心 | 未フォローでも導線を出し、エントリー時にフォロー補完など |
| フォロー状態の同期 | 限定的 | **FollowService と連動** |

#### 実装参照（メモ用）

| 項目 | 参照先 |
|------|--------|
| 正規化 | `lib/utils/tournament_status.dart` の `normalizeTournamentStatus` |
| さがす大会の出し分け | `lib/screens/tournament/tournament_search_screen.dart` の `_buildTournamentList` |

### トラブルシュート

#### 「Command PhaseScriptExecution failed with a nonzero exit code」
最も多いビルドエラー。以下で解決:
```bash
cd ~/Desktop/sofvo
flutter clean
flutter pub get
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..
# → Xcodeで Clean Build Folder → Archive
```
それでもダメな場合:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Xcode のディスク容量を減らす
- **プロジェクト内**: リポジトリ直下で `./scripts/clean-xcode-disk.sh`（`flutter clean` と `build/`・`ios/Pods` 等の削除。次回 `cd ios && pod install --repo-update` が必要）
- **DerivedData 全削除**（効果大・次回ビルドは遅くなる）: `./scripts/clean-xcode-disk.sh --derived`
- **古いシミュレータ**: `./scripts/clean-xcode-disk.sh --simulators` または `xcrun simctl delete unavailable`
- **手動**: Xcode → **Window → Organizer** で古い **Archive** を削除。`~/Library/Developer/Xcode/iOS DeviceSupport/` から不要な iOS バージョンを削除。`~/Library/Caches/org.swift.swiftpm/` や `~/Library/Caches/CocoaPods/` も大きくなりがち

#### 「Module 'xxx' not found」
`pod install` が未実行。Step 3を実行する。

#### Archiveがグレーアウト
デバイスが「Any iOS Device (arm64)」になっていない。シミュレータ選択中はArchiveできない。

#### 「iOS XX.X is not installed」「Unable to find a destination … generic:1, platform:iOS」
- **原因**: `flutter build ipa` / `flutter build ios --release` は **実機向け（iphoneos）** のビルドであり、Xcode が **その iOS バージョン用のデバイス・プラットフォーム**（Settings → **Platforms** / 旧 Components）を要求する。SDK が `-showsdks` に出ていても、プラットフォーム未導入だと同様のエラーになる。
- **ログ例（2026/05）**: `error:iOS 26.5 is not installed` と **接続中の iPhone / iPad**（`arch:arm64e`）および **Any iOS Device** が ineligible → **iPhoneOS 26.5 の「プラットフォーム」本体**が未インストール。USB を複数本挿していても、根本は **Xcode に 26.5 の実機用プラットフォームを入れる**こと。シミュレータ用ランタイムだけ入っていても足りない。
- **エラー文言の「Components」**: 新しい Xcode では **Settings → Platforms**（旧 **Settings → Platforms / Components**）で同じ意味。
- **`xcodebuild -downloadPlatform iOS` の注意**: ログに **Simulator** と出る場合は **シミュレータ用ランタイム**のみ。App Store 用 IPA に必要な **実機ビルド用プラットフォーム**とは別のため、これだけでは直らないことが多い。
- **対処（推奨順）**:
  1. **Xcode → Settings → Platforms** で **iOS 26.5**（エラーに出たバージョン）を **完了までインストール**（一覧に無い場合は Xcode を App Store から最新化）。
  2. ターミナルで `xcodebuild -showsdks` に **`iphoneos26.5`**（または要求バージョン）が出ることを確認。
  3. まだ失敗する場合は **USB の実機を一度外して**から再実行（接続端末の OS が要求ランタイムを引き上げていることがある）。
  4. それでも不可なら、プラットフォームが揃った **別 Mac** または **GitHub Actions 等の CI** で `flutter build ipa` を検討。
- **fastlane 前の Git**: `git stash` 後に `stash pop` で **未コミットの `ios/` 変更**が残ると混乱の元。提出前は `git status` をクリーンにするか、意図した変更だけコミットしてから `fastlane release` すること。
- **手動で `git pull` するとき**（`error: cannot pull with rebase: You have unstaged changes`）: 未追跡の `ios/Podfile.lock` 等があると `git stash` だけでは退避されない。`git stash push -u -m wip` → `git pull origin main --rebase` → `git stash pop`。または `fastlane release` 先頭で同様に `-u` 付き stash を実行（リポジトリの Fastfile を最新化）。

## App Store Connect
- **Bundle ID**: com.sofvo.app
- **Team**: SHUSUKE NAKAMURA
- **Apple Developer アカウント**: Shusuke Nakamura

## Firebase
- **Project ID**: sofvo-19d84
- **Firebase CLI**: `npm install -g firebase-tools --force` でインストール/更新
- **Node**: v25.6.1 / npm 11.9.0（Mac環境）

### Firebase デプロイ（CI で自動化済み）
- **`main` ブランチへの push 時に GitHub Actions で全リソースが自動デプロイされる**
- ワークフロー: `.github/workflows/firebase-deploy.yml`
- 対象: Functions, Firestore rules/indexes, Storage rules, Hosting（Web ビルド含む）
- **手動デプロイは不要。コードを `main` に push すれば自動でデプロイされる**
- シークレット: `FIREBASE_SERVICE_ACCOUNT`（GitHub リポジトリの Secrets に設定済み）

手動デプロイが必要な場合（緊急時のみ）:
```bash
firebase deploy --only storage    # Storage rules のデプロイ
firebase deploy --only firestore  # Firestore rules のデプロイ
firebase deploy --only functions  # Cloud Functions のデプロイ
firebase deploy --only hosting    # Hosting のデプロイ
```

## ドメイン移管（sofvo.com: XServer → ムームードメイン）→ 完了
- **レジストラ**: ムームードメイン（2026/04/03 移管完了）
- **ドメイン**: sofvo.com（利用期限: 2027/09/13）
- **移管費用**: ¥2,154（ムームードメイン） + ¥1,721（XServer特典解除費用）
- **ステータス**: **移管完了**

### 移管後のTODO
- [x] Firebase Hosting にカスタムドメイン `sofvo.com` を追加（SSL接続済み）
- [x] Firebase Auth の承認済みドメインに `sofvo.com` を追加
- [x] Google Cloud Console で OAuth リダイレクトURIに `https://sofvo.com/__/auth/handler` を追加
- [x] `lib/firebase_options.dart` の `authDomain` を `sofvo.com` に変更
- [x] Google Workspace 契約 & MXレコード設定（`info@sofvo.com`）
- [x] DNS設定（ムームードメインのネームサーバー設定）
- [x] コードベース内の `sofvo-19d84.web.app` / `sofvo-19d84.firebaseapp.com` を `sofvo.com` に統一
- [x] SPFレコード統合（Google Workspace + Firebase を1レコードに統合済み）
- [ ] Firebase Auth メールテンプレート用カスタムドメイン認証（DNS反映待ち → 認証後に送信元を `noreply@sofvo.com` に変更）

## アプリ化 進捗（2026/05/14 更新）

### リリース状況
- **iOS**: 🟢 1.0.19 リリース済み（安定性向上・チェックイン・大会運営・収支まわりの改善等）
- **Android**: 🟢 製品版公開済み（Google Play）

### Macローカル環境
- **fastlaneインストール済み**（Ruby 4.0.2 + fastlane 2.232.2）
- iOS提出: `cd ~/Desktop/sofvo/ios && fastlane release`（全自動）

## 審査メール自動通知（2026/04/15 稼働開始）

### 概要
`info@sofvo.com` に届く Apple / Google Play からの審査関連メールを
**Google Apps Script** が定期的にスキャンし、`sofvo-dev/sofvo` リポジトリに
GitHub Issue を自動作成する仕組み。Claude Code は GitHub MCP 経由で Issue を
読めるため、審査ステータスを即座に確認して次のアクションに繋げられる。

### 構成
- **スクリプト本体**: `scripts/apps-script/app-review-notifier.gs`
- **セットアップ手順**: `scripts/apps-script/README.md`
- **実行環境**: Google Apps Script（`info@sofvo.com` の Google Workspace 内）
- **定期実行**: 1時間ごとのトリガー
- **対象送信元**: `no_reply@email.apple.com`, `noreply@email.apple.com`, `googleplay-noreply@google.com`, `googleplay-developer-noreply@google.com`
- **重複防止**: Gmail に `AppReview/Processed` ラベルを付与

### 使い方
- 審査メールが届く → 1時間以内に GitHub Issue が自動作成される（ラベル: `app-review`）
- Claude Code に「最近の app-review Issue を見せて」と聞けば取得してくれる
- 審査通過 → CLAUDE.md のバージョン履歴表を「リリース済み」に更新するトリガーにもなる

### メリット
- **新規ツール登録ゼロ**: Google Workspace + GitHub のみ（Zapier などは不要）
- **無料**: Apps Script の無料枠で完結
- **履歴が GitHub に残る**: 審査の流れが Issue として時系列で追える

### トラブルシュート
- Issue が作成されない → Apps Script の「実行数」で実行ログを確認
- 再処理したいメールがある → Gmail で `AppReview/Processed` ラベルを外せばOK
- GitHub Token の期限切れ → Script Properties の `GITHUB_TOKEN` を更新

## スーパーアドミン（最高権限）設定手順
1. [Firebase Console](https://console.firebase.google.com/) を開く
2. プロジェクト **sofvo-19d84** を選択
3. 左メニューの **Firestore Database** をクリック
4. `users` コレクション → 対象ユーザーの **UID** のドキュメントを開く
5. **フィールドを追加** → 名前: `isAdmin`、型: `boolean`、値: `true`
- UIDがわからない場合: Firebase Console の **Authentication → Users** タブでメールアドレスから検索
- `isAdmin: true` を持つユーザーは全大会で主催者権限を持ち、トラブル時に介入可能
- 設定画面のアカウント情報に「権限: 管理者」と表示される（本人のみ）

## 新規登録フロー（2026/03/17 決定）

### メール登録の場合
```
新規登録（メール + パスワード入力）
  ↓
仮登録メール配信（Firebase 自動）
  ↓
メールのURLクリック → Web版に戻る
  ↓
プロフィール設定（ユーザー名など）
  ↓
本登録完了メール（Cloud Functions で送信）
  ↓
アプリ/Web版の案内
```

### Google/Apple 登録の場合
```
サインイン（メール確認不要）
  ↓
プロフィール設定（ユーザー名など）
  ↓
本登録完了メール（Cloud Functions で送信）
  ↓
アプリ/Web版の案内
```

### 実装メモ
- メール登録: Firebase の `sendEmailVerification()` で仮登録メール自動送信
- 本登録完了メール: Cloud Functions の `onUpdate` トリガーでプロフィール保存時に送信
- 現在アプリ未公開のため、案内はWeb版（`https://sofvo-19d84.web.app`）へ誘導

## 認証・セッション管理のバグ（2026/03/17 報告）

### 報告された問題
1. **アカウント切り替えができない**: ログアウト後に別アカウントでログインできない（キャッシュ残留）
2. **LINEで招待リンクを開くと送信者のアカウントにログインされる**

### 原因
1. `signOut()` が Firebase Auth のみサインアウト → Google OAuth セッションが残る
2. LINEアプリ内ブラウザで `localStorage`（`Persistence.LOCAL`）が共有される

### 修正方針
- **`lib/services/auth_service.dart` の `signOut()`**: Google OAuth / Firestore キャッシュもクリアする
- **招待リンク**: LINEアプリ内ブラウザ検出 → 外部ブラウザで開くよう促す
- **優先度**: signOut修正 = 高、招待リンク対策 = 中

## TODO: Google認証画面のドメイン表示を sofvo.com に変更（ドメイン移管完了後）

### 概要
Google OAuth認証画面に `sofvo-19d84.firebaseapp.com` と表示される → `sofvo.com` に変更したい。
**ドメイン移管（XServer → ムームードメイン）完了後に対応する。**

### 手順
1. **Firebase Hosting にカスタムドメインを追加**
   - Firebase Console → Hosting → 「カスタムドメインを追加」→ `sofvo.com` を設定（DNS設定が必要）
2. **Firebase Auth の承認済みドメインに追加**
   - Firebase Console → Authentication → Settings → 「承認済みドメイン」→ `sofvo.com` を追加
3. **Google Cloud Console で OAuth リダイレクトURIを更新**
   - APIとサービス → 認証情報 → OAuth 2.0 クライアントID
   - 承認済みリダイレクトURIに `https://sofvo.com/__/auth/handler` を追加
4. **Firebase の `authDomain` を変更**
   - `lib/firebase_options.dart` の `authDomain` を `sofvo-19d84.firebaseapp.com` → `sofvo.com` に変更

### 前提条件
- [ ] ドメイン移管完了（XServer → ムームードメイン）
- [ ] DNS設定完了

## ウェルカムメール テスト送信（2026/03/19 追加）

### 概要
`testWelcomeEmail` Cloud Function を追加。管理者が任意のメールアドレスにウェルカムメールをテスト送信できる。

### 使い方
```bash
firebase deploy --only functions
firebase functions:shell
> testWelcomeEmail({email: "shusuke1027@gmail.com", nickname: "Shusuke"})
```

### パラメータ
- `email`（必須）: 送信先メールアドレス
- `nickname`（任意）: メール内の宛名（デフォルト: テストユーザー）

### 備考
- 管理者権限（`isAdmin: true`）が必要
- ウェルカムメールのHTMLテンプレートは `sendWelcomeMailTo()` 共通関数に集約済み
- メール内に「詳しくはこちら」→ Welcome LP（`/welcome`）へのリンクあり

## TODO: 将来の改善タスク

- [ ] **通知用メールアドレス機能**: Apple/Google Sign Inユーザーは認証メールが変更できないため、通知送信先を別途設定できるようにする
  - 設定画面のアカウントセクションに「通知用メールアドレス」を追加
  - 確認メール認証フロー（Cloud Functionsでトークン生成・検証）
  - Firestore `users/{uid}` に `notificationEmail` フィールドを保存
  - Cloud Functionsのメール送信時に `notificationEmail` → 認証メールの順でフォールバック
  - 設定画面に認証状態を表示（「認証済み ✓」/「認証待ち…」）
- [ ] **大会検索・フィルター機能の強化**: 大会数が増えたら、オンボーディング画面（「大会をさがす」）の検索・絞り込みUIを改善する（地域・日程・レベル等）
