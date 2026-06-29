// 収支リール（数字カウントアップ型）：どんぶり勘定→アプリで¥0→¥11,500が自動集計
// 使い方: REEL_OUT=... AUDIO=... FFMPEG=... PW_CHROMIUM=... node reel-finance.mjs
import { chromium } from 'playwright';
import { execFileSync } from 'child_process';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const SCRATCH=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out','finance');
const FRAMES=path.join(SCRATCH,'frames'); fs.rmSync(SCRATCH,{recursive:true,force:true}); fs.mkdirSync(FRAMES,{recursive:true});
const FF=process.env.FFMPEG||path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/ffmpeg');
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440',RED='#E0524B',GREEN='#2e9e5b';
const FPS=30;
const D={hook:+(process.env.DUR_HOOK||3.0), pain:+(process.env.DUR_PAIN||3.2), after:+(process.env.DUR_AFTER||9.0), cta:+(process.env.DUR_CTA||3.8)};
const beats=[{id:'hook',dur:D.hook},{id:'pain',dur:D.pain},{id:'after',dur:D.after},{id:'cta',dur:D.cta}];
let acc=0; for(const b of beats){b.start=acc; acc+=b.dur;} const TOTAL=acc; const NF=Math.round(TOTAL*FPS);
const TARGET=11500;

