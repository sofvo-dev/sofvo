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

async function sheetsRead(spreadsheetId, range) {
  const token = await getAccessToken();
  const url = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`Sheets read error: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.values || [];
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

// ランダムUser-Agent（Cloud FunctionsのIPブロック対策）
function randomUserAgent() {
  const agents = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:133.0) Gecko/20100101 Firefox/133.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  ];
  return agents[Math.floor(Math.random() * agents.length)];
}

async function scrapeAmazonSearch(keyword) {
  const url = `https://www.amazon.co.jp/s?k=${encodeURIComponent(keyword)}&language=ja_JP`;

  const ac = new AbortController();
  const tid = setTimeout(() => ac.abort(), 10000);
  const response = await fetch(url, {
    headers: {
      "User-Agent": randomUserAgent(),
      "Accept-Language": "ja-JP,ja;q=0.9,en-US;q=0.8,en;q=0.7",
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Encoding": "gzip, deflate, br",
      "Cache-Control": "max-age=0",
      "Sec-Ch-Ua": '"Chromium";v="131", "Not_A Brand";v="24"',
      "Sec-Ch-Ua-Mobile": "?0",
      "Sec-Ch-Ua-Platform": '"Windows"',
      "Sec-Fetch-Dest": "document",
      "Sec-Fetch-Mode": "navigate",
      "Sec-Fetch-Site": "none",
      "Sec-Fetch-User": "?1",
      "Upgrade-Insecure-Requests": "1",
    },
    redirect: "follow",
    signal: ac.signal,
  }).finally(() => clearTimeout(tid));

  if (!response.ok) {
    throw new Error(`Amazon returned status ${response.status}`);
  }

  const html = await response.text();

  // CAPTCHA検出
  if (html.includes("captcha") || html.includes("robot") || html.includes("api-services-support@amazon.com")) {
    console.warn("[scrapeAmazonSearch] CAPTCHA/bot detection page received");
    throw new Error("Amazon bot detection triggered");
  }

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

  console.log(`[scrapeAmazonSearch] Parsed ${items.length} items from HTML (length: ${html.length})`);
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

  // デバッグ: 認証情報の有無をログ出力
  const hasCredentials = hasPaapiCredentials();
  console.log(`[amazonSearch] keyword="${keyword}", hasPaapiCredentials=${hasCredentials}`);

  // 1) PA-API が使える場合はそちらを優先
  if (hasCredentials) {
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

      const ac = new AbortController();
      const tid = setTimeout(() => ac.abort(), 12000);
      const response = await fetch(url, {
        method: "POST",
        headers,
        body: payload,
        signal: ac.signal,
      }).finally(() => clearTimeout(tid));

      const data = await response.json();

      if (response.ok) {
        const items = (data.SearchResult?.Items || []).map(extractItem);
        console.log(`[amazonSearch] PA-API success: ${items.length} items`);
        res.json(items);
        return;
      }

      console.warn(`[amazonSearch] PA-API failed (${response.status}):`, JSON.stringify(data).substring(0, 500));
    } catch (paapiError) {
      console.warn(`[amazonSearch] PA-API error: ${paapiError.message}`);
    }
  }

  // 2) フォールバック: スクレイピング
  try {
    console.log(`[amazonSearch] Trying scraping fallback...`);
    const items = await scrapeAmazonSearch(keyword);
    console.log(`[amazonSearch] Scraping success: ${items.length} items`);
    res.json(items);
  } catch (scrapeError) {
    console.error(`[amazonSearch] Scraping also failed: ${scrapeError.message}`);
    // エラーでも空配列を返す（UIで手動入力を促す）
    res.json([]);
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
// 診断エンドポイント: Amazon検索の問題を特定
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.amazonSearchDebug = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const result = {
    credentials: {
      hasAccessKey: !!process.env.AMAZON_ACCESS_KEY,
      hasSecretKey: !!process.env.AMAZON_SECRET_KEY,
      hasPartnerTag: !!process.env.AMAZON_PARTNER_TAG,
      partnerTag: process.env.AMAZON_PARTNER_TAG || "(not set)",
      accessKeyPrefix: process.env.AMAZON_ACCESS_KEY ? process.env.AMAZON_ACCESS_KEY.substring(0, 6) + "..." : "(not set)",
    },
    paapiTest: null,
    scrapeTest: null,
  };

  const keyword = req.query.q || "バレーボール";

  // PA-API テスト
  if (hasPaapiCredentials()) {
    try {
      const { partnerTag } = getCredentials();
      const payload = JSON.stringify({
        Keywords: keyword,
        Resources: ["ItemInfo.Title"],
        SearchIndex: "All",
        ItemCount: 1,
        PartnerTag: partnerTag,
        PartnerType: "Associates",
        Marketplace: "www.amazon.co.jp",
      });

      const { headers, url } = signRequest(payload, "SearchItems");
      const ac = new AbortController();
      const tid = setTimeout(() => ac.abort(), 12000);
      const response = await fetch(url, {
        method: "POST", headers, body: payload, signal: ac.signal,
      }).finally(() => clearTimeout(tid));

      const data = await response.json();
      result.paapiTest = {
        status: response.status,
        ok: response.ok,
        itemCount: data.SearchResult?.Items?.length || 0,
        error: data.Errors ? data.Errors.map(e => e.Message).join("; ") : null,
        rawSnippet: JSON.stringify(data).substring(0, 300),
      };
    } catch (e) {
      result.paapiTest = { error: e.message };
    }
  } else {
    result.paapiTest = { error: "Credentials not configured" };
  }

  // スクレイピング テスト
  try {
    const ac = new AbortController();
    const tid = setTimeout(() => ac.abort(), 10000);
    const scrapeUrl = `https://www.amazon.co.jp/s?k=${encodeURIComponent(keyword)}&language=ja_JP`;
    const response = await fetch(scrapeUrl, {
      headers: {
        "User-Agent": randomUserAgent(),
        "Accept-Language": "ja-JP,ja;q=0.9",
        "Accept": "text/html",
      },
      redirect: "follow",
      signal: ac.signal,
    }).finally(() => clearTimeout(tid));

    const html = await response.text();
    const hasCaptcha = html.includes("captcha") || html.includes("robot");
    const cheerio = require("cheerio");
    const $ = cheerio.load(html);
    const resultCount = $('[data-component-type="s-search-result"]').length;

    result.scrapeTest = {
      status: response.status,
      htmlLength: html.length,
      hasCaptcha,
      resultCount,
      titleTag: $("title").text().trim().substring(0, 100),
    };
  } catch (e) {
    result.scrapeTest = { error: e.message };
  }

  res.json(result);
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
      const searchId = userData.searchId || userDoc.id;
      const gadgetsSnap = await userDoc.ref.collection("gadgets")
        .orderBy("createdAt", "desc").get();

      for (const gDoc of gadgetsSnap.docs) {
        const g = gDoc.data();
        allGadgets.push([
          gDoc.id,
          searchId,
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

    const sheetName = "ガジェット一覧";
    const values = [
      ["ガジェットID", "ユーザーID", "ユーザー", "商品名", "カテゴリ", "Amazon URL", "Amazon Affiliate URL", "楽天 Affiliate URL", "画像URL", "メモ", "登録日"],
      ...allGadgets,
    ];

    // 先にデータを書き込み、その後に余分な行だけクリア
    // （書き込み失敗時にデータが消えるのを防止）
    try {
      await sheetsUpdate(GADGET_SHEET_ID, `${sheetName}!A1`, values);
    } catch (e) {
      // シートが存在しない場合は作成してリトライ
      await sheetsAddSheet(GADGET_SHEET_ID, sheetName);
      await sheetsUpdate(GADGET_SHEET_ID, `${sheetName}!A1`, values);
    }
    // 書き込み成功後、新データより下の古い行をクリア
    const nextRow = values.length + 1;
    await sheetsClear(GADGET_SHEET_ID, `${sheetName}!A${nextRow}:K10000`);

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
    const values = [
      ["会場ID", "会場名", "住所", "電話", "最寄り駅", "コート数", "駐車場", "トイレ",
       "更衣室", "シャワー", "観覧席", "空調", "飲食エリア",
       "開始時間", "終了時間", "料金", "貸出備品", "評価", "レビュー数", "登録日"],
      ...venueRows,
    ];

    // 先にデータを書き込み、その後に余分な行だけクリア
    // （書き込み失敗時にデータが消えるのを防止）
    try {
      await sheetsUpdate(VENUE_SHEET_ID, `${sheetName}!A1`, values);
    } catch (e) {
      // シートが存在しない場合は作成してリトライ
      await sheetsAddSheet(VENUE_SHEET_ID, sheetName);
      await sheetsUpdate(VENUE_SHEET_ID, `${sheetName}!A1`, values);
    }
    // 書き込み成功後、新データより下の古い行をクリア
    const nextRow = values.length + 1;
    await sheetsClear(VENUE_SHEET_ID, `${sheetName}!A${nextRow}:T10000`);

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
  .onWrite(async (change) => {
    // ユーザー向けフィールドに変更がなければスキップ（インポート起因の無限ループ防止）
    if (change.before.exists && change.after.exists) {
      const before = change.before.data();
      const after = change.after.data();
      const fields = ["name", "category", "amazonUrl", "amazonAffiliateUrl", "rakutenAffiliateUrl", "imageUrl", "memo"];
      const changed = fields.some((f) => (before[f] || "") !== (after[f] || ""));
      if (!changed) return;
    }
    try {
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
  .onWrite(async (change) => {
    // ユーザー向けフィールドに変更がなければスキップ（インポート起因の無限ループ防止）
    if (change.before.exists && change.after.exists) {
      const before = change.before.data();
      const after = change.after.data();
      const strFields = ["name", "address", "phone", "station", "eatArea", "openTime", "closeTime", "fee"];
      const numFields = ["courts", "parking", "toilets"];
      const boolFields = ["hasChangeRoom", "hasShower", "hasGallery", "hasAC"];
      const strChanged = strFields.some((f) => (before[f] || "") !== (after[f] || ""));
      const numChanged = numFields.some((f) => (before[f] || 0) !== (after[f] || 0));
      const boolChanged = boolFields.some((f) => !!before[f] !== !!after[f]);
      const eqChanged = JSON.stringify(before.equipments || []) !== JSON.stringify(after.equipments || []);
      if (!strChanged && !numChanged && !boolChanged && !eqChanged) return;
    }
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets → Firestore インポート (会場) 共通ロジック
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 比較用: Firestore のデータとシートのデータが同じかチェック
function isVenueDataEqual(existing, sheetData) {
  const fields = ["name", "address", "phone", "station", "eatArea", "openTime", "closeTime", "fee"];
  for (const f of fields) {
    if ((existing[f] || "") !== (sheetData[f] || "")) return false;
  }
  const numFields = ["courts", "parking", "toilets"];
  for (const f of numFields) {
    if ((existing[f] || 0) !== (sheetData[f] || 0)) return false;
  }
  const boolFields = ["hasChangeRoom", "hasShower", "hasGallery", "hasAC"];
  for (const f of boolFields) {
    if (!!existing[f] !== !!sheetData[f]) return false;
  }
  if (JSON.stringify(existing.equipments || []) !== JSON.stringify(sheetData.equipments || [])) return false;
  return true;
}

async function doImportVenues() {
  const rows = await sheetsRead(VENUE_SHEET_ID, "会場一覧!A:T");
  if (rows.length < 2) return { imported: 0, updated: 0, skipped: 0, total: 0 };

  const db = admin.firestore();
  const dataRows = rows.slice(1);
  let imported = 0;
  let updated = 0;
  let skipped = 0;

  for (const row of dataRows) {
    const venueId = (row[0] || "").trim();
    const name = (row[1] || "").trim();
    if (!name) { skipped++; continue; }

    const venueData = {
      name,
      address: row[2] || "",
      phone: row[3] || "",
      station: row[4] || "",
      courts: parseInt(row[5]) || 0,
      parking: parseInt(row[6]) || 0,
      toilets: parseInt(row[7]) || 0,
      hasChangeRoom: (row[8] || "").trim() === "あり",
      hasShower: (row[9] || "").trim() === "あり",
      hasGallery: (row[10] || "").trim() === "あり",
      hasAC: (row[11] || "").trim() === "あり",
      eatArea: row[12] || "",
      openTime: row[13] || "",
      closeTime: row[14] || "",
      fee: row[15] || "",
    };

    if (row[16]) {
      const eqParts = row[16].split(",").map((s) => s.trim()).filter(Boolean);
      venueData.equipments = eqParts.map((part) => {
        const m = part.match(/^(.+?)\((\d+)個(?:\/¥(\d+)|\/無料)?\)$/);
        if (m) return { name: m[1], qty: parseInt(m[2]) || 1, fee: parseInt(m[3]) || 0 };
        return { name: part, qty: 1, fee: 0 };
      });
    }

    if (venueId) {
      const existing = await db.collection("venues").doc(venueId).get();
      if (existing.exists) {
        // データが変わっていなければスキップ（無限ループ防止）
        if (isVenueDataEqual(existing.data(), venueData)) { skipped++; continue; }
        venueData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        await db.collection("venues").doc(venueId).update(venueData);
        updated++;
      } else {
        venueData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        venueData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        venueData.registeredBy = "sheet_import";

        venueData.rating = 0;
        venueData.reviewCount = 0;
        await db.collection("venues").doc(venueId).set(venueData);
        imported++;
      }
    } else {
      venueData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      venueData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      venueData.registeredBy = "sheet_import";
      venueData.rating = 0;
      venueData.reviewCount = 0;
      await db.collection("venues").add(venueData);
      imported++;
    }
  }

  return { imported, updated, skipped, total: dataRows.length };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets → Firestore インポート (ガジェット) 共通ロジック
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 比較用: Firestore のデータとシートのデータが同じかチェック
function isGadgetDataEqual(existing, sheetData) {
  const fields = ["name", "category", "amazonUrl", "amazonAffiliateUrl", "rakutenAffiliateUrl", "imageUrl", "memo"];
  for (const f of fields) {
    if ((existing[f] || "") !== (sheetData[f] || "")) return false;
  }
  return true;
}

async function doImportGadgets() {
  const rows = await sheetsRead(GADGET_SHEET_ID, "ガジェット一覧!A:K");
  if (rows.length < 2) return { imported: 0, updated: 0, skipped: 0, total: 0 };

  const db = admin.firestore();
  const dataRows = rows.slice(1);
  let imported = 0;
  let updated = 0;
  let skipped = 0;

  // searchId → Firebase UID のマッピングを事前に構築
  const usersSnap = await db.collection("users").get();
  const searchIdToUid = {};
  for (const uDoc of usersSnap.docs) {
    const sId = (uDoc.data().searchId || "").trim();
    if (sId) searchIdToUid[sId] = uDoc.id;
    // Firebase UID でも引けるようにフォールバック
    searchIdToUid[uDoc.id] = uDoc.id;
  }

  for (const row of dataRows) {
    const gadgetId = (row[0] || "").trim();
    const userIdOrSearchId = (row[1] || "").trim();
    const name = (row[3] || "").trim();
    if (!userIdOrSearchId || !name) { skipped++; continue; }

    // searchId または Firebase UID からユーザーを解決
    const resolvedUid = searchIdToUid[userIdOrSearchId];
    if (!resolvedUid) { skipped++; continue; }

    const gadgetData = {
      name,
      category: row[4] || "カテゴリなし",
      amazonUrl: row[5] || "",
      amazonAffiliateUrl: row[6] || "",
      rakutenAffiliateUrl: row[7] || "",
      imageUrl: row[8] || "",
      memo: row[9] || "",
    };

    const userRef = db.collection("users").doc(resolvedUid);

    if (gadgetId) {
      const existing = await userRef.collection("gadgets").doc(gadgetId).get();
      if (existing.exists) {
        // データが変わっていなければスキップ（無限ループ防止）
        if (isGadgetDataEqual(existing.data(), gadgetData)) { skipped++; continue; }
        gadgetData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        await userRef.collection("gadgets").doc(gadgetId).update(gadgetData);
        updated++;
      } else {
        gadgetData.id = gadgetId;
        gadgetData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        gadgetData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        await userRef.collection("gadgets").doc(gadgetId).set(gadgetData);
        imported++;
      }
    } else {
      gadgetData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      gadgetData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      const newDoc = await userRef.collection("gadgets").add(gadgetData);
      // Flutter側と同じく、ドキュメントIDをフィールドとしても保存
      await newDoc.update({ id: newDoc.id });
      imported++;
    }
  }

  return { imported, updated, skipped, total: dataRows.length };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HTTP エンドポイント (手動トリガー用)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.importVenuesFromSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const result = await doImportVenues();
    res.json({ success: true, ...result });
  } catch (e) {
    console.error("Venue import error:", e);
    res.status(500).json({ error: e.message });
  }
});

exports.importGadgetsFromSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const result = await doImportGadgets();
    res.json({ success: true, ...result });
  } catch (e) {
    console.error("Gadget import error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// スケジュール実行: シート → Firestore 自動同期 (5分毎)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.scheduledImportVenues = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    try {
      const result = await doImportVenues();
      console.log("Scheduled venue import:", JSON.stringify(result));
    } catch (e) {
      console.error("Scheduled venue import error:", e.message);
    }
  });

exports.scheduledImportGadgets = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    try {
      const result = await doImportGadgets();
      console.log("Scheduled gadget import:", JSON.stringify(result));
    } catch (e) {
      console.error("Scheduled gadget import error:", e.message);
    }
  });
