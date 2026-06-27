# ビジュアルスタイルガイド ＋ 画像生成マスタープロンプト

Gemini など画像生成AIで挿絵・背景を作るときに使う。**世界観を固定する**ための文書。
これを毎回プロンプトに織り込めば、誰が作っても Sofvo らしさが崩れない。

> 画像生成は ChatGPT / Gemini で行う（Codex は不可＝コーディング用）。
> アプリの画面そのものは AI で描かず、必ず実機の画面録画・スクショを使う。

---

## 1. Sofvo の世界観（崩してはいけない軸）

| 要素 | 定義 |
|---|---|
| 色 | ネイビー `#1B3A5C`（信頼・誠実）＋ ゴールド `#C4A962`（上質な差し色） |
| 背景 | 明るいグレー `#F7F7F7` または白。暗くしない |
| トーン | クリーン・ミニマル・誠実で少し上質 |
| 温度感 | 親しみやすいが整っている（地域・ママさん・シニアにも馴染む） |
| 競技 | ソフトバレー＝**柔らかいゴム製の大きめボール・4人制**。硬い6人制ではない |
| 文字 | 画像内に入れない。テロップ・見出しは Canva で後乗せ |

### やってはいけない（NG）
- ポップで派手な色、ネオン、原色だらけ
- マンガ／アニメ調、3Dリアル写真調、ごちゃごちゃした構図
- 硬式の6人制バレー、ビーチバレー、普通のスポーツストックフォト感
- 画像内の日本語テキスト（崩れる）
- 暗い背景・重いグラデーション

---

## 2. マスタープロンプト（毎回これを土台にする）

各投稿の「描きたい中身」を [ここ] に入れて使う。**英語版を推奨**（精度が出る）。

### 英語版（推奨）
```
Flat minimal vector illustration in a clean, calm, slightly premium style.
Subject: [ここに描きたい場面].
Theme: Japanese community soft volleyball (a SOFT rubber ball, casual 4-player
recreational style — NOT a hard 6-player competitive volleyball).
Color palette: deep navy (#1B3A5C) as the main color, warm gold (#C4A962) as a small
accent, on a light (#F7F7F7) or white background.
Style: soft rounded shapes, simple friendly figures, generous empty space, trustworthy
and tidy, approachable for all ages including parents and seniors.
No text, no letters, no logos. Flat 2D, not 3D, not photo-realistic, not cartoonish.
```

### 日本語版（Geminiならこれでも可）
```
クリーンで落ち着いた、少し上質なフラットなベクターイラスト。
描く場面：[ここに描きたい場面]。
テーマ：日本の地域ソフトバレー（柔らかいゴム製の大きめボール・4人制のレクリエーション。
硬い6人制の競技バレーではない）。
配色：ネイビー(#1B3A5C)を主役に、ゴールド(#C4A962)を少しだけ差し色、背景は明るいグレー
(#F7F7F7)か白。
スタイル：柔らかく丸みのある形、シンプルで親しみやすい人物、余白を広く、誠実で整った印象、
ママさんやシニアを含む幅広い年代に馴染む。
画像内に文字・ロゴは入れない。フラットな2D、3Dや写真調・マンガ調にしない。
```

### 末尾に足せる調整キーワード
- 縦長リール用：`Vertical 9:16 composition.`
- カルーセル/正方形用：`Square 1:1 composition.`
- 文字を乗せる前提：`Leave generous empty space in the [top / center / bottom] for text overlay.`

---

## 3. カテゴリ別テンプレ（30投稿に対応）

[場面] をマスタープロンプトに差し込むだけ。よく使う場面を用意。

### ①お役立ち（図解・解説系／カルーセル 1:1）
- ルール解説：`a simple diagram-like scene of a soft volleyball court seen from above with four player positions marked by soft dots`
- 持ち物・チェックリスト：`a tidy flat-lay of simple sports items (soft volleyball, water bottle, shoes, whistle) neatly arranged with empty space for a checklist`
- ウォームアップ：`friendly simple figures doing light stretching warm-ups in a gym, calm and healthy mood`
- ポジション解説：`four simple player figures positioned on a soft volleyball court, soft directional arrows showing movement`

### ②機能紹介（背景・アイコン的／余白多め）
- 表紙背景：`a smartphone in the center surrounded by small simple icons (bracket, checklist, QR code, soft volleyball) with lots of empty space in the middle for text`
- 自動化のうれしさ：`a relieved smiling person holding a smartphone showing a clean organized bracket, light and airy`

### ③コミュニティ（参加型・募集／1:1 or 9:16）
- 地域の声募集：`a friendly map of Japan with small soft volleyball markers in several regions, inviting and warm`
- 大会レポ募集：`simple figures of a soft volleyball team celebrating together after a match, warm and joyful but tidy`
- 募集拡散：`three soft volleyball players waving and looking for one more teammate, one empty spot beside them`

### ④世界観・中の人（あるある・想い）
- 開発の想い：`a calm scene of a person looking at a messy hand-drawn bracket on paper, then a tidy smartphone beside it, before-and-after feeling`
- あるある：`a light humorous but tidy everyday soft volleyball scene (e.g. a parent player checking a phone between games)`

---

## 4. 仕上げの流れ（毎回共通）

```
マスタープロンプト＋[場面] を Gemini に貼る
   ↓ 生成
世界観チェック（色・柔らかいボール・文字なし・整った印象か）→ NGなら作り直し
   ↓
Canva で「本物のアプリ画面（録画/スクショ）＋AI挿絵＋テロップ」を合成
   ↓
リール／カルーセルとして書き出し → 投稿
```

### 投稿前チェックリスト（世界観を守る）
- [ ] ネイビー主役＋ゴールド差し色になっているか（原色だらけになっていないか）
- [ ] ボールが「柔らかいゴム製・4人制」になっているか（硬式6人制でないか）
- [ ] 画像内に変な文字が混ざっていないか
- [ ] フラットで整った印象か（マンガ調・写真調・ごちゃごちゃでないか）
- [ ] アプリ画面は本物（AI生成の偽UIでないか）
