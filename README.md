# sofvo

ソフトバレーボール マッチングアプリ

## 主な機能

- **大会管理** - 大会の作成・エントリー・トーナメント進行・スコア入力・MVP投票・QRチェックイン
- **チーム管理** - チーム作成・メンバー管理・チャット
- **メンバー募集** - 大会への参加メンバー募集・応募
- **タイムライン** - 投稿・コメント・いいね
- **友達検索** - ID/ニックネーム検索・QRコードで友達追加
- **チャット** - 1対1・グループチャット（画像/ファイル送信対応）
- **プロフィール** - 戦績・バッジ・ランキング・ブックマーク
- **ガジェット** - 使用機材の登録・Amazon商品検索連携
- **通知** - プッシュ通知・フォロー通知・大会リマインド

## 技術スタック

- **Flutter** (Web / iOS / Android)
- **Firebase** - Auth, Firestore, Storage, Messaging
- **認証** - Google / Apple サインイン

## セットアップ

```bash
flutter pub get
flutter run -d chrome       # Web
flutter run -d ios          # iOS
flutter run -d android      # Android
```

## デプロイ

```bash
./deploy.sh
```
