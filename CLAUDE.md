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
3. Xcodeで `ios/Runner.xcworkspace` を開く
4. **Product → Clean Build Folder** (Shift+Command+K)
5. **Product → Archive**
6. **Organizer → Distribute App → App Store Connect** でアップロード

## App Store Connect
- **Bundle ID**: com.sofvo.app
- **Team**: SHUSUKE NAKAMURA
- **Apple Developer アカウント**: Shusuke Nakamura

## Firebase
- **Project ID**: sofvo-19d84
