# 引き継ぎメモ（Sofvo マーケ：Instagram ＆ LP）

別AIへの引き継ぎ用。これまでの経緯・決定事項・ファイル・残タスクをまとめる。
**特に Instagram 投稿は本ドキュメント下部に詳細あり。**

最終更新：2026-06-28

---

## 0. 全体ゴール
ソフトバレー専用アプリ「Sofvo」を Instagram（@**sofvo.official**）で普及させる。
- オーガニック投稿でフォロワーの質を上げ、**DMで主催者・チームに個別アプローチ**して実ユーザー獲得。
- プロフィールのリンク → **`sofvo.com/start`（初心者向けLP）**。
- 運用者の負担を最小化（画像はコード生成、運用者は「予約だけ」を目指す）。

## 1. ブランド（投稿もLPも共通）
| 項目 | 値 |
|---|---|
| ネイビー（主役） | `#1B3A5C` |
| ネイビー濃（フッター等） | `#0F2440` |
| クリーム（明背景） | `#F7F5EF` |
| ゴールド（差し色） | `#C4A962` |
| 見出しフォント | **Dela Gothic One**（極太） |
| 本文フォント | **Noto Sans JP** |
| ロゴ | 文字ロゴ「Sof（白or紺）＋vo（金）」 |
| フッター決め文句 | **ソフトバレーを、もっと楽しく。** |

ターゲット：大会主催者・運営、チーム/プレイヤー、ママさん・シニア・地域クラブ。

---

## 2. ここまでの成果（ざっくり）
- **LP**：`website/start.html`（= `sofvo.com/start`）公開済み。アニメ・「紙→デジタル」・無料サポート・実機画面ギャラリー入り。**404は解消済み**（後述）。※LPの改行/サイズ/デスクトップ/アニメの微調整は別AIが対応中。
- **Instagram テキストカルーセル 24本**（`docs/instagram/canva-bulk/carousels.csv`）生成済み・PNG納品済み。
- **Instagram 機能カルーセル（実機画像入り）** の型を確立。
- **実機スクショ 19枚** をリポジトリに保存（`website/images/app-*.jpg`）。
- **生成ツール一式**（`tools/ig-carousel/`）。
- **投稿状況**：テキスト投稿 1・2 をユーザーが Instagram にアップ済み。

---

## 3. Instagram 投稿【詳細】★最重要

### 3-1. 共通デザイン仕様（全投稿）
- サイズ **1080 × 1350px（4:5）**。
- **全スライド下部にフッターバー**（濃紺 `#0F2440`）：左♥(金) ＋ 中央「ソフトバレーを、もっと楽しく。」＋ 右🔖。`z-index` は最前面。
- **左上に文字ロゴ**「Sofvo」（背景が紺なら Sof=白、クリームなら Sof=紺、vo=常に金）。
- 見出しは **Dela Gothic One**（極太）。キーワードはゴールド。
- 表紙は投稿ごとに **ネイビー / クリーム 交互**（プロフィールのグリッドが市松になる）。

### 3-2. フィードの並び順（ユーザー決定）★
**3サイクルの繰り返し**：
```
① ネイビー（文字カルーセル）
② クリーム（文字カルーセル）
③ 実機（機能投稿：表紙が大きな実機画面）
…を繰り返す
```
- グリッドに出るのは **各投稿の1枚目（表紙）だけ**。だから①紺・②クリーム・③実機写真 で3種が綺麗に分かれる。
- 注意：実機投稿の**中の**スライドでクリームを使うのはOK（グリッドに出ないので「クリーム2回」にはならない）。

### 3-3. 投稿タイプA：テキストカルーセル（お役立ち/入門/コミュニティ）
- データ：`docs/instagram/canva-bulk/carousels.csv`（24本ぶん。列：pill, cover_title, cover_sub, s2_title, s2_body, s3_title, s3_body, s4_title, s4_body, cta_title, cta_sub）
- キャプション：`docs/instagram/canva-bulk/captions.md`（同じ並び順）
- 生成：`tools/ig-carousel/render.mjs`（5スライド：表紙＋中3＋CTA。表紙は index 偶数=ネイビー / 奇数=クリーム）
- ※ `／` 区切りが箇条書きになる。`""` でくくる（CSVルール）。

