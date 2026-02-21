const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets 連携設定 (googleapis不使用 — 直接REST API)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const GADGET_SHEET_ID = "1IITgU-IvD1xpIqig0MtnlMfQAsoGWcwtbcPLKkNwv60";
const VENUE_SHEET_ID = "1HNRinSk-Bk_NdekTLiZ8cOhhgVWs4CV4KvRdnYUKtFk";

async function getAccessToken() {
  // Firebase Admin SDK の組み込みクレデンシャルを使用
  // google-auth-library 不要 → デプロイ高速化
  const tokenResult = await admin.app().options.credential.getAccessToken();
  return tokenResult.access_token;
}

async function sheetsClear(spreadsheetId, range) {
  const token = await getAccessToken();
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}:clear`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  });
  return res;
}

async function sheetsUpdate(spreadsheetId, range, values) {
  const token = await getAccessToken();
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}?valueInputOption=RAW`;
  const res = await fetch(url, {
    method: "PUT",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ values }),
  });
  if (!res.ok) throw new Error(`Sheets API error: ${res.status} ${await res.text()}`);
  return res.json();
}

async function sheetsAddSheet(spreadsheetId, sheetName) {
  const token = await getAccessToken();
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}:batchUpdate`;
  await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ requests: [{ addSheet: { properties: { title: sheetName } } }] }),
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Amazon PA-API v5 共通ヘルパー
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const PAAPI_HOST = "webservices.amazon.co.jp";
const PAAPI_REGION = "us-west-2";
const PAAPI_SERVICE = "ProductAdvertisingAPI";

function getPartnerTag() {
  return process.env.AMAZON_PARTNER_TAG || null;
}

function makeAffiliateUrl(asin) {
  const tag = getPartnerTag();
  if (tag) {
    return `https://www.amazon.co.jp/dp/${asin}?tag=${tag}`;
  }
  return `https://www.amazon.co.jp/dp/${asin}`;
}

function hasPaapiCredentials() {
  return !!(
    process.env.AMAZON_ACCESS_KEY &&
    process.env.AMAZON_SECRET_KEY &&
    process.env.AMAZON_PARTNER_TAG
  );
}

function getCredentials() {
  const accessKey = process.env.AMAZON_ACCESS_KEY;
  const secretKey = process.env.AMAZON_SECRET_KEY;
  const partnerTag = process.env.AMAZON_PARTNER_TAG;

  if (!accessKey || !secretKey || !partnerTag) {
    throw new Error(
      "Amazon PA-API credentials not configured. " +
      "Set AMAZON_ACCESS_KEY, AMAZON_SECRET_KEY, AMAZON_PARTNER_TAG in .env"
    );
  }
  return { accessKey, secretKey, partnerTag };
}

/**
 * AWS Signature Version 4 で PA-API v5 リクエストに署名
 */
