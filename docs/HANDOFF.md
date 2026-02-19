# Sofvo 開発ドキュメント（2026-02-19 最終更新）

================================================================================
## 1. アプリ概要
================================================================================

### 基本情報
- アプリ名: Sofvo
- バージョン: 6.0
- URL: https://sofvo-19d84.web.app
- リポジトリ: https://github.com/sofvo-dev/sofvo
- Firebase: sofvo-19d84

### 概要
ソフトバレーボール大会運営・SNSアプリ。大会の作成からエントリー、対戦表自動生成、スコア入力、順位集計、決勝トーナメントまでワンストップで管理。SNS機能でチーム間の交流も促進。

### 技術スタック
- フレームワーク: Flutter Web (Dart)
- バックエンド: Firebase (Auth / Firestore / Storage / Hosting)
- フォント: Noto Sans JP（PDF用）

### 画面構成（BottomNavigationBar 5タブ）
1. ホーム - タイムライン（投稿・いいね）
2. さがす - 大会検索・メンバー募集検索・ブックマーク
3. 予定 - 参加予定の大会・過去の大会
4. チャット - 1対1メッセージ
5. マイページ - プロフィール・大会管理・メンバー募集管理

================================================================================
## 2. 開発環境・手順
================================================================================

### ローカル実行
cd ~/Desktop/sofvo && flutter run -d chrome

### デプロイ
cd ~/Desktop/sofvo && flutter build web && firebase deploy --only hosting && git add -A && git commit -m "メッセージ" && git push

### 開発用ログイン
LoginScreenで空欄のままログインボタン → devアカウントで自動ログイン（本番前に削除）

### AIチャット開発フロー
1. 変更内容を日本語で伝える（スクショ添付推奨）
2. AIがbashブロック（Python書き換え + flutter run）を生成
3. ターミナルにコピペ → Enter
4. Pythonがファイル書換 → flutter run -d chrome 自動実行
5. ブラウザで確認 → スクショ送信
6. OKならデプロイコマンド実行

### 新チャット開始時
最初のメッセージ: 「sofvo-dev/sofvo を見て続きを進めて」

### 指示のコツ
- スクショを送る → UIの問題を正確に把握
- 色・サイズ・位置を具体的に
- 複数変更を一度にOK
- ビルドエラーはエラーメッセージを貼る

### 注意事項
- main.dart に開発用自動ログインあり（本番前に削除）
- flutter build web で wasm 警告・font tree-shaking 警告は無視してOK
- Firestore複合インデックスが必要な場合はエラーメッセージのURLから作成

================================================================================
## 3. プロジェクト構成
================================================================================

lib/
├── config/
│   └── app_theme.dart                      # テーマ・カラー定義
├── services/
│   ├── auth_service.dart                   # 認証サービス
│   └── bookmark_notification_service.dart  # ブックマーク・通知サービス
├── screens/
│   ├── auth/
│   │   └── login_screen.dart               # ログイン
│   ├── home/
│   │   └── home_screen.dart                # ホームタブ（タイムライン）
│   ├── profile/
│   │   ├── my_page_screen.dart             # マイページ + プロフィール編集
│   │   ├── follow_list_screen.dart         # フォロー/フォロワー一覧
│   │   └── settings_screen.dart            # 設定
│   ├── follow/
│   │   └── follow_search_screen.dart       # 友達検索
│   ├── tournament/
│   │   ├── tournament_search_screen.dart   # さがすタブ（メイン検索画面）
│   │   ├── tournament_detail_screen.dart   # 大会詳細
│   │   ├── tournament_management_screen.dart # 大会管理
│   │   ├── tournament_rules_screen.dart    # ルール設定
│   │   ├── score_input_screen.dart         # スコア入力
│   │   └── venue_search_screen.dart        # 会場検索
│   ├── recruitment/
│   │   ├── recruitment_screen.dart         # 予定タブ
│   │   └── recruitment_management_screen.dart # メンバー募集管理
│   └── chat/
│       └── chat_list_screen.dart           # チャットタブ
├── main.dart                               # エントリポイント
docs/
└── HANDOFF.md                              # このファイル

================================================================================
## 4. 実装済み機能一覧
================================================================================

### 認証・基本UI
- Googleログイン / メールログイン
- プロフィール設定（ニックネーム・アバター・競技歴・エリア・自己紹介）
- プロフィール編集（アバターアップロード対応）
- 設定画面（ログアウト）

