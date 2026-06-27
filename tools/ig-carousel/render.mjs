import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const HERE = import.meta.dirname;
const ROOT = path.resolve(HERE, '../..');
const CSV = path.join(ROOT, 'docs/instagram/canva-bulk/carousels.csv');
const FONTS = path.join(HERE, 'fonts');
const OUT = path.join(HERE, 'output');
fs.mkdirSync(OUT, { recursive: true });

// only render these post indexes (0-based). Override via argv.
const ONLY = process.argv[2] ? process.argv[2].split(',').map(Number) : [0];

// ---- CSV parse (RFC4180-ish) ----
function parseCSV(text) {
  const rows = [];
  let row = [], field = '', i = 0, inQ = false;
  while (i < text.length) {
    const c = text[i];
    if (inQ) {
      if (c === '"') { if (text[i+1] === '"') { field += '"'; i += 2; continue; } inQ = false; i++; continue; }
      field += c; i++; continue;
    }
    if (c === '"') { inQ = true; i++; continue; }
    if (c === ',') { row.push(field); field = ''; i++; continue; }
    if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i+1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = ''; i++; continue;
    }
    field += c; i++;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows;
}

const raw = fs.readFileSync(CSV, 'utf8').replace(/^﻿/, '');
const rows = parseCSV(raw).filter(r => r.length > 1);
const header = rows[0];
const data = rows.slice(1).map(r => Object.fromEntries(header.map((h, j) => [h, r[j] ?? ''])));

const fontB64 = f => fs.readFileSync(path.join(FONTS, f)).toString('base64');
const dela = fontB64('DelaGothicOne-Regular.ttf');
const noto = fontB64('NotoSansJP.ttf');

const NAVY = '#1B3A5C', CREAM = '#F7F5EF', GOLD = '#C4A962', DARK = '#0F2440';

// Sofvo wordmark (Sof + vo). sofColor depends on background.
const wordmark = (variant) => {
  const sof = variant === 'navy' ? '#fff' : NAVY;
  return `<div class="wm"><span style="color:${sof}">Sof</span><span style="color:${GOLD}">vo</span></div>`;
};
const wordmarkBig = (variant) => {
  const sof = variant === 'navy' ? '#fff' : NAVY;
  return `<div class="wmbig"><span style="color:${sof}">Sof</span><span style="color:${GOLD}">vo</span></div>`;
};

const heart = `<svg width="34" height="34" viewBox="0 0 24 24"><path fill="${GOLD}" d="M12 21s-7.5-4.9-10-9.2C.3 8.6 1.6 5 5 5c2 0 3.3 1.2 4 2.3C9.7 6.2 11 5 13 5c3.4 0 4.7 3.6 3 6.8C19.5 16.1 12 21 12 21z"/></svg>`;
const mark = `<svg width="30" height="30" viewBox="0 0 24 24"><path fill="#fff" d="M6 3h12a1 1 0 0 1 1 1v17l-7-4-7 4V4a1 1 0 0 1 1-1z"/></svg>`;
const footer = `<div class="footer"><span>${heart}</span><span class="ftxt">ソフトバレーを、もっと楽しく。</span><span>${mark}</span></div>`;

function bullets(body) {
  return body.split('／').map(s => `<div class="li"><span class="dot"></span><span class="jptxt jp">${s}</span></div>`).join('');
}

function coverSlide(d) {
  return `<div class="slide navy">
    ${wordmark('navy')}
    <div class="cover">
      <div class="pill">${d.pill}</div>
      <div class="ctitle jp">${d.cover_title.replace(/"/g,'&quot;')}</div>
      <div class="csub">${d.cover_sub}</div>
    </div>
    ${footer}
  </div>`;
}
function contentSlide(d, n, bg) {
  return `<div class="slide ${bg}">
    ${wordmark(bg === 'navy' ? 'navy' : 'cream')}
    <div class="content">
      <div class="card">
        <div class="cardhead"><span class="bar"></span><span class="htxt jp">${d['s'+n+'_title']}</span></div>
        <div class="cardbody">${bullets(d['s'+n+'_body'])}</div>
      </div>
    </div>
    ${footer}
  </div>`;
}
function ctaSlide(d) {
  return `<div class="slide navy">
    <div class="cta">
      ${wordmarkBig('navy')}
      <div class="ctatitle jp">${d.cta_title}</div>
      <div class="ctasub">${d.cta_sub}</div>
    </div>
    ${footer}
  </div>`;
}

