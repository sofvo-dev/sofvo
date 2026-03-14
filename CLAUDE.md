# Sofvo プロジェクト設定メモ

## Mac ローカル環境
- **プロジェクトパス**: `~/Desktop/sofvo`
- **Xcodeワークスペース (iOS)**: `~/Desktop/sofvo/ios/Runner.xcworkspace`
- **ユーザー名**: shusuke
- **Mac**: MacBook-Pro-2

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