### SNS機能
- タイムライン（投稿・いいね）
- ユーザー検索・フォロー（QRコード・ID検索）
- チャット（1対1メッセージ）
- 通知一覧
- フォロー/フォロワー一覧画面

### チーム機能
- チーム作成・編集・削除
- メンバー招待・管理

### 大会運営基盤
- 大会作成・編集・削除
- ルール設定UI（セット数・得点・デュース・キャップ）
- 当日スケジュール設定UI（TimePicker: 開場〜閉会式の6項目）
- 会場登録・検索・連携
- チームエントリー（掲示板に自動投稿）
- エントリー締切自動チェック
- ステータス管理（準備中→募集中→開催中→決勝中→終了）
- テストチーム追加・リセット機能

### 大会進行
- 対戦表自動生成（ラウンドロビン）
- 審判チーム自動割り当て
- スコア入力（数字入力・バリデーション・スライド確認・自動保存）
- 順位自動集計（勝ち点・得失点差・総得点）
- 決勝トーナメント生成
- 全試合完了時ステータス自動更新
- 大会結果セクション（終了時に優勝・準優勝を自動表示）

### さがす画面（検索タブ） ★ 最新の実装
- 上部TabBar:「フォロワーの大会」/「みんなの大会」
- ミニトグル:「大会をさがす」/「メンバーをさがす」/「保存済み」
- テキスト検索 + フィルター（種別・エリア・日付）折りたたみ式
- 種別: すべて/混合/メンズ/レディース（BottomSheet）
- エリア: 北海道〜九州・沖縄（BottomSheet）
- 日付: DateRangePicker
- 「終了した大会も表示」チェックボックス
- フィルターリセットボタン、アクティブ時に赤ドット
- 大会カード: 予定タブ風（左に日付+曜日+種別バッジ、右に情報）
- 種別バッジ色分け（メンズ=青、レディース=ピンク、混合=緑）
- デフォルト「募集中」のみ、開催中・決勝中・準備中は非表示
- 大会日が近い順ソート
- 4人制非表示、コート数非表示、締切日あり
- メンバー募集: フォロー/非フォローでフィルタリング
- メンバー募集カード: アバター+タグ+大会情報カード+応募ボタン+ブックマーク
- ブックマーク: ローカルSet管理で即時反映、右下配置

### ブックマーク（保存）機能 ★ 最新の実装
- 大会・メンバー募集の保存/解除
- さがすタブ内「保存済み」トグルで一覧表示
- Firestore: users/{uid}/bookmarks
- 通知ロジック: 締切3日以内→警告、残り枠2以下→警告
- ログイン時に自動通知チェック

### 予定タブ
- Firestore連携（参加中・主催の大会を自動取得）
- 「次の大会」ハイライトカード（残り日数表示）
- 開催予定一覧（日付カード付き）
- 過去の大会一覧 + 戦績サマリー
- Pull-to-refresh対応

### 大会詳細画面
- 概要タブ（ステータスバナー・基本情報・ルール・募集状況・結果）
- 対戦表タブ（Aコート/Bコート・第N試合・審判チーム表示）
- チームタブ（エントリー済みチーム一覧）
- 掲示板タブ（投稿・いいね・主催者ピン留め）

### PDF機能
- 大会要項PDF / 対戦表PDF / トーナメント表PDF
- Noto Sans JP日本語フォント対応

### UI改善
- 自チーム名の赤ハイライト（対戦表・順位表）
- 開催中のエントリーボタン非表示
- コート順ソート（A→B→C）

================================================================================
## 5. Firestoreデータモデル
================================================================================

### tournaments（大会）
{
  id, title, date, location, venueId, venueAddress,
  courts, maxTeams, currentTeams, entryFee,
  format: "4人制",
  type: "メンズ" | "レディース" | "混合",
  status: "準備中" | "募集中" | "満員" | "開催中" | "決勝中" | "終了",
  organizerId, organizerName,
  deadline: "2026/03/15",
  area: "関東",
  rules: { preliminary: {sets, target, deuce, deuceCap}, final: {...}, scoring: {...} },
  schedule: { openTime, receptionTime, ceremonyTime, matchStartTime, finalsTime, closingTime }
}

