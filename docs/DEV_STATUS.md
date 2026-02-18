# 開発引き継ぎ情報

## リポジトリ
- GitHub: https://github.com/sofvo-dev/sofvo (public)
- 本番: https://sofvo-19d84.web.app
- Firebase: sofvo-19d84

## 開発ルール
- 実行: cd ~/Desktop/sofvo && flutter run -d chrome
- デプロイ: flutter build web && firebase deploy --only hosting && git add -A && git commit -m "メッセージ" && git push
- コード確認はClaudeがGitHub経由で行う（ユーザーにgrep/sedさせない）
- 開発用自動ログイン: main.dart に設定済み（本番前に削除）

## ドキュメント構成
- docs/01_overview.md — アプリ概要・技術スタック
- docs/02_implemented.md — 実装済み機能一覧
- docs/03_tournament_flow.md — 大会運営フロー・スコア仕様
- docs/04_data_model.md — Firestoreデータモデル
- docs/05_todo.md — 開発ロードマップ
- docs/06_changelog.md — 作業履歴

## 新チャット開始時の指示
「sofvo-dev/sofvo を見て続きを進めて」と言えばOK
