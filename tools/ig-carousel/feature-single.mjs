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
const bullets=b=>b.split('／').map(s=>`<div class="li"><span class="dot"></span><span>${s}</span></div>`).join('');

// 1枚目：実機（下まで突き抜け・少し上げ）
function coverSlide(d){return `<div class="slide navy">${wm('navy')}
 <div class="ctop"><div class="pill">${d.pill}</div><div class="ctitle">${d.title}</div><div class="csub">${d.sub}</div></div>
 <div class="fphone"><img src="data:image/jpeg;base64,${img64(d.img)}"></div>${footer}</div>`;}
// 2枚目以降：解説（カード＋箇条書き）
function textSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
 <div class="content"><div class="card"><div class="chead"><span class="bar"></span>${d.head}</div><div class="cbody">${bullets(d.body)}</div></div></div>${footer}</div>`;}
function ctaSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
 <div class="cta"><div class="ctaT">${d.title}</div><div class="ctaS">${d.sub}</div></div>${footer}</div>`;}

function build(post){
 const slides=[coverSlide(post.cover),...post.slides.map(textSlide),ctaSlide(post.cta)];
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
 .ctitle{font-family:'Dela';font-size:64px;line-height:1.3}
 .csub{margin-top:16px;font-size:36px;font-weight:700;color:${GOLD}}
 .fphone{position:absolute;left:50%;transform:translateX(-50%);bottom:0;width:780px;height:800px;border:14px solid ${DARK};border-radius:56px 56px 0 0;border-bottom:0;overflow:hidden;box-shadow:0 -4px 50px rgba(0,0,0,.22);background:#000;z-index:1}
 .fphone img{width:100%;height:100%;object-fit:cover;object-position:top;display:block}
 .content{position:absolute;top:0;left:0;right:0;bottom:92px;display:flex;align-items:center;padding:80px}
 .card{background:#fff;color:${NAVY};border-radius:40px;padding:76px 64px;width:100%;box-shadow:0 16px 40px rgba(0,0,0,.18)}
 .chead{font-family:'Dela';font-size:58px;line-height:1.32;display:flex;align-items:flex-start;margin-bottom:46px}
 .bar{display:inline-block;width:16px;height:52px;background:${GOLD};border-radius:8px;margin-right:26px;margin-top:6px;flex:0 0 auto}
 .li{display:flex;align-items:flex-start;font-size:46px;line-height:1.6;font-weight:500;margin:30px 0}
 .dot{width:18px;height:18px;border-radius:50%;background:${GOLD};margin:22px 28px 0 0;flex:0 0 auto}
 .cta{position:absolute;top:0;left:0;right:0;bottom:92px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:80px}
 .ctaT{font-family:'Dela';font-size:74px;line-height:1.35}.ctaS{margin-top:32px;font-size:44px;font-weight:700;color:${GOLD}}
 </style><body>${slides.join('')}</body>`;
}

// 機能投稿①：対戦表（1実機＋解説）
const post={
 name:'対戦表',
 cover:{pill:'大会運営',title:'対戦表、<br>ボタンひとつ。',sub:'手書きはもう卒業',img:'app-bracket.jpg'},
 slides:[
  {bg:'cream',head:'こんな悩み、ありませんか？',body:'手書きで30分以上かかる／組み直しが大変／書き間違いが起きる'},
  {bg:'navy',head:'Sofvoなら数タップ',body:'チーム数を入れるだけ／リーグもトーナメントも対応／組み直しもワンタップ'},
 ],
 cta:{bg:'cream',title:'対戦表づくり、ゼロに。',sub:'無料・プロフィールのリンクから'},
};
const br=await chromium.launch();
const p=await br.newPage({viewport:{width:1080,height:1350},deviceScaleFactor:1});
await p.setContent(build(post),{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);
const els=await p.locator('.slide').all();
for(let i=0;i<els.length;i++){await els[i].screenshot({path:path.join(OUT,`single_${i+1}.png`)});}
await br.close();console.log('done',els.length,'slides');
