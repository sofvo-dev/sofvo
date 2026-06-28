import { chromium } from 'playwright';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const OUT=path.join(import.meta.dirname,'output-feature');
fs.mkdirSync(OUT,{recursive:true});
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440';
const wm=(bg)=>`<div class="wm"><span style="color:${bg==='navy'?'#fff':NAVY}">Sof</span><span style="color:${GOLD}">vo</span></div>`;
const heart=`<svg width="34" height="34" viewBox="0 0 24 24"><path fill="${GOLD}" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>`;
const mark=`<svg width="30" height="30" viewBox="0 0 24 24"><path fill="#fff" d="M6 3h12a1 1 0 0 1 1 1v17l-7-4-7 4V4a1 1 0 0 1 1-1z"/></svg>`;
const footer=`<div class="footer"><span>${heart}</span><span class="ftxt">ソフトバレーを、もっと楽しく。</span><span>${mark}</span></div>`;

// 表紙のみ：実機（クリーム背景・暗いアプリ画面とコントラスト／枠で分離）
function coverSlide(d){return `<div class="slide cream">${wm('cream')}
 <div class="ctop"><div class="pill">${d.pill}</div><div class="ctitle">${d.title}</div><div class="csub">${d.sub}</div></div>
 <div class="fphone"><img src="data:image/jpeg;base64,${img64(d.img)}"></div>${footer}</div>`;}

function build(cover){
 return `<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 .slide{width:1080px;height:1350px;position:relative;overflow:hidden;font-family:'Noto'}
 .slide.navy{background:${NAVY};color:#fff}.slide.cream{background:${CREAM};color:${NAVY}}
 .wm{position:absolute;top:58px;left:74px;font-weight:900;font-size:50px;z-index:7}
 .footer{z-index:6;position:absolute;left:0;right:0;bottom:0;height:92px;background:${DARK};color:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 48px}
 .footer .ftxt{font-size:32px;font-weight:700}.footer span{display:flex;align-items:center}
 .ctop{position:absolute;top:140px;left:0;right:0;text-align:center;padding:0 70px;z-index:3}
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:700;font-size:32px;padding:11px 30px;border-radius:999px;margin-bottom:24px}
 .ctitle{font-family:'Dela';font-size:64px;line-height:1.3;color:${NAVY}}
 .csub{margin-top:16px;font-size:36px;font-weight:700;color:${NAVY};opacity:.78}
 .fphone{position:absolute;left:50%;transform:translateX(-50%);bottom:0;width:780px;height:800px;border:14px solid ${DARK};border-radius:56px 56px 0 0;border-bottom:0;overflow:hidden;box-shadow:0 -4px 50px rgba(0,0,0,.22);background:#000;z-index:1}
 .fphone img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
 </style><body>${build_cover(cover)}</body>`;
}
function build_cover(c){return coverSlide(c);}

// 機能投稿②：スコア入力（リアルタイムスコア）
const cover={pill:'試合中',title:'スコアは、<br>リアルタイム。',sub:'入力した瞬間、全員の画面へ',img:'app-score.jpg'};

// PW_CHROMIUM で実行ファイルを明示できる（プリインストールChromiumを使う環境向け）。未指定なら通常起動。
const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1350},deviceScaleFactor:1});
await p.setContent(build(cover),{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);
await p.locator('.slide').screenshot({path:path.join(OUT,'cover_score.png')});
await br.close();console.log('done cover');
