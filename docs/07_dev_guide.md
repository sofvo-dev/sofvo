# 開発環境・手順ガイド（2026-02-19 更新）

## 基本情報
- リポジトリ: https://github.com/sofvo-dev/sofvo
- 本番: https://sofvo-19d84.web.app
- Firebase: sofvo-19d84
- ローカル実行: cd ~/Desktop/sofvo && flutter run -d chrome
- デプロイ: cd ~/Desktop/sofvo && flutter build web && firebase deploy --only hosting && git add -A && git commit -m "メッセージ" && git push

## AIチャット開発フロー
1. 変更内容を日本語で伝える（スクショ添付推奨）
2. AIがbashブロックを生成
3. ターミナルにコピペ → Enter
4. Pythonがファイル書換 → flutter run -d chrome 自動実行
5. ブラウザで確認 → スクショ送信
6. OKならデプロイコマンド実行

## 新チャット開始時
「sofvo-dev/sofvo を見て続きを進めて」と入力

## 指示のコツ
- スクショを送る
- 色・サイズ・位置を具体的に
- 複数変更を一度にOK
- ビルドエラーはメッセージを貼る

## プロジェクト構成
lib/screens/tournament/tournament_search_screen.dart - さがすタブ
lib/screens/tournament/tournament_detail_screen.dart - 大会詳細
lib/screens/tournament/tournament_management_screen.dart - 大会管理
lib/screens/recruitment/recruitment_screen.dart - 予定タブ
lib/screens/profile/my_page_screen.dart - マイページ
lib/config/app_theme.dart - テーマ定義
lib/main.dart - エントリポイント（dev自動ログイン付き）
docs/ - ドキュメント群