サブコレクション:
- entries: { teamId, teamName, enteredBy, enteredAt }
- rounds/round_N/matches: { courtId, courtNumber, matchOrder, teamA*, teamB*, referee*, status, sets, result, confirmed* }
- rounds/round_N/standings/courtId/teams: { teamId, teamName, matchPoints, pointDiff, totalPoints, wins, losses, draws, rank }
- brackets: { bracketId, type, matches... }
- timeline: { authorId, authorName, text, isOrganizer, pinned, likesCount, createdAt }
- checkIns: { teamId, teamName, checkedInAt }

### users（ユーザー）
{
  uid, nickname, avatarUrl, bio,
  experience, area, searchId,
  followersCount, followingCount,
  totalPoints, stats: { tournamentsPlayed, championships }
}

サブコレクション:
- following/{targetUid}: { createdAt }
- bookmarks/{id}: {
    targetId, type: "tournament" | "recruitment",
    title, date, location, type, status,
    nickname, tournamentName, tournamentDate,
    alerts: ["deadline", "slots"],
    lastChecked, createdAt
  }

### teams
{ teamId, teamName, ownerId, memberIds[], createdAt }

### venues
{ venueId, name, address, courts, facilities }

### recruitments（メンバー募集）
{
  userId, nickname, experience, area,
  tournamentName, tournamentDate, tournamentType,
  recruitCount, comment, createdAt
}

================================================================================
## 6. 現在の状態と次のタスク
================================================================================

### 未解決（要確認）
- ブックマーク保存済みリストの表示: Firestore書き込みは成功、DefaultTabController競合を解消しStreamBuilder直接参照に変更済み。動作確認必要。

### 次のタスク候補（優先度高）
1. QRコード受付（3パターン: チーム読み取り / 主催者読み取り / 手動）
2. 予選2の動作確認（順位ベースのコート再編成）
3. 大会終了ボタン（主催者操作→ステータス「終了」→結果自動表示）
4. 参加者向け画面整備（非主催者の試合・結果・順位表示改善）

### 中優先度
- 大会テンプレート機能
- プッシュ通知（FCM）
- マイページ強化（戦績グラフ・バッジ・ランキング）
- チームページ充実

### 将来構想
- MVP投票、大会ギャラリー、リアルタイムスコアボード
- 天気情報、カレンダー連携、Google Maps
- Stripe決済、ネイティブアプリ、AI推奨

================================================================================
## 7. 作業履歴
================================================================================

### 2026-02-19（セッション3 - 最新）
- ブックマーク機能実装（bookmark_notification_service.dart新規作成）
- 大会・募集カードにブックマークアイコン追加（右下配置）
- ローカルSet管理で即時反映
- さがすタブに「保存済み」トグル追加
- 通知ロジック実装（締切3日以内・残り枠2以下）
- 「友達の大会」→「フォロワーの大会」名称変更
- 月別カラーリング廃止→ステータス色統一
- みんなの大会にもトグル追加
- メンバー募集にフォロー/非フォローフィルター追加
- メンバー募集カード全面リニューアル
- メンバー募集にもテキスト検索+フィルター追加

### 2026-02-19（セッション2）
- 種別バッジ分離（色分け）、フィルター折りたたみ式
- デフォルト募集中のみ、過去大会チェックボックス
- 4人制・コート数非表示、締切日・曜日追加
- 近い日付順ソート

### 2026-02-19（セッション1）
- さがす画面2段構成化、予定タブFirestore連携
- スケジュール設定UI、大会結果セクション

### 2026-02-18
- PDFダウンロード3種、バグ修正多数、締切自動チェック

### 2026-02-16
- 自チームハイライト、審判チーム割当、コート表記変更
- スコアバリデーション強化、自動保存

### 2026-02-15
- ルール設定UI改修、会場連携、スコア入力改善
- 決勝トーナメント生成、掲示板機能

================================================================================
## 8. 設計判断メモ
================================================================================

- ブックマーク状態: ローカルSet管理（FutureBuilderだと再描画問題あり）
- フィルター: 折りたたみ式（常時表示だとスペース圧迫）
- 4人制: 非表示（ソフトバレーは必ず4人制）
- コート数: カードでは非表示（情報量削減）
- 開催中の大会: さがすタブに非表示（予定タブで確認）
- メンバー募集: フォロー状態でフィルタリング（友達/みんな分離）
- 保存済みリスト: さがすタブ内に統合（マイページではなく）
