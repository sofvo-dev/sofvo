/**
 * 公式アカウントの Google ドライブ自動投稿を、まとめて再投稿するスクリプト。
 *
 * resetDrivePosts で投稿が消えた場合など、通常スケジュール（月・木 20:00 JST に
 * 1件ずつ）を待たずに戻したいときに使う。runDrivePostNow は管理者トークンが
 * 必須なので、サービスアカウントで管理者ユーザーのカスタムトークンを作り、
 * ID トークンに交換してから呼び出す。
 *
 * 実行例（GOOGLE_APPLICATION_CREDENTIALS にサービスアカウント鍵が必要）:
 *   COUNT=17 node scripts/restore-drive-posts.js
 */
const admin = require("firebase-admin");

const PROJECT_ID = "sofvo-19d84";
const REGION = "us-central1";
// Firebase Web API キー（クライアントに埋め込まれている公開値）
const WEB_API_KEY = "AIzaSyAAaQdMGZu_us_BplrwOq9t_ltvQWG0Pwc";
const ENDPOINT = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/runDrivePostNow`;

const COUNT = parseInt(process.env.COUNT || "17", 10);
const DELAY_MS = 3000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function findAdminUid(db) {
  const snap = await db.collection("users").where("isAdmin", "==", true).limit(1).get();
  if (snap.empty) throw new Error("isAdmin: true のユーザーが見つかりません");
  return snap.docs[0].id;
}

async function getIdToken(uid) {
  const customToken = await admin.auth().createCustomToken(uid);
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${WEB_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const body = await res.json();
  if (!res.ok || !body.idToken) {
    throw new Error(`ID トークンの取得に失敗: ${res.status} ${JSON.stringify(body)}`);
  }
  return body.idToken;
}

(async () => {
  admin.initializeApp();
  const db = admin.firestore();

  const before = await db.collection("posts").where("source", "==", "driveInstagram").get();
  console.log(`再投稿前の自動投稿数: ${before.size}`);

  const uid = await findAdminUid(db);
  console.log(`管理者 uid: ${uid}`);
  const idToken = await getIdToken(uid);

  let posted = 0;
  for (let i = 1; i <= COUNT; i++) {
    const res = await fetch(ENDPOINT, {
      method: "POST",
      headers: { Authorization: `Bearer ${idToken}`, "Content-Type": "application/json" },
      body: "{}",
    });
    const text = await res.text();
    console.log(`[${i}/${COUNT}] HTTP ${res.status} ${text.slice(0, 300)}`);

    if (res.status !== 200) {
      console.log("200 以外が返ったため中断します");
      break;
    }
    let json = null;
    try {
      json = JSON.parse(text);
    } catch (e) {
      console.log("レスポンスを解析できないため中断します");
      break;
    }
    // 投稿できる素材が尽きたら止める（postIndex も進まない）
    if (json.result && json.result.skipped) {
      console.log(`投稿できる素材がなくなりました: ${json.result.skipped}`);
      break;
    }
    posted += 1;
    if (i < COUNT) await sleep(DELAY_MS);
  }

  const after = await db.collection("posts").where("source", "==", "driveInstagram").get();
  console.log("----");
  console.log(`再投稿した件数: ${posted}`);
  console.log(`現在の自動投稿数: ${after.size}`);
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
