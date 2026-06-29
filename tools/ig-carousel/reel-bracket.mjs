// 対戦表リール（ビフォーアフター型）：手書きのぐちゃぐちゃ → アプリの自動対戦表 ＋「30分→10秒」
// 使い方: REEL_OUT=... AUDIO=... FFMPEG=... PW_CHROMIUM=... node reel-bracket.mjs
import { chromium } from 'playwright';
import { execFileSync } from 'child_process';
import fs from 'fs'; import path from 'path';
const ROOT=path.resolve(import.meta.dirname,'../..');
const F=path.join(import.meta.dirname,'fonts');
const SCRATCH=process.env.REEL_OUT||path.join(import.meta.dirname,'reel-out','bracket');
const FRAMES=path.join(SCRATCH,'frames');
fs.rmSync(SCRATCH,{recursive:true,force:true}); fs.mkdirSync(FRAMES,{recursive:true});
const FF=process.env.FFMPEG||path.join(import.meta.dirname,'node_modules/@ffmpeg-installer/linux-x64/ffmpeg');
const b64=f=>fs.readFileSync(path.join(F,f)).toString('base64');
const dela=b64('DelaGothicOne-Regular.ttf'), noto=b64('NotoSansJP.ttf');
const img64=n=>fs.readFileSync(path.join(ROOT,'website/images',n)).toString('base64');
const NAVY='#1B3A5C',CREAM='#F7F5EF',GOLD='#C4A962',DARK='#0F2440',RED='#E0524B',INK='#27406b';
const FPS=30;

const D={hook:+(process.env.DUR_HOOK||3.0), before:+(process.env.DUR_BEFORE||5.6), after:+(process.env.DUR_AFTER||6.6), cta:+(process.env.DUR_CTA||3.8)};
const beats=[{id:'hook',dur:D.hook},{id:'before',dur:D.before},{id:'after',dur:D.after},{id:'cta',dur:D.cta}];
let acc=0; for(const b of beats){b.start=acc; acc+=b.dur;} const TOTAL=acc; const NF=Math.round(TOTAL*FPS);

// 手書きメモ（ぐちゃぐちゃの組み合わせ表）
const line=(y,rot,html)=>`<div class="hl" style="top:${y}px;transform:rotate(${rot}deg)">${html}</div>`;
const memo=`
 <div class="paper">
  <div class="ph2">予選リーグ<span class="ul"></span></div>
  ${line(150,-0.6,`第1試合　Aチーム　<span class="vs2">vs</span>　Bチーム`)}
  ${line(258,0.5,`第2試合　Cチーム　<span class="vs2">vs</span>　<span class="ng">Dチーム</span><span class="arw">→Eチーム</span>`)}
  ${line(372,-0.4,`第3試合　<span class="ng">Aチーム</span>　<span class="vs2">vs</span>　Cチーム`)}
  ${line(486,0.7,`第4試合　Bチーム　<span class="vs2">vs</span>　？？？`)}
  ${line(600,-0.5,`第5試合　…コート足りる？`)}
  <div class="scrib">また組み直し…😩</div>
  <div class="stamp">⏱ もう30分…</div>
  <div class="cup">☕</div><div class="pen">✏️</div>
 </div>`;

