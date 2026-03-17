# Sofvo プロジェクト設定メモ

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

## Xcode ビルド & アップロード手順
1. `cd ~/Desktop/sofvo`
2. `git pull origin main --rebase` で最新のコードを取得
   - コンフリクトが出た場合: `git rebase --abort && git fetch origin main && git reset --hard origin/main`
3. `cd ios && pod install && cd ..` でCocoaPodsの依存関係をインストール
   - `Module 'cloud_firestore' not found` 等のエラーが出た場合はこの手順が抜けている可能性が高い
4. Xcodeで `ios/Runner.xcworkspace` を開く（`.xcodeproj` ではなく `.xcworkspace` を使うこと）
5. **Product → Clean Build Folder** (Shift+Command+K)
6. **Product → Archive**
7. **Organizer → Distribute App → App Store Connect** でアップロード

## App Store Connect
- **Bundle ID**: com.sofvo.app
- **Team**: SHUSUKE NAKAMURA
- **Apple Developer アカウント**: Shusuke Nakamura

## Firebase
- **Project ID**: sofvo-19d84
- **Firebase CLI**: `npm install -g firebase-tools --force` でインストール/更新
- **Node**: v25.6.1 / npm 11.9.0（Mac環境）

### Firebase デプロイコマンド
```bash
firebase deploy --only storage    # Storage rules のデプロイ
firebase deploy --only firestore  # Firestore rules のデプロイ
firebase deploy --only functions  # Cloud Functions のデプロイ
firebase deploy --only hosting    # Hosting のデプロイ
```

### トラブルシュート（2026/03/16）
- `No targets in firebase.json match '--only storage'` エラー
  - **原因**: `git pull origin main` をしておらず、ローカルに `storage.rules` ファイルがなかった
  - **対処**: `git pull origin main` で最新コードを取得してから再デプロイで解決
  - **教訓**: デプロイ前に必ず `git pull origin main` で最新化すること

## ドメイン移管（sofvo.com: XServer → ムームードメイン）
- **現在のレジストラ**: XServer（サーバーID: xs228659）
- **移管先**: ムームードメイン
- **ドメイン**: sofvo.com（利用期限: 2026/09/13）
- **特典**: 「独自ドメイン永久無料特典」が適用中 → 移管前に解除が必要
- **ステータス**: 2026/03/14 XServerサポートへ特典解除を問い合わせ済み（返信待ち）
- **手順**:
  1. XServerサポートに特典解除を依頼 → **済（返信待ち）**
  2. 解除手数料（ドメイン1年分の更新料金）を支払い
  3. XServerアカウントからドメインの解約手続き
  4. 「ドメイン解約についてのご案内」メールの案内に従い、ムームードメインで移管申請
- **参考**: https://www.xserver.ne.jp/support/faq/transfer_domain_permanent_free.php

## アプリ化 進捗（2026/03/14 時点）

### リリース状況
- **iOS**: 🟡 審査待ち（App Store Connect に提出済み、結果待ち 1〜3日）
- **Android**: ⏳ クローズドテスト中（12人オプトイン済み、1/14日目 → 3/28頃完了）

### 完了済み
- Apple Developer 登録
- Google Play Console 登録
- iOS ビルド & App Store Connect アップロード
- iOS スクリーンショット & メタデータ登録
- iOS 審査提出
- Android クローズドテスト版公開 & テスター12人オプトイン
- プライバシーポリシー・利用規約 公開済み
- Firebase 設定完了
- 署名設定（iOS / Android）完了

### 残りタスク
1. iOS 審査結果対応（数日以内）
2. Android 14日間テスト完了待ち（3/28頃）
3. Android 製品版申請 & 審査（3/28以降）
4. ドメイン移管（XServer → ムームードメイン）サポート返信待ち

### 想定スケジュール
- **3月中旬〜**: iOS App Store 公開（審査通過次第）
- **3月末〜**: Android Play Store 製品版申請
- **4月上旬**: 両ストアで公開完了（目標）

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
