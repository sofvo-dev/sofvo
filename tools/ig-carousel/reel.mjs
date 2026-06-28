import { chromium } from 'playwright';
import { execFileSync } from 'child_process';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const SCRATCH=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out');
const FRAMES=path.join(SCRATCH,'frames');
fs.rmSync(SCRATCH,{recursive:true,force:true}); fs.mkdirSync(FRAMES,{recursive:true});
const FF=process.env.FFMPEG||require_ffmpeg();
function require_ffmpeg(){try{return JSON.parse(fs.readFileSync(path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/package.json')))&&path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/ffmpeg')}catch(e){return 'ffmpeg'}}
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440';
const FPS=30;

// シーン定義（秒）。feat=実機紹介。
const feats=[
 {pill:'大会運営',ttl:'対戦表',img:'app-bracket.jpg',bg:'navy'},
 {pill:'試合中',  ttl:'スコア',img:'app-score.jpg',  bg:'cream'},
 {pill:'結果発表',ttl:'順位表',img:'app-ranking.jpg',bg:'navy'},
 {pill:'受付',    ttl:'QR受付',img:'app-checkin.jpg',bg:'cream'},
 {pill:'お金の管理',ttl:'収支管理',img:'app-finance.jpg',bg:'navy'},
 {pill:'さがす',  ttl:'大会をさがす',img:'app-search-tournaments.jpg',bg:'cream'},
];
const FEAT_DUR=1.55, INTRO_DUR=2.4, CTA_DUR=3.0;
let t=0; const scenes=[];
scenes.push({type:'intro',start:0,end:INTRO_DUR}); t=INTRO_DUR;
for(const f of feats){scenes.push({type:'feat',...f,start:t,end:t+FEAT_DUR}); t+=FEAT_DUR;}
scenes.push({type:'cta',start:t,end:t+CTA_DUR}); t+=CTA_DUR;
const TOTAL=t; const NFRAMES=Math.round(TOTAL*FPS);

const wmDark=`<span style="color:${NAVY}">Sof</span><span style="color:${GOLD}">vo</span>`;
const wmLight=`<span style="color:#fff">Sof</span><span style="color:${GOLD}">vo</span>`;
function sceneHTML(s,i){
 if(s.type==='intro') return `<div class="scene" data-i="${i}" style="background:${CREAM}">
   <div class="center">
     <div class="wm big up">${wmDark}</div>
     <div class="hook up" style="color:${NAVY}">ソフトバレーの大会、<br>ぜんぶこれ1つ。</div>
     <div class="hooksub up" style="color:${NAVY}">運営も、参加も、仲間さがしも。🏐</div>
   </div></div>`;
 if(s.type==='cta') return `<div class="scene" data-i="${i}" style="background:${NAVY}">
   <div class="center">
     <div class="ctaT up">無料で、はじめよう。</div>
     <div class="ctaHandle up">@sofvo.official</div>
     <div class="ctaLink up">プロフィールのリンクから</div>
     <div class="ctaTag up">ソフトバレーを、もっと楽しく。</div>
   </div></div>`;
 const dark=s.bg==='navy';
 return `<div class="scene" data-i="${i}" style="background:${dark?NAVY:CREAM}">
   <div class="lbl up">
     <div class="pill">${s.pill}</div>
     <div class="ttl" style="color:${dark?'#fff':NAVY}">${s.ttl}</div>
   </div>
   <div class="wm small" style="position:absolute;top:54px;left:70px">${dark?wmLight:wmDark}</div>
   <div class="ph up"><img style="object-position:center top" src="data:image/jpeg;base64,${img64(s.img)}"></div>
 </div>`;
}
const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 html,body{width:1080px;height:1920px;background:${CREAM};font-family:'Noto';overflow:hidden}
 .scene{position:absolute;inset:0;will-change:opacity}
 .center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 90px}
 .wm{font-weight:900}.wm.big{font-size:84px;margin-bottom:40px}.wm.small{font-size:46px;font-weight:900}
 .hook{font-family:'Dela';font-size:84px;line-height:1.28}
 .hooksub{margin-top:34px;font-size:40px;font-weight:700;opacity:.8}
 .lbl{position:absolute;top:150px;left:0;right:0;text-align:center;z-index:3}
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:700;font-size:34px;padding:12px 32px;border-radius:999px;margin-bottom:22px}
 .ttl{font-family:'Dela';font-size:78px;line-height:1.1}
 .ph{position:absolute;left:50%;top:430px;transform:translateX(-50%);width:760px;height:1300px;border:15px solid ${DARK};border-radius:60px;overflow:hidden;box-shadow:0 30px 80px rgba(0,0,0,.32);background:#000}
 .ph img{width:100%;height:100%;object-fit:cover;display:block}
 .ctaT{font-family:'Dela';font-size:92px;line-height:1.25;color:#fff}
 .ctaHandle{margin-top:48px;font-size:54px;font-weight:900;color:${GOLD}}
 .ctaLink{margin-top:14px;font-size:40px;font-weight:700;color:#fff;opacity:.85}
 .ctaTag{margin-top:60px;font-size:34px;font-weight:700;color:#fff;opacity:.7}
</style><body>
 ${scenes.map(sceneHTML).join('')}
 <script>
 const SCENES=${JSON.stringify(scenes.map(s=>({start:s.start,end:s.end})))};
 const easeOut=x=>1-Math.pow(1-x,3);
 const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
 window.renderAt=(t)=>{
  const els=document.querySelectorAll('.scene');
  els.forEach((el,i)=>{
   const s=SCENES[i]; const tl=t-s.start;
   // フェードイン（前シーンとクロスフェード）。最後のCTAは出っぱなし。
   const op = tl<0 ? 0 : cl(tl/0.25);
   el.style.opacity=op;
   el.style.display = (t>=s.start-0.05 && t<=s.end+0.4) || (i===els.length-1 && t>=s.start) ? 'block':'none';
   const p = cl(tl/0.55); const ease=easeOut(p);
   el.querySelectorAll('.up').forEach((u,k)=>{
    const dy=(1-ease)*70; const uop=cl((tl-0.06*k)/0.4);
    u.style.transform='translateY('+dy.toFixed(2)+'px)';
    u.style.opacity=uop;
   });
   // .ph は中央寄せのtranslateXを保持
   const ph=el.querySelector('.ph');
   if(ph){const dy=(1-ease)*70; ph.style.transform='translateX(-50%) translateY('+dy.toFixed(2)+'px)';}
  });
 };
 </script>
</body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'});
await p.evaluate(()=>document.fonts.ready);
console.log('rendering',NFRAMES,'frames /',TOTAL.toFixed(2),'s');
for(let i=0;i<NFRAMES;i++){
 const tt=i/FPS;
 await p.evaluate(t=>window.renderAt(t),tt);
 await p.screenshot({path:path.join(FRAMES,`f${String(i).padStart(4,'0')}.png`)});
}
await br.close();
const mp4=path.join(SCRATCH,'sofvo-reel-15s.mp4');
execFileSync(FF,['-y','-framerate',String(FPS),'-i',path.join(FRAMES,'f%04d.png'),
 '-c:v','libx264','-pix_fmt','yuv420p','-r',String(FPS),'-movflags','+faststart',mp4],{stdio:'inherit'});
console.log('done ->',mp4);
