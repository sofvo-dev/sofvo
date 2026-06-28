// 1機能=1リール（共感フック型・ナレーション前提・アニメ多め）
// 使い方: REEL=score REEL_OUT=... FFMPEG=... PW_CHROMIUM=... node reel-single.mjs
import { chromium } from 'playwright';
import { execFileSync } from 'child_process';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const KEY=process.env.REEL||'score';
const SCRATCH=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out',KEY);
const FRAMES=path.join(SCRATCH,'frames');
fs.rmSync(SCRATCH,{recursive:true,force:true}); fs.mkdirSync(FRAMES,{recursive:true});
const FF=process.env.FFMPEG||path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/ffmpeg');
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440',RED='#E0524B';
const FPS=30;

// ---- 機能ごとの設定（スコア版） ----
const REELS={
 score:{
  img:'app-score.jpg',
  hookA:'まだ、紙で', hookB:'スコアつけてるの？', strike:'紙',
  painA:'集計ミスでもめたり', painB:'「今どっち勝ってる？」',
  chips:['リアルタイム反映','セット自動集計'],
  appCap:'入力した瞬間、全員の画面へ',
  benefitCap:'もう、紙もペンもいらない。',
  zoomY:41.3, // 画面内で注目する高さ(%)＝15-10スコアの位置（ピクセル実測: 画像35.6%→枠内41.3%）
  ctaTitle:'スコアも集計も、スマホで。',
 },
};
const R=REELS[KEY];

// ---- タイムライン（秒） ----
const beats=[
 {id:'hook',   dur:3.2, bg:'cream'},
 {id:'pain',   dur:3.2, bg:'navy'},
 {id:'app',    dur:9.0, bg:'cream'}, // フォン連続（イン→ズーム→戻し）
 {id:'cta',    dur:3.6, bg:'navy'},
];
let acc=0; for(const b of beats){b.start=acc; acc+=b.dur;} const TOTAL=acc; const NF=Math.round(TOTAL*FPS);