function signRequest(payload, target) {
  const { accessKey, secretKey } = getCredentials();

  const now = new Date();
  const amzDate = now.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
  const dateStamp = amzDate.substring(0, 8);

  const canonicalUri = "/paapi5/" + target.split(".").pop().toLowerCase();
  const canonicalQuerystring = "";

  const headers = {
    "content-encoding": "amz-1.0",
    "content-type": "application/json; charset=utf-8",
    "host": PAAPI_HOST,
    "x-amz-date": amzDate,
    "x-amz-target": `com.amazon.paapi5.v1.ProductAdvertisingAPIv1.${target}`,
  };

  const signedHeaders = Object.keys(headers).sort().join(";");
  const canonicalHeaders = Object.keys(headers)
    .sort()
    .map((k) => `${k}:${headers[k]}\n`)
    .join("");

  const payloadHash = crypto
    .createHash("sha256")
    .update(payload)
    .digest("hex");

  const canonicalRequest = [
    "POST",
    canonicalUri,
    canonicalQuerystring,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");

  const credentialScope = `${dateStamp}/${PAAPI_REGION}/${PAAPI_SERVICE}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    crypto.createHash("sha256").update(canonicalRequest).digest("hex"),
  ].join("\n");

  const signingKey = getSignatureKey(secretKey, dateStamp, PAAPI_REGION, PAAPI_SERVICE);
  const signature = crypto
    .createHmac("sha256", signingKey)
    .update(stringToSign)
    .digest("hex");

  headers["Authorization"] =
    `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return { headers, url: `https://${PAAPI_HOST}${canonicalUri}` };
}

function getSignatureKey(key, dateStamp, region, service) {
  let k = crypto.createHmac("sha256", "AWS4" + key).update(dateStamp).digest();
  k = crypto.createHmac("sha256", k).update(region).digest();
  k = crypto.createHmac("sha256", k).update(service).digest();
  k = crypto.createHmac("sha256", k).update("aws4_request").digest();
  return k;
}

/**
 * PA-API レスポンスからアイテム情報を抽出
 */
function extractItem(item) {
  const info = item.ItemInfo || {};
  const images = item.Images || {};

  const asin = item.ASIN || "";
  return {
    asin,
    title: info.Title?.DisplayValue || "",
    imageUrl:
      images.Primary?.Large?.URL ||
      images.Primary?.Medium?.URL ||
      "",
    detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
    affiliateUrl: makeAffiliateUrl(asin),
    price:
      item.Offers?.Listings?.[0]?.Price?.DisplayAmount || null,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// スクレイピング フォールバック
// PA-API認証情報が未設定の場合に使用
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async function scrapeAmazonSearch(keyword) {
  const url = `https://www.amazon.co.jp/s?k=${encodeURIComponent(keyword)}&language=ja_JP`;

  const ac = new AbortController();
  const tid = setTimeout(() => ac.abort(), 8000);
  const response = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept-Language": "ja-JP,ja;q=0.9,en;q=0.8",
      "Accept":
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    },
    signal: ac.signal,
  }).finally(() => clearTimeout(tid));

  if (!response.ok) {
    throw new Error(`Amazon returned status ${response.status}`);
  }

  const html = await response.text();
  const cheerio = require("cheerio");
  const $ = cheerio.load(html);
  const items = [];

  // 検索結果カードを解析
  $('[data-component-type="s-search-result"]').each((_, el) => {
    const $el = $(el);
    const asin = $el.attr("data-asin");
    if (!asin || asin.length !== 10) return;

    // 商品名
    const title =
      $el.find("h2 a span").text().trim() ||
      $el.find(".a-text-normal").first().text().trim();

    // 画像URL
    const image =
      $el.find("img.s-image").attr("src") || "";

    // 価格
    const price =
      $el.find(".a-price .a-offscreen").first().text().trim() || null;

    if (title && image) {
      items.push({
        asin,
        title,
        imageUrl: image,
        detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
        affiliateUrl: makeAffiliateUrl(asin),
        price,
      });
    }
  });

  return items.slice(0, 10);
}