const html=`<!doctype html><meta charset=utf8><style>
 @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela})}
 @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto});font-weight:100 900}
 *{margin:0;box-sizing:border-box}
 html,body{width:1080px;height:1920px;background:${CREAM};font-family:'Noto';overflow:hidden}
 .scene{position:absolute;inset:0;will-change:opacity}
 .center{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 80px}
 /* hook */
 .hookT{font-family:'Dela';font-size:90px;line-height:1.28;color:${NAVY}}
 .te{position:relative;display:inline-block}
 .te .sl{position:absolute;left:-6px;top:56%;height:12px;background:${RED};border-radius:6px;width:0}
 .hookSub{margin-top:40px;font-size:44px;font-weight:800;color:${NAVY};opacity:.85}
 /* before: 手書きメモ */
 .beforeBg{position:absolute;inset:0;background:${NAVY}}
 .blabel{position:absolute;top:120px;left:0;right:0;text-align:center;color:#fff;font-family:'Dela';font-size:54px;z-index:5}
 .paper{position:absolute;left:90px;right:90px;top:300px;height:1320px;background:#FBFAF4;border-radius:18px;
   box-shadow:0 30px 70px rgba(0,0,0,.4);transform:rotate(-1.2deg);overflow:hidden;
   background-image:repeating-linear-gradient(${'#FBFAF4'} 0 56px, #e7e3d6 56px 58px);padding:60px 70px}
 .ph2{font-family:'Dela';font-size:50px;color:${INK};position:relative;display:inline-block;margin-bottom:20px}
 .ph2 .ul{position:absolute;left:-6px;bottom:-12px;width:104%;height:8px;background:${INK};border-radius:6px;transform:rotate(-1deg)}
 .hl{position:absolute;left:70px;right:70px;font-size:46px;font-weight:700;color:${INK}}
 .vs2{color:${RED};font-weight:900;margin:0 6px}
 .ng{color:${INK};opacity:.9;position:relative}
 .ng::after{content:'';position:absolute;left:-4px;top:52%;width:108%;height:7px;background:${RED};border-radius:5px;transform:rotate(-3deg)}
 .arw{color:${RED};font-weight:900;margin-left:14px;transform:rotate(-3deg);display:inline-block}
 .scrib{position:absolute;left:120px;top:760px;color:${RED};font-family:'Dela';font-size:64px;transform:rotate(-7deg);opacity:0}
 .scrib::before{content:'';position:absolute;left:-20px;top:60%;width:118%;height:10px;background:${RED};opacity:.5;transform:rotate(-4deg)}
 .stamp{position:absolute;right:60px;top:60px;color:${RED};font-weight:900;font-size:44px;border:6px solid ${RED};border-radius:16px;padding:8px 20px;transform:rotate(6deg);opacity:.9}
 .cup{position:absolute;right:90px;bottom:80px;font-size:90px;transform:rotate(8deg)}
 .pen{position:absolute;left:60px;bottom:70px;font-size:84px;transform:rotate(-18deg)}
 /* after: アプリ＋カウンタ */
 .afterBg{position:absolute;inset:0;background:${CREAM}}
 .badge{position:absolute;top:96px;left:0;right:0;text-align:center;z-index:6}
 .bChip{display:inline-flex;align-items:center;gap:18px;background:#fff;border-radius:999px;padding:16px 34px;box-shadow:0 14px 34px rgba(0,0,0,.18);font-weight:900}
 .bOld{font-size:46px;color:${NAVY};position:relative}
 .bOld .x{position:absolute;left:-4px;top:54%;height:8px;background:${RED};border-radius:5px;width:0}
 .bArr{font-size:40px;color:${GOLD}}
 .bNew{font-size:46px;color:${GOLD};font-family:'Dela'}
 .wm{position:absolute;top:50px;left:64px;font-weight:900;font-size:46px;z-index:7}
 .ph{position:absolute;left:50%;top:300px;transform:translateX(-50%);width:740px;height:1300px;border:15px solid ${DARK};border-radius:60px;overflow:hidden;box-shadow:0 30px 90px rgba(0,0,0,.32);background:#000;z-index:2}
 .ph img{width:100%;height:100%;object-fit:cover;object-position:center top;display:block}
 .sweep{position:absolute;left:0;right:0;height:150px;background:linear-gradient(${'rgba(196,169,98,0)'},rgba(196,169,98,.45),rgba(196,169,98,0));z-index:3;opacity:0}
 .chip{position:absolute;background:#fff;color:${NAVY};font-weight:800;font-size:36px;padding:16px 28px;border-radius:18px;box-shadow:0 14px 30px rgba(0,0,0,.22);z-index:5;opacity:0;white-space:nowrap}
 .chip .gd{color:${GOLD}}
 /* cta */
 .ctaBg{position:absolute;inset:0;background:${NAVY}}
 .ctaWm{font-weight:900;font-size:96px}
 .ctaT{font-family:'Dela';font-size:64px;color:#fff;margin-top:18px;line-height:1.3}
 .ctaBtn{margin-top:46px;background:${GOLD};color:${NAVY};font-weight:900;font-size:48px;padding:24px 60px;border-radius:999px;display:inline-block}
 .ctaSub{margin-top:34px;font-size:40px;font-weight:700;color:#fff;opacity:.85}
</style><body>
 <div class="scene" data-i="0"><div class="afterBg" style="background:${CREAM}"></div><div class="center">
   <div class="hookT up">対戦表づくり、<br>まだ<span class="te">手書き<span class="sl"></span></span>？</div>
   <div class="hookSub up">紙とペン、もう卒業しません？✍️</div>
 </div></div>

 <div class="scene" data-i="1"><div class="beforeBg"></div>
   <div class="blabel up">手書きだと、これ…😵‍💫</div>
   ${memo}
 </div>

 <div class="scene" data-i="2"><div class="afterBg"></div>
   <div class="wm"><span style="color:${NAVY}">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="badge"><div class="bChip"><span class="bOld">手書き 30分<span class="x"></span></span><span class="bArr">→</span><span class="bNew" id="bnew">わずか10秒</span></div></div>
   <div class="ph"><img src="data:image/jpeg;base64,${img64('app-bracket.jpg')}"><div class="sweep"></div></div>
   <div class="chip c0"><span class="gd">⚡</span> エントリーから自動生成</div>
   <div class="chip c1"><span class="gd">✓</span> 組み直しもワンタップ</div>
 </div>

 <div class="scene" data-i="3"><div class="ctaBg"></div><div class="center">
   <div class="ctaWm up"><span style="color:#fff">Sof</span><span style="color:${GOLD}">vo</span></div>
   <div class="ctaT up">対戦表づくり、ゼロに。</div>
   <div class="ctaBtn up">無料ではじめる</div>
   <div class="ctaSub up">@sofvo.official ・ プロフィールのリンクから</div>
 </div></div>

 <script>
 const B=${JSON.stringify(beats.map(b=>({id:b.id,start:b.start,dur:b.dur})))};
 const easeOut=x=>1-Math.pow(1-Math.max(0,Math.min(1,x)),3);
 const easeIO=x=>{x=Math.max(0,Math.min(1,x));return x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2};
 const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
 const AFTERd=${D.after};
 window.renderAt=(t)=>{
  document.querySelectorAll('.scene').forEach((el,i)=>{
   const b=B[i]; const tl=t-b.start; const last=i===B.length-1;
   el.style.display=((t>=b.start-0.05&&t<=b.start+b.dur+0.45)||(last&&t>=b.start))?'block':'none';
   el.style.opacity= tl<0?0: cl(tl/0.3);
   el.querySelectorAll('.up').forEach((u,k)=>{const lt=tl-0.08*k;const e=easeOut(lt/0.5);
     u.style.opacity=cl(lt/0.4); u.style.transform='translateY('+((1-e)*60).toFixed(2)+'px)';});
   if(b.id==='hook'){const sl=el.querySelector('.te .sl'); if(sl) sl.style.width=(easeIO((tl-1.4)/0.6)*100).toFixed(1)+'%';}
   if(b.id==='before'){
    // メモは少し遅れて各行が出る＋赤スクリブル＝書き直し
    el.querySelectorAll('.hl').forEach((h,k)=>{h.style.opacity=cl((tl-0.3-k*0.18)/0.3);});
    const sc=el.querySelector('.scrib'); if(sc){const p=cl((tl-2.2)/0.4); sc.style.opacity=p; sc.style.transform='rotate(-7deg) scale('+(0.7+0.3*easeOut(p)).toFixed(3)+')';}
   }
   if(b.id==='after'){
    const ph=el.querySelector('.ph'); const inE=easeOut(tl/0.7);
    ph.style.transform='translateX(-50%) translateY('+((1-inE)*130).toFixed(1)+'px)';
    // カウンタ：手書き30分を消して「10秒」をスタンプ
    const x=el.querySelector('.bOld .x'); if(x) x.style.width=(easeIO((tl-0.9)/0.45)*108).toFixed(1)+'%';
    const bn=el.querySelector('#bnew'); if(bn){const p=cl((tl-1.35)/0.4); bn.style.opacity=p; bn.style.transform='scale('+(1.3-0.3*easeOut(p)).toFixed(3)+')';}
    // ハイライトのスイープ（試合リストを上→下＝全部できてる）
    const sw=el.querySelector('.sweep'); if(sw){const s=cl((tl-1.6)/2.4); sw.style.opacity=(s>0&&s<1?0.9:0).toFixed(2); sw.style.top=(120+s*900).toFixed(0)+'px';}
    // チップ
    const pop=(s)=>{const p=cl((tl-s)/0.32);return {o:p,sc:(0.7+0.3*easeOut(p))};};
    const off=1-cl((tl-(AFTERd-0.5))/0.4);
    const a=pop(2.6),c0=el.querySelector('.c0'); c0.style.opacity=(a.o*off).toFixed(2); c0.style.left='520px'; c0.style.top='800px'; c0.style.transform='scale('+a.sc.toFixed(3)+')';
    const bb=pop(3.1),c1=el.querySelector('.c1'); c1.style.opacity=(bb.o*off).toFixed(2); c1.style.left='60px'; c1.style.top='1250px'; c1.style.transform='scale('+bb.sc.toFixed(3)+')';
   }
  });
 };
 </script>
</body>`;

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
await p.setContent(html,{waitUntil:'networkidle'}); await p.evaluate(()=>document.fonts.ready);
console.log('rendering',NF,'frames /',TOTAL.toFixed(2),'s · bracket(BA)');
for(let i=0;i<NF;i++){await p.evaluate(t=>window.renderAt(t),i/FPS);await p.screenshot({path:path.join(FRAMES,`f${String(i).padStart(4,'0')}.png`)});}
await br.close();
const mp4=path.join(SCRATCH,'sofvo-reel-bracket.mp4');
const args=['-y','-framerate',String(FPS),'-i',path.join(FRAMES,'f%04d.png')];
if(process.env.AUDIO) args.push('-i',process.env.AUDIO);
args.push('-c:v','libx264','-pix_fmt','yuv420p','-r',String(FPS),'-movflags','+faststart');
if(process.env.AUDIO) args.push('-c:a','aac','-b:a','192k','-shortest','-map','0:v:0','-map','1:a:0');
args.push(mp4);
execFileSync(FF,args,{stdio:'inherit'});
console.log('done ->',mp4,'audio:',process.env.AUDIO?'yes':'no');