### 3-4. 投稿タイプB：機能投稿（実機画像入り）★現在の主軸
**最重要の決定：「1機能 ＝ 1投稿」**（1投稿に詰め込まない＝ネタが長持ち・投稿数が増える）。
- 構成（`tools/ig-carousel/feature-single.mjs`）：
  1. **1枚目＝実機画面（下まで突き抜けるレイアウト）**＋タイトル。**背景クリーム**（最終仕様は下の 3-4-1。表紙だけは `cover-only.mjs` で確定）。
  2. **2枚目＝「こんな悩み、ありませんか？」**（白カード＋箇条書き。背景クリーム）
  3. **3枚目＝「Sofvoなら〜」**（解決。白カード＋箇条書き。背景ネイビー）
  4. **4枚目＝CTA**（「無料・プロフィールのリンクから」）
- **実機画面のレイアウト要点（ユーザーのこだわり）**：
  - スマホ枠を**大きく**、**スライド下端まで突き抜け**させる（`.fphone{position:absolute;bottom:0;...;border-bottom:0;border-radius:上だけ}`）。
  - フッターは `z-index` を上げてスマホの上に出す（中央文字が隠れないように）。
  - 実機スライドの背景は**クリーム**にする（**ネイビーだと暗いアプリ画面と被る**ため。←指摘済み）。
  - `object-fit:cover; object-position:top` で**画面上部を表示**（下のナビは切れてOK）。
- 既に作った機能投稿：
  - **複数機能まとめ版**①「大会運営」（`feature.mjs`）= 表紙＋対戦表/スコア/順位/QR/収支の5実機＋CTA。→ **今は単機能版を主軸にする方針に変更**。
  - **単機能サンプル**「対戦表」（`feature-single.mjs`）= 上記4枚構成。納品済み。

#### 3-4-1. 実機表紙（1枚目）の最終確定仕様 ★2026-06-28 ユーザー「完璧」承認
ツール：**`tools/ig-carousel/cover-only.mjs`**（表紙だけ量産。クリーム背景）。**この設定で確定**。
- **背景＝クリーム**（`#F7F5EF`）で統一（暗いアプリ画面が映える／濃紺ベゼルで枠が必ず分離。ネイビー背景は不採用）。
- **左上の文字ロゴ「Sofvo」は削除**（表紙はタイトル＋実機＋フッターのみで構成）。
- **タイトルは1行**（`white-space:nowrap`・Dela・ネイビー）。`.ctop{top:50px}`。pill＝ゴールド／sub＝ネイビー。キーワードのゴールド文字はクリーム上で低コントラストなので**表紙では使わず**ゴールドはpillのみ。
- **実機スマホ**：`width:780px`（＝**スケールはこの幅で固定**。"大きくする"のではなく幅は据え置き）／`top:300px; bottom:0; height:auto`（**下端はフッターまで突き抜け**・上に持ち上げて中央余白を詰めた値）。ベゼル `14px #0F2440`・`border-radius:56px 56px 0 0`・`border-bottom:0`。
- **クロップは原則 `object-position:center top`（上から自然表示）。QR等を中央へ無理にクロップしない**（下端で自然に切れてOK）。※必要な機能だけ `pos` で微調整可能（現状は全機能 top）。
- フッター（濃紺 `#0F2440`・♥／中央文言／🔖）は最前面。
- **試行錯誤の結論メモ**：「実機をもっと見せたい」→ ただ大きくする（幅を広げる）と端末感が消え×。正解は**幅＝スケールは固定したまま、スマホを上へ持ち上げて下までより多く見せる**＋**上から自然クロップ**。タイトルと実機を一緒に上げて中央余白を詰める。
- **確定した各機能の表紙コピー（cover-only.mjs の covers 配列）**：

  | key | pill | title（1行） | sub | 実機画像 |
  |---|---|---|---|---|
  | score | 試合中 | スコアはリアルタイム。 | 入力した瞬間、全員の画面へ | app-score.jpg |
  | ranking | 結果発表 | 順位は自動で確定。 | セットの勝敗から即集計 | app-ranking.jpg |
  | checkin | 受付 | 受付はQRでサッと。 | 名簿チェックの行列をゼロに | app-checkin.jpg |
  | bracket | 大会運営 | 対戦表はボタンひとつ。 | 手書きはもう卒業 | app-bracket.jpg |
  | finance | お金の管理 | 収支もアプリで丸見え。 | 参加費も経費も自動で集計 | app-finance.jpg |

- **生成**：`PW_CHROMIUM=<chromium本体> node tools/ig-carousel/cover-only.mjs` → `output-feature/cover_<key>.png`。
  - リモート環境では `PW_CHROMIUM=/opt/pw-browsers/chromium-1194/chrome-linux/chrome`（プリインストール）。ローカルは `npx playwright install` 済みなら未指定でOK（`cover-only.mjs` は `PW_CHROMIUM` 未指定なら通常起動）。
  - フォントは `tools/ig-carousel/fonts/`（Dela Gothic One・Noto Sans JP。`.gitignore`済み。READMEのcurlで取得）。