const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 html,body{width:1080px;height:1920px;background:${CREAM};font-family:'Noto';overflow:hidden}
 .scene{position:absolute;inset:0;will-change:opacity}
 .center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 80px}
 .dela{font-family:'Dela'}
 /* hook */
 .hookT{font-family:'Dela';font-size:92px;line-height:1.3;color:${NAVY}}
 .kami{position:relative;display:inline-block}
 .kami .sl{position:absolute;left:-4px;top:54%;height:12px;background:${RED};border-radius:6px;width:0}
 .hookSub{margin-top:40px;font-size:46px;font-weight:800;color:${NAVY};opacity:.85}
 /* pain */
 .painT{font-family:'Dela';font-size:74px;line-height:1.45;color:#fff}
 .xmark{display:inline-block;color:${RED};font-weight:900;margin-right:18px}
 /* app */
 .lbl{position:absolute;top:120px;left:0;right:0;text-align:center;z-index:4}
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:800;font-size:34px;padding:12px 32px;border-radius:999px}
 .cap{position:absolute;left:0;right:0;bottom:96px;text-align:center;font-family:'Dela';font-size:52px;color:${NAVY};z-index:4;padding:0 70px}
 .wm{position:absolute;top:50px;left:64px;font-weight:900;font-size:46px;z-index:5}
 .ph{position:absolute;left:50%;top:330px;transform:translateX(-50%);width:760px;height:1300px;border:15px solid ${DARK};border-radius:60px;overflow:hidden;box-shadow:0 30px 90px rgba(0,0,0,.35);background:#000;z-index:2}
 .ph img{width:100%;height:100%;object-fit:cover;object-position:center top;display:block;transform-origin:50% ${R.zoomY}%}
 .ring{position:absolute;left:50%;border:6px solid ${GOLD};border-radius:20px;width:480px;height:150px;transform:translate(-50%,-50%);z-index:3;opacity:0;box-shadow:0 0 0 5px rgba(196,169,98,.18)}
 .chip{position:absolute;background:#fff;color:${NAVY};font-weight:800;font-size:36px;padding:16px 28px;border-radius:18px;box-shadow:0 14px 30px rgba(0,0,0,.22);z-index:4;opacity:0;white-space:nowrap}
 .chip .gd{color:${GOLD}}
 /* cta */
 .ctaWm{font-weight:900;font-size:96px}
 .ctaT{font-family:'Dela';font-size:62px;color:#fff;margin-top:18px;line-height:1.3}
 .ctaBtn{margin-top:46px;background:${GOLD};color:${NAVY};font-weight:900;font-size:48px;padding:24px 60px;border-radius:999px;display:inline-block}
 .ctaSub{margin-top:34px;font-size:40px;font-weight:700;color:#fff;opacity:.85}
</style><body>
 <div class="scene" data-i="0" style="background:${CREAM}"><div class="center">
   <div class="hookT up">${R.hookA.replace(R.strike,`<span class="kami">${R.strike}<span class="sl"></span></span>`)}<br>${R.hookB}</div>
   <div class="hookSub up">…その手間、もう終わりにしませんか？🏐</div>
 </div></div>

 <div class="scene" data-i="1" style="background:${NAVY}"><div class="center">
   <div class="painT"><div class="pl up"><span class="xmark">✕</span>${R.painA}</div>
   <div class="pl up" style="margin-top:24px"><span class="xmark">✕</span>${R.painB}</div></div>
 </div></div>

 <div class="scene" data-i="2" style="background:${CREAM}">
   <div class="wm"><span style="color:${NAVY}">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="lbl up"><div class="pill">試合中</div></div>
   <div class="ph"><img src="data:image/jpeg;base64,${img64(R.img)}"></div>
   <div class="ring"></div>
   <div class="chip c0"><span class="gd">⚡</span> ${R.chips[0]}</div>
   <div class="chip c1"><span class="gd">✓</span> ${R.chips[1]}</div>
   <div class="cap" id="cap"></div>
 </div>

 <div class="scene" data-i="3" style="background:${NAVY}"><div class="center">
   <div class="ctaWm up"><span style="color:#fff">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="ctaT up">${R.ctaTitle}</div>
   <div class="ctaBtn up">無料ではじめる</div>
   <div class="ctaSub up">@sofvo.official ・ プロフィールのリンクから</div>
 </div></div>

 <script>
 const B=${JSON.stringify(beats.map(b=>({id:b.id,start:b.start,dur:b.dur})))};
 const APPCAP=${JSON.stringify(R.appCap)}, BENCAP=${JSON.stringify(R.benefitCap)};
 const easeOut=x=>1-Math.pow(1-Math.max(0,Math.min(1,x)),3);
 const easeIO=x=>{x=Math.max(0,Math.min(1,x));return x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2};
 const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
 const lerp=(a,b,t)=>a+(b-a)*cl(t);
 window.renderAt=(t)=>{
  const scenes=document.querySelectorAll('.scene');
  scenes.forEach((el,i)=>{
   const b=B[i]; const tl=t-b.start; const last=i===scenes.length-1;
   const vis=(t>=b.start-0.05 && t<=b.start+b.dur+0.45)||(last&&t>=b.start);
   el.style.display=vis?'block':'none';
   el.style.opacity= tl<0?0: cl(tl/0.28);
   // 共通：.up はスタッガでスライド＋フェード
   el.querySelectorAll('.up,.pl').forEach((u,k)=>{
    const lt=tl-0.08*k; const e=easeOut(lt/0.5);
    u.style.opacity=cl(lt/0.4);
    u.style.transform='translateY('+((1-e)*60).toFixed(2)+'px)';
   });
   if(b.id==='hook'){
    const sl=el.querySelector('.kami .sl');
    if(sl){ const w=easeIO((tl-1.5)/0.6); sl.style.width=(w*100).toFixed(1)+'%'; }
   }
   if(b.id==='app'){
    const img=el.querySelector('.ph img');
    const ph=el.querySelector('.ph');
    // フォン：スライドイン＋オーバーシュート
    const inE=easeOut(tl/0.7); const dy=(1-inE)*120;
    ph.style.transform='translateX(-50%) translateY('+dy.toFixed(2)+'px)';
    // ズーム：1.2s→2.4s で 1.0→1.45、5.6s→6.6s で戻す
    let z=1.0;
    if(tl>=1.2&&tl<5.6) z=lerp(1.0,1.45,easeIO((tl-1.2)/1.1));
    else if(tl>=5.6) z=lerp(1.45,1.0,easeIO((tl-5.6)/1.0));
    img.style.transform='scale('+z.toFixed(3)+')';
    // リング（スコアを囲む）＋パルス
    const ring=el.querySelector('.ring');
    const phTop=330, phH=1300; const cy=phTop+15+ (phH-30)*${R.zoomY}/100;
    const ringOp= tl>=1.4&&tl<5.6? cl((tl-1.4)/0.4)*(1-cl((tl-5.2)/0.4)) :0;
    const pulse=1+0.05*Math.sin(tl*7);
    ring.style.top=cy+'px'; ring.style.opacity=ringOp.toFixed(2);
    ring.style.transform='translate(-50%,-50%) scale('+(z*pulse).toFixed(3)+')'; // 数字と同じ倍率で拡大＝常に枠が一致
    // チップ：ポップイン（スコアの左右）
    const c0=el.querySelector('.c0'), c1=el.querySelector('.c1');
    const popp=(s)=>{const p=cl((tl-s)/0.32);return {o:p, sc:lerp(0.7,1,easeOut(p))};};
    let a=popp(1.7); c0.style.opacity=(a.o*(1-cl((tl-5.4)/0.4))).toFixed(2);
    c0.style.left='600px'; c0.style.top='678px'; c0.style.transform='scale('+a.sc.toFixed(3)+')';
    let bb=popp(2.2); c1.style.opacity=(bb.o*(1-cl((tl-5.4)/0.4))).toFixed(2);
    c1.style.left='60px'; c1.style.top='1130px'; c1.style.transform='scale('+bb.sc.toFixed(3)+')';
    // キャプション差し替え（前半=appCap、後半=benefitCap）
    const cap=el.querySelector('#cap');
    if(tl<5.4){cap.textContent=APPCAP; cap.style.opacity=cl((tl-0.5)/0.4).toFixed(2);}
    else{cap.textContent=BENCAP; cap.style.opacity=cl((tl-6.0)/0.4).toFixed(2);}
   }
  });
 };
 </script>
</body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'});
await p.evaluate(()=>document.fonts.ready);
console.log('rendering',NF,'frames /',TOTAL.toFixed(2),'s ·',KEY);
for(let i=0;i<NF;i++){await p.evaluate(t=>window.renderAt(t),i/FPS);await p.screenshot({path:path.join(FRAMES,`f${String(i).padStart(4,'0')}.png`)});}
await br.close();
const mp4=path.join(SCRATCH,`sofvo-reel-${KEY}.mp4`);
execFileSync(FF,['-y','-framerate',String(FPS),'-i',path.join(FRAMES,'f%04d.png'),'-c:v','libx264','-pix_fmt','yuv420p','-r',String(FPS),'-movflags','+faststart',mp4],{stdio:'inherit'});
console.log('done ->',mp4);
