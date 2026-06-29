// 順位表リール（結果発表ドラマ型）：電卓→混乱→アプリで1位ジャジャーン＋紙吹雪
// 使い方: REEL_OUT=... AUDIO=... FFMPEG=... PW_CHROMIUM=... node reel-ranking.mjs
import { chromium } from 'playwright';
import { execFileSync } from 'child_process';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const SCRATCH=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out','ranking');
const FRAMES=path.join(SCRATCH,'frames'); fs.rmSync(SCRATCH,{recursive:true,force:true}); fs.mkdirSync(FRAMES,{recursive:true});
const FF=process.env.FFMPEG||path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/ffmpeg');
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440',RED='#E0524B';
const FPS=30;
const D={hook:+(process.env.DUR_HOOK||3.0), pain:+(process.env.DUR_PAIN||3.2), reveal:+(process.env.DUR_REVEAL||9.2), cta:+(process.env.DUR_CTA||3.8)};
const beats=[{id:'hook',dur:D.hook},{id:'pain',dur:D.pain},{id:'reveal',dur:D.reveal},{id:'cta',dur:D.cta}];
let acc=0; for(const b of beats){b.start=acc; acc+=b.dur;} const TOTAL=acc; const NF=Math.round(TOTAL*FPS);
const ZY=35.8; // 1位の枠内%（実測: 画像31.7%→枠内35.8%）

const COL=[GOLD,NAVY,RED,'#fff','#7FB3E0','#E8C24B'];
const confetti=Array.from({length:34},(_,i)=>{
 const x=30+(i*131%1000); const col=COL[i%COL.length]; const rot=(i%2?1:-1)*(160+i*19); const d=(i%12)*0.05; const sp=0.85+(i%5)*0.10;
 return `<div class="conf" data-x="${x}" data-rot="${rot}" data-d="${d.toFixed(2)}" data-sp="${sp.toFixed(2)}" style="background:${col}"></div>`;
}).join('');