function pageHTML(d) {
  const slides = [coverSlide(d), contentSlide(d,2,'cream'), contentSlide(d,3,'navy'), contentSlide(d,4,'cream'), ctaSlide(d)].join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face{font-family:'Dela';src:url(data:font/ttf;base64,${dela}) format('truetype');}
  @font-face{font-family:'Noto';src:url(data:font/ttf;base64,${noto}) format('truetype');font-weight:100 900;}
  *{margin:0;padding:0;box-sizing:border-box;}
  .jp{word-break:auto-phrase;line-break:strict;text-wrap:balance;overflow-wrap:break-word;}
  .slide{width:1080px;height:1350px;position:relative;overflow:hidden;font-family:'Noto';}
  .slide.navy{background:${NAVY};color:#fff;}
  .slide.cream{background:${CREAM};color:${NAVY};}
  .wm{position:absolute;top:64px;left:80px;font-family:'Noto';font-weight:900;font-size:54px;letter-spacing:.5px;z-index:5;}
  .wmbig{font-family:'Noto';font-weight:900;font-size:120px;letter-spacing:1px;margin-bottom:50px;}
  .cover{position:absolute;top:0;left:0;right:0;bottom:120px;display:flex;flex-direction:column;justify-content:center;padding:100px 80px;}
  .pill{align-self:flex-start;background:${GOLD};color:${NAVY};font-weight:700;font-size:34px;padding:12px 34px;border-radius:999px;margin-bottom:44px;}
  .ctitle{font-family:'Dela';font-size:82px;line-height:1.36;letter-spacing:.5px;}
  .csub{margin-top:44px;font-size:42px;font-weight:700;color:${GOLD};}
  .content{position:absolute;top:0;left:0;right:0;bottom:120px;display:flex;align-items:center;padding:80px;}
  .card{background:#fff;color:${NAVY};border-radius:40px;padding:76px 64px;width:100%;box-shadow:0 16px 40px rgba(0,0,0,.18);}
  .cardhead{font-family:'Dela';font-size:60px;line-height:1.32;display:flex;align-items:flex-start;margin-bottom:48px;}
  .bar{display:inline-block;width:16px;height:54px;background:${GOLD};border-radius:8px;margin-right:28px;flex:0 0 auto;margin-top:6px;}
  .htxt{flex:1;}
  .li{display:flex;align-items:flex-start;font-size:44px;line-height:1.6;font-weight:500;margin:30px 0;}
  .li .jptxt{flex:1;}
  .dot{width:18px;height:18px;border-radius:50%;background:${GOLD};margin:20px 28px 0 0;flex:0 0 auto;}
  .cta{position:absolute;top:0;left:0;right:0;bottom:120px;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:80px;text-align:center;}
  .ctatitle{font-family:'Dela';font-size:76px;line-height:1.38;}
  .ctasub{margin-top:40px;font-size:44px;font-weight:700;color:${GOLD};}
  .footer{position:absolute;left:0;right:0;bottom:0;height:96px;background:${DARK};color:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 50px;}
  .footer .ftxt{font-size:34px;font-weight:700;letter-spacing:1px;}
  .footer span{display:flex;align-items:center;}
  </style></head><body>${slides}</body></html>`;
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1 });
for (const idx of ONLY) {
  const d = data[idx];
  if (!d) { console.log('no row', idx); continue; }
  await page.setContent(pageHTML(d), { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  const slides = await page.locator('.slide').all();
  const pn = String(idx + 1).padStart(2, '0');
  for (let s = 0; s < slides.length; s++) {
    await slides[s].screenshot({ path: path.join(OUT, `post${pn}_${s + 1}.png`) });
  }
  console.log('rendered post', pn, '-', slides.length, 'slides');
}
await browser.close();
console.log('done ->', OUT);
