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

function coverSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
  <div class="shot"><div class="pill">${d.pill}</div><div class="ctitle">${d.title}</div><div class="csub">${d.sub}</div></div>
  <div class="fphone fcov"><img src="data:image/jpeg;base64,${img64(d.coverImg)}"></div>${footer}</div>`;}
function shotSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
  <div class="shot"><div class="shead">${d.head}</div><div class="scap">${d.cap}</div></div>
  <div class="fphone"><img src="data:image/jpeg;base64,${img64(d.img)}"></div>${footer}</div>`;}
function ctaSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
  <div class="cta"><div class="ctaT">${d.title}</div><div class="ctaS">${d.sub}</div></div>${footer}</div>`;}

function page(slides){
 const body=slides.map(s=>s.type==='cover'?coverSlide(s):s.type==='cta'?ctaSlide(s):shotSlide(s)).join('');
 return `<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 .slide{width:1080px;height:1350px;position:relative;overflow:hidden;font-family:'Noto'}
 .slide.navy{background:${NAVY};color:#fff}.slide.cream{background:${CREAM};color:${NAVY}}
 .wm{position:absolute;top:60px;left:74px;font-family:'Noto';font-weight:900;font-size:50px;z-index:5}
 .footer{z-index:6;position:absolute;left:0;right:0;bottom:0;height:92px;background:${DARK};color:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 48px}
 .footer .ftxt{font-size:32px;font-weight:700}.footer span{display:flex;align-items:center}
 .cover{position:absolute;top:130px;left:0;right:0;bottom:92px;display:flex;flex-direction:column;align-items:flex-start;padding:0 80px}
 
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:700;font-size:34px;padding:12px 34px;border-radius:999px;margin-bottom:40px}
 .ctitle{font-family:'Dela';font-size:62px;line-height:1.3}.csub{margin-top:18px;font-size:36px;font-weight:700;color:${GOLD}}
 .cphone{align-self:center;width:520px;height:560px;margin-top:40px;border:12px solid ${DARK};border-radius:38px;overflow:hidden;box-shadow:0 26px 55px rgba(0,0,0,.45);background:#000}
 .cphone img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
 .shot{position:absolute;top:140px;left:0;right:0;text-align:center;z-index:3}
 .shead{font-family:'Dela';font-size:62px;padding:0 50px;margin-bottom:14px}
 .fphone{position:absolute;left:50%;transform:translateX(-50%);bottom:0;width:760px;height:920px;border:14px solid ${DARK};border-radius:56px 56px 0 0;border-bottom:0;overflow:hidden;box-shadow:0 -4px 50px rgba(0,0,0,.22);background:#000;z-index:1}
 .fphone.fcov{height:720px}
 .fphone img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
 .scap{font-size:38px;font-weight:700;padding:0 60px}
 .scap b{color:${GOLD}}
 .cta{position:absolute;top:0;left:0;right:0;bottom:92px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:80px}
 .ctaT{font-family:'Dela';font-size:78px;line-height:1.35}.ctaS{margin-top:34px;font-size:46px;font-weight:700;color:${GOLD}}
 </style><body>${body}</body>`;
}

// 運営者向け 機能カルーセル
const slides=[
 {type:'cover',bg:'navy',pill:'大会運営',title:'大会運営、<br>ぜんぶアプリで。',sub:'紙も電卓も、もういらない',coverImg:'app-home.jpg'},
 {type:'shot',bg:'cream',head:'対戦表を自動作成',img:'app-bracket.jpg',cap:'チーム数を入れるだけ'},
 {type:'shot',bg:'cream',head:'リアルタイムでスコア',img:'app-score.jpg',cap:'入力すれば<b>全員に即共有</b>'},
 {type:'shot',bg:'cream',head:'順位表は自動集計',img:'app-ranking.jpg',cap:'勝敗・得失点も自動で'},
 {type:'shot',bg:'cream',head:'QRで受付',img:'app-checkin.jpg',cap:'かざすだけでチェックイン'},
 {type:'shot',bg:'cream',head:'収支もまるわかり',img:'app-finance.jpg',cap:'参加費・経費を自動集計'},
 {type:'cta',bg:'navy',title:'ぜんぶ、無料。',sub:'プロフィールのリンクから'},
];
const br=await chromium.launch();
const p=await br.newPage({viewport:{width:1080,height:1350},deviceScaleFactor:1});
await p.setContent(page(slides),{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);
const els=await p.locator('.slide').all();
for(let i=0;i<els.length;i++){await els[i].screenshot({path:path.join(OUT,`feat01_${i+1}.png`)});}
await br.close();console.log('done',els.length,'slides ->',OUT);
