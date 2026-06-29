# ig-carousel — Instagramカルーセル画像ジェネレーター

`docs/instagram/canva-bulk/carousels.csv` の文章を読み込み、Sofvoブランドの
カルーセル画像（PNG・1080×1350）を**全自動で生成**するツール。

- デザイン：ネイビー×ゴールド・極太ゴシック（Dela Gothic One）・Sofvo文字ロゴ・
  下部フッターバー固定（`visual-direction.md` の方針に準拠）。
- 1投稿＝5枚（表紙／中3枚／CTA）。日本語は `word-break:auto-phrase` で自然に改行。

## 使い方

```bash
# 1) フォントを用意（初回のみ）
mkdir -p tools/ig-carousel/fonts
curl -sSL -o tools/ig-carousel/fonts/DelaGothicOne-Regular.ttf \
  "https://github.com/google/fonts/raw/main/ofl/delagothicone/DelaGothicOne-Regular.ttf"
curl -sSL -o tools/ig-carousel/fonts/NotoSansJP.ttf \
  "https://github.com/google/fonts/raw/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"

# 2) Playwright（Chromium）が必要
npm i -D playwright   # または環境の playwright を利用

# 3) 生成（引数なし=投稿1のみ / カンマ区切りで複数 / all相当は 0..11）
node tools/ig-carousel/render.mjs 0,1,2,3,4,5,6,7,8,9,10,11
# 出力先: tools/ig-carousel/output/postNN_S.png
```

## 新しい投稿を作るとき

1. `docs/instagram/canva-bulk/carousels.csv` に行を足す（列は固定）。
2. `docs/instagram/canva-bulk/captions.md` に同じ順でキャプションを足す。
3. `render.mjs` を実行 → PNG生成 → Instagramで予約。

> 文章（CSV／キャプション）はClaudeに「次の◯本作って」と頼めば量産できる。
> 画像はこのツールが生成するので、運用者の作業は予約だけ。

## カスタマイズ

`render.mjs` 内の定数・CSSで調整：
- 色：`NAVY` / `CREAM` / `GOLD` / `DARK`
- サイズ：`.slide` の `width/height` と `viewport`
- フォントサイズ：`.ctitle` / `.cardhead` / `.li` など
