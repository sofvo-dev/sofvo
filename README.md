# sofvo

ソフトバレーボール マッチングアプリ

## 主な機能

### 大会管理
- 大会の作成・編集・公開
- エントリー受付・承認
- QRコードによるチェックイン（主催者スキャン / 参加者セルフチェックイン / 手動受付）
- 予選リーグ（ラウンドロビン）自動対戦表生成
- 決勝トーナメント（シングル/ダブルエリミネーション）ブラケット生成
- リアルタイムスコア入力（複数セット対応・確定ワークフロー）
- MVP投票
- 大会写真ギャラリー
- 収支管理（参加費収入・経費・損益レポート）
- 大会ルールテンプレート管理
- PDF出力（大会概要・対戦表・スコアシート）

### チーム管理
- チーム作成・メンバー招待
- メンバーロール管理（オーナー/メンバー）
- チーム専用掲示板（大会ごと）

### メンバー募集
- 大会への参加メンバー募集投稿
- 募集一覧・応募

### タイムライン
- 投稿（テキスト・画像）
- コメント・いいね
- 全体 / フォロー中の切り替え

### 友達検索
- ID・ニックネーム検索
- QRコードで友達追加（生成・読み取り）

### チャット
- 1対1メッセージ
- グループチャット作成・設定
- 画像・ファイル送信
- メッセージ編集
- チャットピン留め・非表示
- アルバム・共有ノート

### プロフィール
- プロフィール設定（ニックネーム・検索ID・自己紹介・都道府県・経験レベル）
- フォロー / フォロワー管理
- 戦績・試合履歴・大会参加履歴
- バッジコレクション
- ランキング（累積ポイント・大会参加回数・優勝回数）
- ブックマーク
- ユーザーブロック

### ガジェット
- 使用機材の登録・カテゴリ管理
- Amazon商品検索連携

### 通知
- プッシュ通知（FCM）
- いいね・コメント・フォロー・大会エントリー通知
- アプリ内通知センター
- ディープリンク対応

## 技術スタック

| カテゴリ | 技術 |
|---|---|
| フレームワーク | Flutter (Web / iOS / Android) |
| バックエンド | Firebase (Auth, Firestore, Storage, Messaging) |
| 認証 | Email/Password, Google Sign-In, Apple Sign-In |
| PDF生成 | pdf + printing |
| QRコード | qr_flutter + mobile_scanner |
| フォント | Noto Sans JP (Google Fonts) |
| テーマ | Material 3, Navy (#1B3A5C) + Gold (#C4A962) |

## プロジェクト構成

```
lib/
├── main.dart                   # エントリーポイント・認証ゲート
├── firebase_options.dart       # Firebase設定
├── config/
│   └── app_theme.dart          # デザイントークン・テーマ
├── services/
│   ├── auth_service.dart       # 認証（Email/Google/Apple）
│   ├── notification_service.dart    # アプリ内通知作成
│   ├── push_notification_service.dart # FCMプッシュ通知
│   ├── match_generator.dart    # 対戦表自動生成
│   ├── pdf_generator.dart      # PDF出力
│   ├── bookmark_notification_service.dart
│   ├── amazon_search_service.dart
│   └── media_service.dart      # 画像アップロード
└── screens/
    ├── auth/          # ログイン・登録
    ├── home/          # タイムライン・投稿
    ├── tournament/    # 大会管理・スコア入力・チェックイン
    ├── team/          # チーム管理
    ├── profile/       # プロフィール・設定・戦績
    ├── chat/          # チャット
    ├── follow/        # 友達検索・QRコード
    ├── gadget/        # ガジェット管理
    ├── notification/  # 通知センター
    └── recruitment/   # メンバー募集
```

## Firestore コレクション

| コレクション | サブコレクション | 説明 |
|---|---|---|
| `users` | `following`, `followers`, `notifications`, `bookmarks`, `blockedUsers`, `gadgets`, `gadgetCategories`, `hiddenPosts` | ユーザー情報 |
| `posts` | `likes`, `comments` | タイムライン投稿 |
| `tournaments` | `entries`, `rounds`, `brackets`, `timeline`, `team_board`, `photos`, `expenses`, `mvpVotes` | 大会データ |
| `teams` | - | チーム情報 |
| `chats` | `messages`, `album`, `notes` | チャットデータ |
| `venues` | - | 会場情報 |
| `recruitments` | - | メンバー募集 |
| `reports` | - | 通報（管理者のみ） |

## セットアップ

```bash
flutter pub get
flutter run -d chrome       # Web
flutter run -d ios          # iOS
flutter run -d android      # Android
```

## デプロイ

```bash
./deploy.sh web       # Web (Firebase Hosting)
./deploy.sh android   # Android (AAB生成)
./deploy.sh ios       # iOS (Xcode Archive)
./deploy.sh all       # 全プラットフォーム
```
