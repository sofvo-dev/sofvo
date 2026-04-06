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
  3. コミット＆プッシュ（mainにマージ）
- ユーザーはMacで `cd ~/Desktop/sofvo/ios && fastlane release` を実行するだけで審査提出まで全自動
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
| 1.0.6 | 19 | 審査提出予定 | アップデートチェック機能・ボタンデザイン統一・ドメイン統一 |

### iOS提出時のリリースノート
- **iOSアップロード時は必ず「このバージョンの最新情報」も一緒に出すこと**

### Macローカルでの提出時の注意
- **unstaged changesエラー**: `git checkout -- .` で変更を破棄してからpull
- **`flutter clean && flutter pub get` を必ず実行する**: pubspec.yamlの変更がビルドに反映されない
- **fastlaneがない場合**: Xcodeで手動Archive → Distribute App で提出可能（fastlaneなしでOK）

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

#### 「Module 'xxx' not found」
`pod install` が未実行。Step 3を実行する。

#### Archiveがグレーアウト
デバイスが「Any iOS Device (arm64)」になっていない。シミュレータ選択中はArchiveできない。

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

## アプリ化 進捗（2026/04/05 更新）

### リリース状況
- **iOS**: 🟢 1.0.1 配信準備完了 / 1.0.2 配信準備完了 / 1.0.3 審査提出済み / 1.0.6 審査提出予定
- **Android**: 🟢 製品版公開済み（Google Play）

### Macローカル環境
- **fastlaneインストール済み**（Ruby 4.0.2 + fastlane 2.232.2）
- iOS提出: `cd ~/Desktop/sofvo/ios && fastlane release`（全自動）

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