- **TODO**：残り3枚（②悩み→③Sofvoなら→④CTA）も同じ表紙仕様に合わせて `feature-single.mjs` 側を更新する（旧ネイビー表紙のままなので要差し替え）。

### 3-4-2. リール（動画）★2026-06-28 追加
ツール：**`tools/ig-carousel/reel.mjs`**（Playwrightでフレーム単位レンダリング→ffmpegでMP4/H.264）。
- 仕様：**1080×1920・約15秒・30fps・無音MP4**（投稿時にInstagramでトレンド音源を付ける運用）。
- スタイル：**モーショングラフィック**（フック→実機6機能を1.55秒ずつ→CTA）。背景はクリーム/ネイビー交互、文字Dela、実機は角丸フル端末で中央配置。
- 構成：イントロ「ソフトバレーの大会、ぜんぶこれ1つ。」→ 対戦表/スコア/順位表/QR受付/収支/大会さがす → CTA「無料で、はじめよう。/ @sofvo.official / プロフィールのリンクから」。
- アニメは CSS ではなく **`window.renderAt(t)` でフレーム毎に opacity/transform を駆動**（決定論的。クロスフェード＋スライドイン）。
- **ffmpeg**：同梱の Playwright ffmpeg は VP8 のみ（H.264不可）。`@ffmpeg-installer/ffmpeg`（npm経由＝プロキシのサイズ制限を回避）を使う。`ffmpeg-static` は GitHub DL が途中で切れて壊れるので不可。環境変数 `FFMPEG` でバイナリ指定可。
- 生成：`REEL_OUT=<出力先> FFMPEG=<ffmpegパス> PW_CHROMIUM=<chromium> node tools/ig-carousel/reel.mjs` → `<REEL_OUT>/sofvo-reel-15s.mp4`（中間フレームは `<REEL_OUT>/frames/`）。
- 出力（`reel-out/`）は `.gitignore` 済み。配布はチャット添付のMP4。

### 3-5. 実機スクショ素材（`website/images/`）
ユーザーがアップ済み（jpg・iPhone実機）。**使える主なもの**：
| ファイル | 画面 | 用途（機能投稿） |
|---|---|---|
| app-login.jpg | ログイン/新規登録 | 登録 |
| app-home.jpg | タイムライン | コミュニティ |
| app-search-tournaments.jpg | 大会をさがす | 大会発見 |
| app-search-members.jpg | メンバーをさがす | 仲間募集 |
| app-notifications.jpg | お知らせ | 通知 |
| app-overview.jpg | 大会概要・エントリー | 大会情報 |
| app-bracket.jpg / -random / -new | 対戦表（試合一覧/プレビュー/空状態） | 対戦表自動作成 |
| app-score.jpg | スコア入力（黒画面） | リアルタイムスコア |
| app-ranking.jpg | 最終順位（トロフィー） | 順位自動集計 |
| app-checkin.jpg | 受付QR | QRチェックイン |
| app-finance.jpg | 収支管理（¥11,500） | 収支管理 |
| app-organizer-menu.jpg | 主催者メニュー | 機能の広さ |
| app-board.jpg | 掲示板・お知らせ送信 | 連絡 |
| app-team.jpg | チーム戦績 | 戦績 |
| app-friends.jpg | 友達をさがす | （補助） |
| app-venues.jpg | 会場をさがす | 会場情報 |
- **未提供**：`app-mypage.jpg`（マイページ戦績）, `app-mytournaments.jpg`（マイ大会）。あると尚良い。

### 3-6. 生成ツールの使い方（`tools/ig-carousel/`）
前提：Playwright(Chromium) ＋ フォント2種をローカルに用意。
```bash
mkdir -p tools/ig-carousel/fonts
curl -sSL -o tools/ig-carousel/fonts/DelaGothicOne-Regular.ttf \
  "https://github.com/google/fonts/raw/main/ofl/delagothicone/DelaGothicOne-Regular.ttf"
curl -sSL -o tools/ig-carousel/fonts/NotoSansJP.ttf \
  "https://github.com/google/fonts/raw/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"
# テキストカルーセル（CSVから）
node tools/ig-carousel/render.mjs 0,1,2,...   # 出力 output/postNN_S.png
# 機能投稿（単機能＝主軸。投稿内容はスクリプト内の post= を編集）
node tools/ig-carousel/feature-single.mjs     # 出力 output-feature/single_S.png
```
- 画像はスクリプト内に **base64 埋め込み**でレンダリング（日本語フォント崩れ防止）。
- フォント `fonts/`・出力 `output*/` は `.gitignore` 済み。