async function scrapeAmazonProduct(asin) {
  const url = `https://www.amazon.co.jp/dp/${asin}?language=ja_JP`;

  const ac = new AbortController();
  const tid = setTimeout(() => ac.abort(), 8000);
  const response = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept-Language": "ja-JP,ja;q=0.9,en;q=0.8",
      "Accept":
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    },
    signal: ac.signal,
  }).finally(() => clearTimeout(tid));

  if (!response.ok) {
    throw new Error(`Amazon returned status ${response.status}`);
  }

  const html = await response.text();
  const cheerio = require("cheerio");
  const $ = cheerio.load(html);

  const title =
    $("#productTitle").text().trim() ||
    $("h1#title span").text().trim();

  const image =
    $("#imgBlkFront").attr("src") ||
    $("#landingImage").attr("src") ||
    $("#main-image").attr("src") ||
    "";

  const price =
    $(".a-price .a-offscreen").first().text().trim() ||
    $("#priceblock_ourprice").text().trim() ||
    null;

  return {
    asin,
    title,
    imageUrl: image,
    detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
    affiliateUrl: makeAffiliateUrl(asin),
    price,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cloud Function: Amazon 商品キーワード検索
// PA-API → スクレイピング のフォールバック付き
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.amazonSearch = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const keyword = req.query.q;
  if (!keyword) {
    res.status(400).json({ error: "Missing query parameter: q" });
    return;
  }

  // 1) PA-API が使える場合はそちらを優先
  if (hasPaapiCredentials()) {
    try {
      const { partnerTag } = getCredentials();

      const payload = JSON.stringify({
        Keywords: keyword,
        Resources: [
          "ItemInfo.Title",
          "Images.Primary.Large",
          "Images.Primary.Medium",
          "Offers.Listings.Price",
        ],
        SearchIndex: "All",
        ItemCount: 10,
        PartnerTag: partnerTag,
        PartnerType: "Associates",
        Marketplace: "www.amazon.co.jp",
      });

      const { headers, url } = signRequest(payload, "SearchItems");
      const response = await fetch(url, {
        method: "POST",
        headers,
        body: payload,
      });

      const data = await response.json();

      if (response.ok) {
        const items = (data.SearchResult?.Items || []).map(extractItem);
        res.json(items);
        return;
      }

      console.warn("PA-API failed, falling back to scraping:", JSON.stringify(data));
    } catch (paapiError) {
      console.warn("PA-API error, falling back to scraping:", paapiError.message);
    }
  }

  // 2) フォールバック: スクレイピング
  try {
    const items = await scrapeAmazonSearch(keyword);
    res.json(items);
  } catch (scrapeError) {
    console.error("Scraping also failed:", scrapeError.message);
    res.status(500).json({
      error: "検索に失敗しました。しばらく待ってからお試しください。",
    });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cloud Function: ASIN で商品情報取得
// PA-API → スクレイピング のフォールバック付き
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.amazonProduct = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const asin = req.query.asin;
  if (!asin) {
    res.status(400).json({ error: "Missing query parameter: asin" });
    return;
  }

  // 1) PA-API が使える場合はそちらを優先
  if (hasPaapiCredentials()) {
    try {
      const { partnerTag } = getCredentials();

      const payload = JSON.stringify({
        ItemIds: [asin],
        Resources: [
          "ItemInfo.Title",
          "Images.Primary.Large",
          "Images.Primary.Medium",
          "Offers.Listings.Price",
        ],
        PartnerTag: partnerTag,
        PartnerType: "Associates",
        Marketplace: "www.amazon.co.jp",
      });

      const { headers, url } = signRequest(payload, "GetItems");
      const response = await fetch(url, {
        method: "POST",
        headers,
        body: payload,
      });

      const data = await response.json();

      if (response.ok) {
        const items = data.ItemsResult?.Items || [];
        if (items.length > 0) {
          res.json(extractItem(items[0]));
          return;
        }
      }

      console.warn("PA-API failed for product, falling back to scraping");
    } catch (paapiError) {
      console.warn("PA-API error for product, falling back:", paapiError.message);
    }
  }

  // 2) フォールバック: スクレイピング
  try {
    const product = await scrapeAmazonProduct(asin);
    if (product.title) {
      res.json(product);
    } else {
      // スクレイピングでも取得できない場合、最低限の情報を返す
      res.json({
        asin,
        title: "",
        imageUrl: `https://images-na.ssl-images-amazon.com/images/P/${asin}.09.LZZZZZZZ.jpg`,
        detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
        affiliateUrl: makeAffiliateUrl(asin),
        price: null,
      });
    }
  } catch (scrapeError) {
    console.error("Scraping also failed for product:", scrapeError.message);
    // 最低限の情報を返す
    res.json({
      asin,
      title: "",
      imageUrl: `https://images-na.ssl-images-amazon.com/images/P/${asin}.09.LZZZZZZZ.jpg`,
      detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
      affiliateUrl: makeAffiliateUrl(asin),
      price: null,
    });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ガジェット → Google Sheets 同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.syncGadgetsToSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    // 全ユーザーのガジェットを取得
    const usersSnap = await admin.firestore().collection("users").get();
    const allGadgets = [];

    for (const userDoc of usersSnap.docs) {
      const userData = userDoc.data();
      const nickname = userData.nickname || "不明";
      const gadgetsSnap = await userDoc.ref.collection("gadgets")
        .orderBy("createdAt", "desc").get();

      for (const gDoc of gadgetsSnap.docs) {
        const g = gDoc.data();
        allGadgets.push([
          gDoc.id,
          userDoc.id,
          nickname,
          g.name || "",
          g.category || "カテゴリなし",
          g.amazonUrl || "",
          g.amazonAffiliateUrl || "",
          g.rakutenAffiliateUrl || "",
          g.imageUrl || "",
          g.memo || "",
          g.createdAt ? g.createdAt.toDate().toISOString().split("T")[0] : "",
        ]);
      }
    }

    // シートをクリアしてヘッダー＋データを書き込む
    const sheetName = "ガジェット一覧";
    const clearRes = await sheetsClear(GADGET_SHEET_ID, `${sheetName}!A:K`);
    if (!clearRes.ok) {
      // シートがない場合は作成
      await sheetsAddSheet(GADGET_SHEET_ID, sheetName);
    }

    const values = [
      ["ガジェットID", "ユーザーID", "ユーザー", "商品名", "カテゴリ", "Amazon URL", "Amazon Affiliate URL", "楽天 Affiliate URL", "画像URL", "メモ", "登録日"],
      ...allGadgets,
    ];

    await sheetsUpdate(GADGET_SHEET_ID, `${sheetName}!A1`, values);

    res.json({ success: true, count: allGadgets.length });
  } catch (e) {
    console.error("Gadget sync error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 会場 → Google Sheets 同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.syncVenuesToSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const venuesSnap = await admin.firestore().collection("venues")
      .orderBy("name").get();

    const venueRows = venuesSnap.docs.map((doc) => {
      const v = doc.data();
      return [
        doc.id,
        v.name || "",
        v.address || "",
        v.phone || "",
        v.station || "",
        v.courts || 0,
        v.parking || 0,
        v.toilets || 0,
        v.hasChangeRoom ? "あり" : "なし",
        v.hasShower ? "あり" : "なし",
        v.hasGallery ? "あり" : "なし",
        v.hasAC ? "あり" : "なし",
        v.eatArea || "",
        v.openTime || "",
        v.closeTime || "",
        v.fee || "",
        (v.equipments || []).map((eq) => `${eq.name}(${eq.qty}個${eq.fee > 0 ? "/¥" + eq.fee : "/無料"})`).join(", "),
        v.rating || 0,
        v.reviewCount || 0,
        v.createdAt ? v.createdAt.toDate().toISOString().split("T")[0] : "",
      ];
    });

    const sheetName = "会場一覧";
    const clearRes = await sheetsClear(VENUE_SHEET_ID, `${sheetName}!A:T`);
    if (!clearRes.ok) {
      await sheetsAddSheet(VENUE_SHEET_ID, sheetName);
    }

    const values = [
      ["会場ID", "会場名", "住所", "電話", "最寄り駅", "コート数", "駐車場", "トイレ",
       "更衣室", "シャワー", "観覧席", "空調", "飲食エリア",
       "開始時間", "終了時間", "料金", "貸出備品", "評価", "レビュー数", "登録日"],
      ...venueRows,
    ];

    await sheetsUpdate(VENUE_SHEET_ID, `${sheetName}!A1`, values);

    res.json({ success: true, count: venueRows.length });
  } catch (e) {
    console.error("Venue sync error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// お知らせ初期データ登録（1回だけ実行）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.seedNotices = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const db = admin.firestore();
    const existing = await db.collection("notices").limit(1).get();
    if (!existing.empty) {
      res.json({ message: "お知らせは既に登録済みです", count: 0 });
      return;
    }

    const notices = [
      {
        type: "release",
        title: "Sofvo 正式リリースのお知らせ",
        body: "ソフトバレーボール マッチングアプリ「Sofvo」をご利用いただきありがとうございます。大会検索・メンバー募集・チャットなどの機能をお楽しみください。",
        createdAt: admin.firestore.Timestamp.fromDate(new Date("2026-02-14T00:00:00+09:00")),
      },
      {
        type: "update",
        title: "バージョン 1.1 アップデート",
        body: "大会検索のフィルター機能が強化されました。種別・エリア・日付での絞り込みが可能です。",
        createdAt: admin.firestore.Timestamp.fromDate(new Date("2026-02-10T00:00:00+09:00")),
      },
    ];

    const batch = db.batch();
    for (const notice of notices) {
      batch.set(db.collection("notices").doc(), notice);
    }
    await batch.commit();

    res.json({ success: true, count: notices.length });
  } catch (e) {
    console.error("Seed notices error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Firestore トリガー: ガジェット変更時に自動同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onGadgetWrite = functions.firestore
  .document("users/{userId}/gadgets/{gadgetId}")
  .onWrite(async () => {
    try {
      // 内部HTTPリクエストで同期処理を実行
      const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
      const syncUrl = `https://us-central1-${projectId}.cloudfunctions.net/syncGadgetsToSheet`;
      const ac = new AbortController();
      const tid = setTimeout(() => ac.abort(), 30000);
      await fetch(syncUrl, { method: "POST", signal: ac.signal }).finally(() => clearTimeout(tid));
    } catch (e) {
      console.warn("Auto gadget sync failed (non-critical):", e.message);
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Firestore トリガー: 会場変更時に自動同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onVenueWrite = functions.firestore
  .document("venues/{venueId}")
  .onWrite(async () => {
    try {
      const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
      const syncUrl = `https://us-central1-${projectId}.cloudfunctions.net/syncVenuesToSheet`;
      const ac = new AbortController();
      const tid = setTimeout(() => ac.abort(), 30000);
      await fetch(syncUrl, { method: "POST", signal: ac.signal }).finally(() => clearTimeout(tid));
    } catch (e) {
      console.warn("Auto venue sync failed (non-critical):", e.message);
    }
  });
