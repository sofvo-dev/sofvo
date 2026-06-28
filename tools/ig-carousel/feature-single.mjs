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

// 1枚目＝実機表紙（確定仕様：クリーム背景・ロゴなし・タイトル1行・スマホ突き抜け・上から自然表示）
function coverSlide(d){return `<div class="slide cream">
 <div class="ctop"><div class="pill">${d.pill}</div><div class="ctitle">${d.title}</div><div class="csub">${d.sub}</div></div>
 <div class="fphone"><img style="object-position:${d.pos||'center top'}" src="data:image/jpeg;base64,${img64(d.img)}"></div>${footer}</div>`;}
// 2・3枚目＝解説（カード＋箇条書き）。inner はブランドのため左上ロゴあり
function textSlide(d){return `<div class="slide ${d.bg}">${wm(d.bg)}
 <div class="content"><div class="card"><div class="chead"><span class="bar"></span>${d.head}</div><div class="cbody">${bullets(d.body)}</div></div></div>${footer}</div>`;}
// 4枚目＝CTA
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
 /* 表紙 */
 .ctop{position:absolute;top:50px;left:0;right:0;text-align:center;padding:0 50px;z-index:3}
 .pill{display:inline-block;background:${GOLD};color:${NAVY};font-weight:700;font-size:30px;padding:10px 28px;border-radius:999px;margin-bottom:18px}
 .ctitle{font-family:'Dela';font-size:58px;line-height:1.1;color:${NAVY};white-space:nowrap}
 .csub{margin-top:14px;font-size:32px;font-weight:700;color:${NAVY};opacity:.78}
 .fphone{position:absolute;left:50%;transform:translateX(-50%);bottom:0;top:300px;width:780px;height:auto;border:14px solid ${DARK};border-radius:56px 56px 0 0;border-bottom:0;overflow:hidden;box-shadow:0 -4px 50px rgba(0,0,0,.22);background:#000;z-index:1}
 .fphone img{width:100%;height:100%;object-fit:cover;display:block}
 /* 解説カード */
 .content{position:absolute;top:0;left:0;right:0;bottom:92px;display:flex;align-items:center;padding:80px}
 .card{background:#fff;color:${NAVY};border-radius:40px;padding:76px 64px;width:100%;box-shadow:0 16px 40px rgba(0,0,0,.18)}
 .chead{font-family:'Dela';font-size:58px;line-height:1.32;display:flex;align-items:flex-start;margin-bottom:46px}
 .bar{display:inline-block;width:16px;height:52px;background:${GOLD};border-radius:8px;margin-right:26px;margin-top:6px;flex:0 0 auto}
 .li{display:flex;align-items:flex-start;font-size:46px;line-height:1.6;font-weight:500;margin:30px 0}
 .dot{width:18px;height:18px;border-radius:50%;background:${GOLD};margin:22px 28px 0 0;flex:0 0 auto}
 /* CTA */
 .cta{position:absolute;top:0;left:0;right:0;bottom:92px;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:80px}
 .ctaT{font-family:'Dela';font-size:74px;line-height:1.35}.ctaS{margin-top:32px;font-size:44px;font-weight:700;color:${GOLD}}
 </style><body>${slides.join('')}</body>`;
}

// 大会フロー＋発見・運営・コミュニティ（各4枚）
// 表紙クリーム → ②navy → ③cream → ④navy（スワイプのコントラスト）
const Q='こんな悩み、ありませんか？';
const CTASUB='無料・プロフィールのリンクから';
const posts=[
 {key:'bracket', cover:{pill:'大会運営',title:'対戦表はボタンひとつ。',sub:'手書きはもう卒業',img:'app-bracket.jpg'},
  slides:[{bg:'navy',head:Q,body:'手書きで30分以上かかる／組み替えのたびに書き直し／コート割りや対戦の組み方が複雑'},
          {bg:'cream',head:'Sofvoなら数タップ',body:'チーム数を入れるだけで自動作成／リーグもトーナメントも対応／コートも試合数も自動で割り当て／組み直しもワンタップ'}],
  cta:{bg:'navy',title:'対戦表づくり、ゼロに。',sub:CTASUB}},
 {key:'score', cover:{pill:'試合中',title:'スコアはリアルタイム。',sub:'入力した瞬間、全員の画面へ',img:'app-score.jpg'},
  slides:[{bg:'navy',head:Q,body:'紙のスコアシートが行方不明／今どっちが勝ってる？が分からない／集計ミスでもめる'},
          {bg:'cream',head:'Sofvoならその場で共有',body:'入力した瞬間に全員の画面へ反映／セットの勝敗・得点を自動集計／結果はそのまま順位に反映'}],
  cta:{bg:'navy',title:'スコアも集計も、スマホで。',sub:CTASUB}},
 {key:'ranking', cover:{pill:'結果発表',title:'順位は自動で確定。',sub:'セットの勝敗から即集計',img:'app-ranking.jpg'},
  slides:[{bg:'navy',head:Q,body:'順位の計算が大変／同率のときの順位付けで迷う／発表までやたら時間がかかる'},
          {bg:'cream',head:'Sofvoなら即発表',body:'セット数・得失点から自動で順位確定／同率もルールで自動判定／その場で発表・シェアできる'}],
  cta:{bg:'navy',title:'順位発表、待たせない。',sub:CTASUB}},
 {key:'checkin', cover:{pill:'受付',title:'受付はQRでサッと。',sub:'名簿チェックの行列をゼロに',img:'app-checkin.jpg'},
  slides:[{bg:'navy',head:Q,body:'受付の名簿チェックで行列／誰が来たか分からない／紙の名簿が回らない'},
          {bg:'cream',head:'SofvoならQRで受付',body:'QRを掲示するだけで受付完了／カメラでサッとチェックイン／出欠はリアルタイムで一覧に'}],
  cta:{bg:'navy',title:'受付の行列、解消。',sub:CTASUB}},
 {key:'finance', cover:{pill:'お金の管理',title:'収支もアプリで丸見え。',sub:'参加費も経費も自動で集計',img:'app-finance.jpg'},
  slides:[{bg:'navy',head:Q,body:'参加費の集計が手作業／経費がどんぶり勘定／黒字か赤字か分からない'},
          {bg:'cream',head:'Sofvoなら自動で集計',body:'参加費・協賛金・経費をまとめて記録／損益が自動で見える／チーム数からも自動計算'}],
  cta:{bg:'navy',title:'大会の収支、ひと目で。',sub:CTASUB}},
 {key:'search-tournaments', cover:{pill:'さがす',title:'出たい大会が見つかる。',sub:'エリア・種目でサッと検索',img:'app-search-tournaments.jpg'},
  slides:[{bg:'navy',head:Q,body:'大会情報がバラバラ／どこで募集してるか分からない／気づいたら締切'},
          {bg:'cream',head:'Sofvoならまとめて検索',body:'全国の大会をまとめて表示／エリア・種目・日程で絞り込み／気になる主催者はフォロー'}],
  cta:{bg:'navy',title:'次の大会、見つけよう。',sub:CTASUB}},
 {key:'search-members', cover:{pill:'仲間さがし',title:'メンバー募集もアプリで。',sub:'一緒に出る仲間を見つける',img:'app-search-members.jpg'},
  slides:[{bg:'navy',head:Q,body:'あと1人が見つからない／声かけがLINE頼み／募集の場がない'},
          {bg:'cream',head:'Sofvoなら募集できる',body:'メンバー募集を投稿できる／条件で仲間を検索／気になる人にそのまま連絡'}],
  cta:{bg:'navy',title:'仲間集め、ここで。',sub:CTASUB}},
 {key:'notifications', cover:{pill:'お知らせ',title:'大事な連絡を見逃さない。',sub:'募集も結果もすぐ届く',img:'app-notifications.jpg'},
  slides:[{bg:'navy',head:Q,body:'連絡がいろんな所に散らばる／大事な告知を見逃す／結果の通知が来ない'},
          {bg:'cream',head:'Sofvoならまとめて通知',body:'募集・エントリー・結果をプッシュ通知／アプリにまとまって届く／見逃しゼロ'}],
  cta:{bg:'navy',title:'連絡、ぜんぶここに。',sub:CTASUB}},
 {key:'home', cover:{pill:'タイムライン',title:'大会の「今」が集まる。',sub:'フォローした人の投稿が並ぶ',img:'app-home.jpg'},
  slides:[{bg:'navy',head:Q,body:'ソフトバレーの情報が少ない／仲間の活動が見えない／盛り上がりを共有しづらい'},
          {bg:'cream',head:'Sofvoなら流れてくる',body:'フォローした人の投稿が並ぶ／大会レポや募集が流れてくる／感想や写真をシェア'}],
  cta:{bg:'navy',title:'ソフトバレーの輪を、もっと。',sub:CTASUB}},
 {key:'board', cover:{pill:'連絡',title:'当日の連絡もアプリで。',sub:'掲示板で参加者に一斉共有',img:'app-board.jpg'},
  slides:[{bg:'navy',head:Q,body:'当日の連絡がバラつく／コート変更が伝わらない／全員に届かない'},
          {bg:'cream',head:'Sofvoなら一斉連絡',body:'掲示板で参加者にまとめて連絡／変更もその場で共有／お知らせはプッシュで通知'}],
  cta:{bg:'navy',title:'当日の連絡、まとめて。',sub:CTASUB}},
 {key:'team', cover:{pill:'戦績',title:'チームの戦績が残る。',sub:'過去の成績も自動で記録',img:'app-team.jpg'},
  slides:[{bg:'navy',head:Q,body:'戦績が記録に残らない／過去の成績を忘れる／チームの歩みが見えない'},
          {bg:'cream',head:'Sofvoなら自動で記録',body:'出場した大会と結果を自動で記録／チームの戦績がたまる／成長がひと目で'}],
  cta:{bg:'navy',title:'チームの歩み、残そう。',sub:CTASUB}},
 {key:'venues', cover:{pill:'会場',title:'会場さがしもおまかせ。',sub:'近くの体育館を見つける',img:'app-venues.jpg'},
  slides:[{bg:'navy',head:Q,body:'使える体育館が分からない／会場情報がまとまってない／毎回ゼロから探す'},
          {bg:'cream',head:'Sofvoならさがせる',body:'会場をアプリでさがせる／場所や情報をまとめて確認／大会会場の参考に'}],
  cta:{bg:'navy',title:'会場さがし、ラクに。',sub:CTASUB}},
 {key:'overview', cover:{pill:'エントリー',title:'エントリーはタップで完了。',sub:'大会情報もひと目で',img:'app-overview.jpg'},
  slides:[{bg:'navy',head:Q,body:'申込書のやり取りが面倒／要項が分かりにくい／エントリー状況が不明'},
          {bg:'cream',head:'Sofvoならタップで完了',body:'大会情報をひと目で確認／タップでエントリー完了／参加状況もすぐ分かる'}],
  cta:{bg:'navy',title:'エントリー、サクッと。',sub:CTASUB}},
 {key:'organizer', cover:{pill:'主催者',title:'運営はこれ一台で。',sub:'準備から当日まで丸ごと',img:'app-organizer-menu.jpg'},
  slides:[{bg:'navy',head:Q,body:'運営の作業が多すぎる／ツールがバラバラ／当日は大忙し'},
          {bg:'cream',head:'Sofvoならまるごと',body:'対戦表・受付・スコア・順位・収支をまとめて／準備から当日まで一台で／主催者メニューに集約'}],
  cta:{bg:'navy',title:'大会運営、まるごと。',sub:CTASUB}},
];

const br=await chromium.launch(process.env.PW_CHROMIUM?{executablePath:process.env.PW_CHROMIUM}:{});
const p=await br.newPage({viewport:{width:1080,height:1350},deviceScaleFactor:1});
for(const post of posts){
 await p.setContent(build(post),{waitUntil:'networkidle'});
 await p.evaluate(()=>document.fonts.ready);
 const els=await p.locator('.slide').all();
 for(let i=0;i<els.length;i++){await els[i].screenshot({path:path.join(OUT,`${post.key}_${i+1}.png`)});}
 console.log('done',post.key,els.length,'slides');
}
await br.close();