### 3-7. キャプションの型
各投稿：共感の一言🏐 → 機能の要点 → 無料を明記 → CTA「プロフィールのリンクから（sofvo.com/start）」→ ハッシュタグ（#ソフトバレー #ソフトバレーボール #大会運営 #ママさんバレー 等）。

### 3-8. Instagram 投稿の残タスク
- [ ] **単機能の機能投稿を量産**（feature-single.mjs を機能ごとに）：スコア／順位表／QR受付／収支管理／タイムライン／大会さがす／メンバーさがす／お知らせ …（各1投稿）
- [ ] それぞれの「悩み→Sofvoなら」文章＋キャプションを用意
- [ ] **プロフィールのリンクを `sofvo.com/start` に設定**（集客導線）
- [ ] 月初にまとめて生成→予約のルーティン化
- [ ] （任意）`app-mypage` / `app-mytournaments` のスクショ追加

### 3-9. 運用の方針メモ
- **画像をAIに一枚絵で描かせるのは不採用**（古く見える）。テンプレ＋実機で作る。
- Predis.ai を一度検討したが**有料（年$474）で見送り**。現状はコード生成（無料）。
- Canva Pro は所持。手動運用するなら `docs/instagram/canva-setup.md`（Bulk Create）参照。

---

## 4. LP（`website/start.html` = sofvo.com/start）
- 構成：ヒーロー（実機ホーム画面）→ 紙→デジタル → Sofvoでできること（実機画像）→ はじめ方3ステップ → どれだけラクになる（ビフォーアフター）→ 大会を運営する方へ → アプリの画面（実機ギャラリー横スクロール）→ 無料サポート（打ち合わせ無料）→ CTA。
- **配信の重要事項（404対策）**：
  - `sofvo.com` は **Firebase Hosting（public: `build/web`）= Flutterアプリ**を配信。
  - `website/` の中身は **デプロイ時に `.github/workflows/firebase-deploy.yml` が個別に `build/web` へコピー**している。**新しいページを足したら、このワークフローにコピー行を追加必須**（`start.html` も追加済み）。
  - `firebase.json` に `"cleanUrls": true` ＋ **`/start`→`/start.html` の明示リライト**を追加済み。
  - 過去、他開発者の大量マージで「コピー行の無い版」がデプロイされ404になった経緯あり。困ったら **mainから手動で `firebase-deploy.yml` を Run（workflow_dispatch）**して上書きするのが確実。
- 残：LP の改行（iOS Safariは `word-break:auto-phrase` 非対応）・実機サイズ・デスクトップ最適化・アニメ強化は**別AIが対応中**。

---

## 5. リポジトリ / Git 運用
- 作業ブランチ：`claude/quirky-thompson-ggnau3`
- `website/**`・`docs/**`・`tools/**`・`.github/**` は**審査不要**（mainマージで即デプロイ）。`lib/**` 等アプリ本体はストア再提出が必要。
- **注意**：直接 main にマージすると「自動PR作成ワークフロー」が "No commits between" で失敗することがある（無害）。基本は**ブランチにpushして自動PRに任せる**。急ぎは手動マージ可。

## 6. 関連ファイル一覧
```
docs/instagram/
  HANDOFF.md              ← このファイル
  README.md               戦略の全体像
  visual-direction.md     ビジュアル方針（写真+極太ゴシック）
  content-calendar-30.md  企画30本＋ハッシュタグ
  ai-post-generator.md    AIに中身を作らせるプロンプト
  canva-setup.md          Canva Pro 半自動運用（代替手段）
  canva-bulk/carousels.csv   テキスト投稿24本のデータ
  canva-bulk/captions.md     同キャプション
tools/ig-carousel/
  render.mjs              テキストカルーセル生成
  feature.mjs             複数機能まとめカルーセル（実機入り）
  feature-single.mjs      ★単機能＝1投稿（現在の主軸）
  README.md               ツールの使い方
website/
  start.html              初心者LP（sofvo.com/start）
  images/app-*.jpg        実機スクショ素材
  images/lp-hero.png 等   LP用グラフィック
.github/workflows/firebase-deploy.yml   デプロイ（website/コピー含む）
firebase.json             hosting設定（cleanUrls・/startリライト）
```
