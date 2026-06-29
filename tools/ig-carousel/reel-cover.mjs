// リール用カバー（サムネ）。1080×1920・クリーム×実機＝フィードの③実機枠に馴染む。
// グリッドは中央1:1付近で切り取られるため、タイトル＋実機を中央バンドに収める。
// 使い方: REEL=score REEL_OUT=... PW_CHROMIUM=... node reel-cover.mjs
import { chromium } from 'playwright';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const KEY=process.env.REEL||'score';
const OUT=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out',KEY);
fs.mkdirSync(OUT,{recursive:true});
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440';

const COVERS={
 score:{pill:'試合中',title:'スコアはリアルタイム。',sub:'入力した瞬間、全員の画面へ',img:'app-score.jpg',pos:'center 22%'},
 bracket:{pill:'大会運営',title:'対戦表はボタンひとつ。',sub:'手書きはもう卒業',img:'app-bracket.jpg',pos:'center top'},
 ranking:{pill:'結果発表',title:'順位は自動で確定。',sub:'セットの勝敗から即集計',img:'app-ranking.jpg',pos:'center top'},
 checkin:{pill:'受付',title:'受付はQRでサッと。',sub:'名簿チェックの行列をゼロに',img:'app-checkin.jpg',pos:'center 30%'},
 finance:{pill:'お金の管理',title:'収支もアプリで丸見え。',sub:'参加費も経費も自動で集計',img:'app-finance.jpg',pos:'center top'},
};
const C=COVERS[KEY];
const heart=`<svg width="34" height="34" viewBox="0 0 24 24"><path fill="${GOLD}" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>`;
const mark=`<svg width="30" height="30" viewBox="0 0 24 24"><path fill="#fff" d="M6 3h12a1 1 0 0 1 1 1v17l-7-4-7 4V4a1 1 0 0 1 1-1z"/></svg>`;

const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 .slide{width:1080px;height:1920px;position:relative;overflow:hidden;font-family:'Noto';background:${CREAM};color:${NAVY}}
 /* グリッド1:1の安全域の目安: y=420〜1500 */
 .ctop{position:absolute;top:470px;left:0;right:0;text-align:center;padding:0 60px;z-index:3}
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:800;font-size:34px;padding:12px 34px;border-radius:999px;margin-bottom:22px}
 .ctitle{font-family:'Dela';font-size:66px;line-height:1.1;white-space:nowrap}
 .csub{margin-top:18px;font-size:36px;font-weight:700;opacity:.78}
 .ph{position:absolute;left:50%;transform:translateX(-50%);top:740px;width:720px;height:1090px;border:14px solid ${DARK};border-radius:56px 56px 0 0;border-bottom:0;overflow:hidden;box-shadow:0 -4px 60px rgba(0,0,0,.24);background:#000;z-index:1}
 .ph img{width:100%;height:100%;object-fit:cover;object-position:${C.pos};display:block}
 .footer{z-index:6;position:absolute;left:0;right:0;bottom:0;height:96px;background:${DARK};color:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 50px}
 .footer .ftxt{font-size:32px;font-weight:700}.footer span{display:flex;align-items:center}
</style><body>
 <div class="slide">
   <div class="ctop"><div class="pill">${C.pill}</div><div class="ctitle">${C.title}</div><div class="csub">${C.sub}</div></div>
   <div class="ph"><img src="data:image/jpeg;base64,${img64(C.img)}"></div>
   <div class="footer"><span>${heart}</span><span class="ftxt">ソフトバレーを、もっと楽しく。</span><span>${mark}</span></div>
 </div>
</body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'}); await p.evaluate(()=>document.fonts.ready);
const out=path.join(OUT,`cover_reel_${KEY}.png`);
await p.locator('.slide').screenshot({path:out});
await br.close(); console.log('done ->',out);