const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 html,body{width:1080px;height:1920px;background:${CREAM};font-family:'Noto';overflow:hidden}
 .scene{position:absolute;inset:0}.bg{position:absolute;inset:0}
 .center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 80px}
 .hookT{font-family:'Dela';font-size:80px;line-height:1.32;color:${NAVY}}
 .te{position:relative;display:inline-block}.te .sl{position:absolute;left:-6px;top:56%;height:12px;background:${RED};border-radius:6px;width:0}
 .hookSub{margin-top:38px;font-size:44px;font-weight:800;color:${NAVY};opacity:.85}
 .painT{font-family:'Dela';font-size:64px;line-height:1.5;color:#fff}
 .q{color:${GOLD}}
 .wm{position:absolute;top:50px;left:64px;font-weight:900;font-size:46px;z-index:7}
 .counter{position:absolute;top:120px;left:0;right:0;text-align:center;z-index:7}
 .cLab{font-size:36px;font-weight:800;color:${NAVY};opacity:.8;margin-bottom:6px}
 .cNum{font-family:'Dela';font-size:118px;color:${GREEN};line-height:1;text-shadow:0 8px 24px rgba(46,158,91,.25)}
 .ph{position:absolute;left:50%;top:380px;transform:translateX(-50%);width:740px;height:1200px;border:15px solid ${DARK};border-radius:60px;overflow:hidden;box-shadow:0 30px 90px rgba(0,0,0,.32);background:#000;z-index:2}
 .ph img{width:100%;height:100%;object-fit:cover;object-position:center top;display:block}
 .coin{position:absolute;font-size:64px;z-index:6;opacity:0}
 .chip{position:absolute;background:#fff;color:${NAVY};font-weight:800;font-size:36px;padding:16px 28px;border-radius:18px;box-shadow:0 14px 30px rgba(0,0,0,.22);z-index:5;opacity:0;white-space:nowrap}
 .chip .gd{color:${GOLD}}
 .ctaWm{font-weight:900;font-size:96px}.ctaT{font-family:'Dela';font-size:64px;color:#fff;margin-top:18px;line-height:1.3}
 .ctaBtn{margin-top:46px;background:${GOLD};color:${NAVY};font-weight:900;font-size:48px;padding:24px 60px;border-radius:999px;display:inline-block}
 .ctaSub{margin-top:34px;font-size:40px;font-weight:700;color:#fff;opacity:.85}
</style><body>
 <div class="scene" data-i="0"><div class="bg" style="background:${CREAM}"></div><div class="center">
   <div class="hookT up">大会の収支、まだ<br><span class="te">どんぶり勘定<span class="sl"></span></span>…？</div>
   <div class="hookSub up">ぜんぶ、自動で見える化💰</div></div></div>

 <div class="scene" data-i="1"><div class="bg" style="background:${NAVY}"></div><div class="center">
   <div class="painT"><div class="up">参加費、いくら集まった？</div>
   <div class="up" style="margin-top:18px">経費は？ <span class="q">黒字…？赤字…？</span>🤔</div></div></div></div>

 <div class="scene" data-i="2"><div class="bg" style="background:${CREAM}"></div>
   <div class="wm"><span style="color:${NAVY}">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="counter"><div class="cLab">大会の収支</div><div class="cNum" id="num">¥0</div></div>
   <div class="ph"><img src="data:image/jpeg;base64,${img64('app-finance.jpg')}"></div>
   <div class="coin c0">🪙</div><div class="coin c1">💰</div><div class="coin c2">🪙</div><div class="coin c3">✨</div>
   <div class="chip c0c"><span class="gd">⚡</span> 参加費も経費も自動集計</div>
   <div class="chip c1c"><span class="gd">✓</span> 損益がひと目で</div></div>

 <div class="scene" data-i="3"><div class="bg" style="background:${NAVY}"></div><div class="center">
   <div class="ctaWm up"><span style="color:#fff">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="ctaT up">大会の収支、まるっと。</div>
   <div class="ctaBtn up">無料ではじめる</div>
   <div class="ctaSub up">@sofvo.official ・ プロフィールのリンクから</div></div></div>

 <script>
 const B=${JSON.stringify(beats.map(b=>({id:b.id,start:b.start,dur:b.dur})))};
 const AD=${D.after}, TG=${TARGET};
 const eO=x=>1-Math.pow(1-Math.max(0,Math.min(1,x)),3);
 const eIO=x=>{x=Math.max(0,Math.min(1,x));return x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2};
 const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
 const COINP=[[560,470],[60,560],[600,640],[80,440]];
 window.renderAt=(t)=>{
  document.querySelectorAll('.scene').forEach((el,i)=>{
   const b=B[i]; const tl=t-b.start; const last=i===B.length-1;
   el.style.display=((t>=b.start-0.05&&t<=b.start+b.dur+0.45)||(last&&t>=b.start))?'block':'none';
   el.style.opacity= tl<0?0: cl(tl/0.3);
   el.querySelectorAll('.up').forEach((u,k)=>{const lt=tl-0.08*k;const e=eO(lt/0.5);u.style.opacity=cl(lt/0.4);u.style.transform='translateY('+((1-e)*60).toFixed(2)+'px)';});
   if(b.id==='hook'){const sl=el.querySelector('.te .sl'); if(sl) sl.style.width=(eIO((tl-1.4)/0.6)*100).toFixed(1)+'%';}
   if(b.id==='after'){
    const ph=el.querySelector('.ph'); const inE=eO(tl/0.7); ph.style.transform='translateX(-50%) translateY('+((1-inE)*130).toFixed(1)+'px)';
    // 数字カウントアップ ¥0→¥11,500（0.8s→2.6s）＋ 到達時に弾む
    const cp=eIO((tl-0.8)/1.8); const val=Math.round(TG*cp); const num=el.querySelector('#num');
    num.textContent='¥'+val.toLocaleString('en-US');
    const settle=cl((tl-2.6)/0.25); const pop=tl<2.6?1:1+0.12*Math.sin((tl-2.6)*16)*(1-settle);
    num.style.transform='scale('+pop.toFixed(3)+')';
    // コイン pop（カウント中に飛び出す）
    el.querySelectorAll('.coin').forEach((c,k)=>{const p=cl((tl-1.0-k*0.18)/0.4); const off=1-cl((tl-(AD-0.6))/0.4);
     c.style.left=COINP[k][0]+'px'; c.style.top=(COINP[k][1]-p*30)+'px'; c.style.opacity=(p*off*0.95).toFixed(2);
     c.style.transform='scale('+(0.4+0.6*eO(p))+') rotate('+(p*(k%2?30:-30))+'deg)';});
    // チップ
    const popc=(s)=>{const p=cl((tl-s)/0.32);return{o:p,sc:0.7+0.3*eO(p)};}; const off=1-cl((tl-(AD-0.5))/0.4);
    const a=popc(3.0),c0=el.querySelector('.c0c'); c0.style.opacity=(a.o*off).toFixed(2); c0.style.left='470px'; c0.style.top='820px'; c0.style.transform='scale('+a.sc.toFixed(3)+')';
    const bb=popc(3.5),c1=el.querySelector('.c1c'); c1.style.opacity=(bb.o*off).toFixed(2); c1.style.left='70px'; c1.style.top='1180px'; c1.style.transform='scale('+bb.sc.toFixed(3)+')';
   }
  });
 };
 </script></body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'}); await p.evaluate(()=>document.fonts.ready);
console.log('rendering',NF,'frames /',TOTAL.toFixed(2),'s · finance(countup)');
for(let i=0;i<NF;i++){await p.evaluate(t=>window.renderAt(t),i/FPS);await p.screenshot({path:path.join(FRAMES,`f${String(i).padStart(4,'0')}.png`)});}
await br.close();
const mp4=path.join(SCRATCH,'sofvo-reel-finance.mp4');
const args=['-y','-framerate',String(FPS),'-i',path.join(FRAMES,'f%04d.png')];
if(process.env.AUDIO) args.push('-i',process.env.AUDIO);
args.push('-c:v','libx264','-pix_fmt','yuv420p','-r',String(FPS),'-movflags','+faststart');
if(process.env.AUDIO) args.push('-c:a','aac','-b:a','192k','-shortest','-map','0:v:0','-map','1:a:0');
args.push(mp4); execFileSync(FF,args,{stdio:'inherit'}); console.log('done ->',mp4,'audio:',process.env.AUDIO?'yes':'no');