const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 html,body{width:1080px;height:1920px;background:${CREAM};font-family:'Noto';overflow:hidden}
 .scene{position:absolute;inset:0}.bg{position:absolute;inset:0}
 .center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 80px}
 .hookT{font-family:'Dela';font-size:88px;line-height:1.3;color:${NAVY}}
 .te{position:relative;display:inline-block}.te .sl{position:absolute;left:-6px;top:56%;height:12px;background:${RED};border-radius:6px;width:0}
 .hookSub{margin-top:38px;font-size:44px;font-weight:800;color:${NAVY};opacity:.85}
 .painT{font-family:'Dela';font-size:72px;line-height:1.5;color:#fff}
 .q{display:inline-block;color:${GOLD}}
 .wm{position:absolute;top:50px;left:64px;font-weight:900;font-size:46px;z-index:7}
 .badge{position:absolute;top:104px;left:0;right:0;text-align:center;z-index:7}
 .bChip{display:inline-block;background:${GOLD};color:${NAVY};font-family:'Dela';font-size:54px;padding:14px 44px;border-radius:999px;box-shadow:0 16px 40px rgba(0,0,0,.2)}
 .ph{position:absolute;left:50%;top:300px;transform:translateX(-50%);width:740px;height:1300px;border:15px solid ${DARK};border-radius:60px;overflow:hidden;box-shadow:0 30px 90px rgba(0,0,0,.32);background:#000;z-index:2}
 .ph img{width:100%;height:100%;object-fit:cover;object-position:center top;display:block;transform-origin:50% ${ZY}%}
 .ring{position:absolute;left:50%;border:8px solid ${GOLD};border-radius:22px;width:660px;height:150px;transform:translate(-50%,-50%);z-index:3;opacity:0;box-shadow:0 0 0 6px rgba(196,169,98,.2)}
 .trophy{position:absolute;left:50%;transform:translateX(-50%);font-size:150px;z-index:6;opacity:0}
 .chip{position:absolute;background:#fff;color:${NAVY};font-weight:800;font-size:36px;padding:16px 28px;border-radius:18px;box-shadow:0 14px 30px rgba(0,0,0,.22);z-index:5;opacity:0;white-space:nowrap}
 .chip .gd{color:${GOLD}}
 .conf{position:absolute;top:-60px;width:22px;height:30px;border-radius:5px;z-index:6;opacity:0}
 .ctaWm{font-weight:900;font-size:96px}.ctaT{font-family:'Dela';font-size:64px;color:#fff;margin-top:18px;line-height:1.3}
 .ctaBtn{margin-top:46px;background:${GOLD};color:${NAVY};font-weight:900;font-size:48px;padding:24px 60px;border-radius:999px;display:inline-block}
 .ctaSub{margin-top:34px;font-size:40px;font-weight:700;color:#fff;opacity:.85}
</style><body>
 <div class="scene" data-i="0"><div class="bg" style="background:${CREAM}"></div><div class="center">
   <div class="hookT up">順位の計算、<br>まだ<span class="te">電卓<span class="sl"></span></span>で…？</div>
   <div class="hookSub up">結果発表、待たせていませんか？⏳</div></div></div>

 <div class="scene" data-i="1"><div class="bg" style="background:${NAVY}"></div><div class="center">
   <div class="painT"><div class="up">セット数？<span class="q">得失点？</span></div>
   <div class="up" style="margin-top:18px">同率は…どっちが上？🤔</div>
   <div class="up" style="margin-top:18px;opacity:.85">発表まで、まだかかる…</div></div></div></div>

 <div class="scene" data-i="2"><div class="bg" style="background:${CREAM}"></div>
   <div class="wm"><span style="color:${NAVY}">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="badge"><div class="bChip" id="bdg">🎉 結果発表！</div></div>
   <div class="ph"><img src="data:image/jpeg;base64,${img64('app-ranking.jpg')}"></div>
   <div class="ring"></div>
   <div class="trophy">🏆</div>
   ${confetti}
   <div class="chip c0"><span class="gd">⚡</span> 順位は自動で確定</div>
   <div class="chip c1"><span class="gd">✓</span> 同率もルールで判定</div></div>

 <div class="scene" data-i="3"><div class="bg" style="background:${NAVY}"></div><div class="center">
   <div class="ctaWm up"><span style="color:#fff">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="ctaT up">結果発表、待たせない。</div>
   <div class="ctaBtn up">無料ではじめる</div>
   <div class="ctaSub up">@sofvo.official ・ プロフィールのリンクから</div></div></div>

 <script>
 const B=${JSON.stringify(beats.map(b=>({id:b.id,start:b.start,dur:b.dur})))};
 const RD=${D.reveal};
 const eO=x=>1-Math.pow(1-Math.max(0,Math.min(1,x)),3);
 const eIO=x=>{x=Math.max(0,Math.min(1,x));return x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2};
 const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)); const lerp=(a,b,t)=>a+(b-a)*cl(t);
 window.renderAt=(t)=>{
  document.querySelectorAll('.scene').forEach((el,i)=>{
   const b=B[i]; const tl=t-b.start; const last=i===B.length-1;
   el.style.display=((t>=b.start-0.05&&t<=b.start+b.dur+0.45)||(last&&t>=b.start))?'block':'none';
   el.style.opacity= tl<0?0: cl(tl/0.3);
   el.querySelectorAll('.up').forEach((u,k)=>{const lt=tl-0.08*k;const e=eO(lt/0.5);u.style.opacity=cl(lt/0.4);u.style.transform='translateY('+((1-e)*60).toFixed(2)+'px)';});
   if(b.id==='hook'){const sl=el.querySelector('.te .sl'); if(sl) sl.style.width=(eIO((tl-1.4)/0.6)*100).toFixed(1)+'%';}
   if(b.id==='reveal'){
    const ph=el.querySelector('.ph'); const inE=eO(tl/0.7); ph.style.transform='translateX(-50%) translateY('+((1-inE)*130).toFixed(1)+'px)';
    // ドラムロール後、1位にズーム
    let z=1.0; if(tl>=1.2) z=lerp(1.0,1.32,eIO((tl-1.2)/0.9));
    const img=el.querySelector('.ph img'); img.style.transform='scale('+z.toFixed(3)+')';
    const ring=el.querySelector('.ring'); const cy=300+15+(1300-30)*${ZY}/100;
    const rop=cl((tl-1.5)/0.35)*(1-cl((tl-(RD-0.6))/0.4)); const pul=1+0.06*Math.sin(tl*8);
    ring.style.top=cy+'px'; ring.style.opacity=rop.toFixed(2); ring.style.transform='translate(-50%,-50%) scale('+(z*pul).toFixed(3)+')';
    // トロフィー pop（1位の上）
    const tr=el.querySelector('.trophy'); const tp=cl((tl-1.7)/0.4); tr.style.top=(cy-z*150)+'px'; tr.style.opacity=(tp*(1-cl((tl-(RD-0.6))/0.4))).toFixed(2);
    tr.style.transform='translateX(-50%) scale('+(0.4+0.6*eO(tp)+0.05*Math.sin(tl*6)).toFixed(3)+')';
    // バッジ pop
    const bd=el.querySelector('#bdg'); const bp=cl((tl-0.5)/0.35); bd.style.transform='scale('+(1.25-0.25*eO(bp)).toFixed(3)+')'; bd.style.opacity=bp.toFixed(2);
    // 紙吹雪（1位確定の瞬間から）
    el.querySelectorAll('.conf').forEach(c=>{const x=+c.dataset.x,rot=+c.dataset.rot,d=+c.dataset.d,sp=+c.dataset.sp;
     const p=cl((tl-1.8-d)/(RD-2.0)); const y=-60+p*2120*sp; c.style.left=(x+Math.sin(p*6.28+x)*36)+'px'; c.style.top=y.toFixed(0)+'px';
     c.style.opacity=(p>0&&p<0.96?1:0).toFixed(2); c.style.transform='rotate('+(p*rot).toFixed(0)+'deg)';});
    // チップ
    const pop=(s)=>{const p=cl((tl-s)/0.32);return{o:p,sc:0.7+0.3*eO(p)};}; const off=1-cl((tl-(RD-0.5))/0.4);
    const a=pop(2.8),c0=el.querySelector('.c0'); c0.style.opacity=(a.o*off).toFixed(2); c0.style.left='560px'; c0.style.top='760px'; c0.style.transform='scale('+a.sc.toFixed(3)+')';
    const bb=pop(3.3),c1=el.querySelector('.c1'); c1.style.opacity=(bb.o*off).toFixed(2); c1.style.left='60px'; c1.style.top='1230px'; c1.style.transform='scale('+bb.sc.toFixed(3)+')';
   }
  });
 };
 </script></body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'}); await p.evaluate(()=>document.fonts.ready);
console.log('rendering',NF,'frames /',TOTAL.toFixed(2),'s · ranking(drama)');
for(let i=0;i<NF;i++){await p.evaluate(t=>window.renderAt(t),i/FPS);await p.screenshot({path:path.join(FRAMES,`f${String(i).padStart(4,'0')}.png`)});}
await br.close();
const mp4=path.join(SCRATCH,'sofvo-reel-ranking.mp4');
const args=['-y','-framerate',String(FPS),'-i',path.join(FRAMES,'f%04d.png')];
if(process.env.AUDIO) args.push('-i',process.env.AUDIO);
args.push('-c:v','libx264','-pix_fmt','yuv420p','-r',String(FPS),'-movflags','+faststart');
if(process.env.AUDIO) args.push('-c:a','aac','-b:a','192k','-shortest','-map','0:v:0','-map','1:a:0');
args.push(mp4); execFileSync(FF,args,{stdio:'inherit'}); console.log('done ->',mp4,'audio:',process.env.AUDIO?'yes':'no');
