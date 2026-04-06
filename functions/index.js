const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
// Cloud Functions v1
const nodemailer = require("nodemailer");
// v5: 投稿いいね/コメント数 + フォロー数 + タイムラインいいね数の自動更新 Cloud Functions 追加

admin.initializeApp();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets 連携設定 (googleapis不使用 — 直接REST API)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const GADGET_SHEET_ID = "1rOmyJWIwLnosJkJmM0Z6QMNGwem0qkt2BSUlZ1w5Aw4";
const VENUE_SHEET_ID = "1fAx4y_kVF526f-F9wm9FsE9hNKA3Ddn8fa2SRjB7hPs";
const PRIZE_SHEET_ID = "1oKPuTyyK0xQHE6h-9FAYe5MH52j3Eroe3WuKCChJInE";

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

  // 金額取得: DisplayAmount → Amount(数値)からフォーマット
  let price =
    item.Offers?.Listings?.[0]?.Price?.DisplayAmount ||
    item.Offers?.Summaries?.[0]?.LowestPrice?.DisplayAmount ||
    item.Offers?.Summaries?.[0]?.HighestPrice?.DisplayAmount ||
    null;

  // DisplayAmountがない場合、Amount(数値)から生成
  if (!price) {
    const amount =
      item.Offers?.Listings?.[0]?.Price?.Amount ||
      item.Offers?.Summaries?.[0]?.LowestPrice?.Amount ||
      item.Offers?.Summaries?.[0]?.HighestPrice?.Amount;
    const currency =
      item.Offers?.Listings?.[0]?.Price?.Currency ||
      item.Offers?.Summaries?.[0]?.LowestPrice?.Currency ||
      "JPY";
    if (amount != null) {
      price = currency === "JPY"
        ? `￥${Number(amount).toLocaleString()}`
        : `${currency} ${amount}`;
    }
  }

  return {
    asin,
    title: info.Title?.DisplayValue || "",
    imageUrl:
      images.Primary?.Large?.URL ||
      images.Primary?.Medium?.URL ||
      "",
    detailPageUrl: `https://www.amazon.co.jp/dp/${asin}`,
    affiliateUrl: makeAffiliateUrl(asin),
    price,
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

  // 検索結果の総件数をHTMLテキストからregexで抽出
  let totalResults = 0;
  // Amazon.co.jp patterns:
  //   "1,000以上の結果" / "10,000 以上の結果"
  //   "1-48 of over 1,000 results" / "of 500 results"
  //   "1,000件中" / "500 件の結果"
  const countPatterns = [
    /([\d,，]+)\s*以上の結果/,
    /([\d,，]+)\s*件以上の結果/,
    /([\d,，]+)\s*件中/,
    /([\d,，]+)\s*件の結果/,
    /of\s+over\s+([\d,]+)\s+result/,
    /of\s+([\d,]+)\s+result/,
    />([\d,，]+)\s*以上</, // inside HTML tags
    />([\d,，]+)\s*件</,
  ];
  for (const pat of countPatterns) {
    const m = html.match(pat);
    if (m) {
      totalResults = parseInt(m[1].replace(/[,，]/g, ""), 10);
      if (totalResults > 0) break;
    }
  }
  console.log(`[scrapeAmazonSearch] Extracted totalResults=${totalResults} from HTML`);

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

  const sliced = items.slice(0, 10);
  // totalResultsが取れなかった場合はアイテム数をフォールバック
  if (totalResults === 0) totalResults = sliced.length;
  console.log(`[scrapeAmazonSearch] Parsed ${items.length} items, totalResults=${totalResults} from HTML (length: ${html.length})`);
  return { items: sliced, totalResults };
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
  res.set("X-Function-Version", "v4");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const keyword = req.query.q;
  const page = parseInt(req.query.page) || 1;
  if (!keyword) {
    res.status(400).json({ error: "Missing query parameter: q" });
    return;
  }

  // 認証情報の有無をログ出力
  const hasCredentials = hasPaapiCredentials();
  console.log(`[amazonSearch] keyword="${keyword}", page=${page}, hasPaapiCredentials=${hasCredentials}`);

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
          "Offers.Listings.MerchantInfo",
          "Offers.Listings.Condition",
          "Offers.Summaries.LowestPrice",
          "Offers.Summaries.HighestPrice",
        ],
        SearchIndex: "All",
        ItemCount: 10,
        ItemPage: page,
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
        const totalResults = data.SearchResult?.TotalResultCount || items.length;
        console.log(`[amazonSearch] PA-API success: ${items.length} items, totalResults=${totalResults}, raw offers sample:`,
          JSON.stringify(data.SearchResult?.Items?.[0]?.Offers || "no-offers").substring(0, 200));

        // PA-APIで価格が取れないアイテムがある場合、並行してスクレイピングで価格補完を試行
        const itemsNeedingPrice = items.filter(i => !i.price);
        if (itemsNeedingPrice.length > 0) {
          console.log(`[amazonSearch] ${itemsNeedingPrice.length} items without price, trying scraping supplement...`);
          try {
            const scraped = await scrapeAmazonSearch(keyword);
            const priceMap = {};
            for (const si of scraped.items) {
              if (si.price) priceMap[si.asin] = si.price;
            }
            for (const item of items) {
              if (!item.price && priceMap[item.asin]) {
                item.price = priceMap[item.asin];
              }
            }
            console.log(`[amazonSearch] Price supplemented for ${Object.keys(priceMap).length} items via scraping`);
          } catch (e) {
            console.warn(`[amazonSearch] Scraping price supplement failed: ${e.message}`);
          }
        }

        res.json({ totalResults, items });
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
    const scraped = await scrapeAmazonSearch(keyword);
    console.log(`[amazonSearch] Scraping success: ${scraped.items.length} items, totalResults=${scraped.totalResults}`);
    res.json({ totalResults: scraped.totalResults, items: scraped.items });
  } catch (scrapeError) {
    console.error(`[amazonSearch] Scraping also failed: ${scrapeError.message}`);
    // エラーでも空を返す（UIで手動入力を促す）
    res.json({ totalResults: 0, items: [] });
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
          "Offers.Listings.MerchantInfo",
          "Offers.Listings.Condition",
          "Offers.Summaries.LowestPrice",
          "Offers.Summaries.HighestPrice",
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
          const result = extractItem(items[0]);
          // PA-APIで価格が取れなかった場合、スクレイピングで価格だけ補完
          if (!result.price) {
            try {
              const scraped = await scrapeAmazonProduct(asin);
              if (scraped.price) {
                result.price = scraped.price;
                console.log(`[amazonProduct] Price supplemented by scraping: ${scraped.price}`);
              }
            } catch (e) {
              console.warn(`[amazonProduct] Price scraping supplement failed: ${e.message}`);
            }
          }
          res.json(result);
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
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  // Firebase Auth トークン検証（管理者のみアクセス可能）
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ error: "Authentication required" });
    return;
  }
  try {
    await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
  } catch (e) {
    res.status(403).json({ error: "Invalid or expired token" });
    return;
  }

  const result = {
    credentials: {
      hasAccessKey: !!process.env.AMAZON_ACCESS_KEY,
      hasSecretKey: !!process.env.AMAZON_SECRET_KEY,
      hasPartnerTag: !!process.env.AMAZON_PARTNER_TAG,
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
        Resources: [
          "ItemInfo.Title",
          "Offers.Listings.Price",
          "Offers.Summaries.LowestPrice",
          "Offers.Summaries.HighestPrice",
        ],
        Condition: "New",
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
      const firstItem = data.SearchResult?.Items?.[0];
      result.paapiTest = {
        status: response.status,
        ok: response.ok,
        itemCount: data.SearchResult?.Items?.length || 0,
        error: data.Errors ? data.Errors.map(e => e.Message).join("; ") : null,
        hasOffers: !!firstItem?.Offers,
        offersData: firstItem?.Offers ? JSON.stringify(firstItem.Offers).substring(0, 500) : "no offers returned",
        rawSnippet: JSON.stringify(data).substring(0, 500),
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

async function doSyncGadgetsToSheet() {
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

  try {
    await sheetsUpdate(GADGET_SHEET_ID, `${sheetName}!A1`, values);
  } catch (e) {
    await sheetsAddSheet(GADGET_SHEET_ID, sheetName);
    await sheetsUpdate(GADGET_SHEET_ID, `${sheetName}!A1`, values);
  }
  const nextRow = values.length + 1;
  await sheetsClear(GADGET_SHEET_ID, `${sheetName}!A${nextRow}:K10000`);

  return allGadgets.length;
}

exports.syncGadgetsToSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const count = await doSyncGadgetsToSheet();
    res.json({ success: true, count });
  } catch (e) {
    console.error("Gadget sync error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 会場 → Google Sheets 同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async function doSyncVenuesToSheet() {
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
      v.hasToilet ? "あり" : "なし",
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

  try {
    await sheetsUpdate(VENUE_SHEET_ID, `${sheetName}!A1`, values);
  } catch (e) {
    await sheetsAddSheet(VENUE_SHEET_ID, sheetName);
    await sheetsUpdate(VENUE_SHEET_ID, `${sheetName}!A1`, values);
  }
  const nextRow = values.length + 1;
  await sheetsClear(VENUE_SHEET_ID, `${sheetName}!A${nextRow}:T10000`);

  return venueRows.length;
}

exports.syncVenuesToSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const count = await doSyncVenuesToSheet();
    res.json({ success: true, count });
  } catch (e) {
    console.error("Venue sync error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 会場データ全クリア（Firestore + Sheets）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.clearVenues = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  // Firebase Auth トークン検証（破壊的操作のため認証必須）
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ error: "Authentication required" });
    return;
  }
  try {
    await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
  } catch (e) {
    res.status(403).json({ error: "Invalid or expired token" });
    return;
  }

  try {
    const db = admin.firestore();

    // 1. Firestore の venues コレクションを全削除
    const venuesSnap = await db.collection("venues").get();
    const batch = db.batch();
    venuesSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    const deletedCount = venuesSnap.size;

    // 2. Google Sheets の会場一覧シートをヘッダーだけ残してクリア
    const sheetName = "会場一覧";
    await sheetsClear(VENUE_SHEET_ID, `${sheetName}!A2:T10000`);

    console.log(`Cleared ${deletedCount} venues from Firestore and Sheets`);
    res.json({ success: true, deletedFromFirestore: deletedCount });
  } catch (e) {
    console.error("Clear venues error:", e);
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
// Firestore トリガー: ユーザープロフィール変更時にガジェットシート再同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onUserWrite = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    if (!change.before.exists || !change.after.exists) return;
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;

    const nicknameChanged = (before.nickname || "") !== (after.nickname || "");
    const avatarChanged = (before.avatarUrl || "") !== (after.avatarUrl || "");

    // searchId または nickname が変わった場合のみシート再同期
    if (nicknameChanged || (before.searchId || "") !== (after.searchId || "")) {
      try {
        const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
        const syncUrl = `https://us-central1-${projectId}.cloudfunctions.net/syncGadgetsToSheet`;
        const ac = new AbortController();
        const tid = setTimeout(() => ac.abort(), 30000);
        await fetch(syncUrl, { method: "POST", signal: ac.signal }).finally(() => clearTimeout(tid));
      } catch (e) {
        console.warn("Auto user-profile gadget sync failed (non-critical):", e.message);
      }
    }

    // ニックネームまたはアバターが変わった場合、非正規化データを同期
    if (!nicknameChanged && !avatarChanged) return;

    const db = admin.firestore();
    const newNickname = after.nickname || "";
    const newAvatar = after.avatarUrl || "";

    try {
      // 1. フォロワーの following サブコレクション内の自分のドキュメントを更新
      const followersSnap = await db.collection("users").doc(userId).collection("followers").get();
      const batch1 = db.batch();
      for (const doc of followersSnap.docs) {
        batch1.update(db.collection("users").doc(doc.id).collection("following").doc(userId), {
          nickname: newNickname, avatarUrl: newAvatar,
        });
      }
      if (followersSnap.docs.length > 0) await batch1.commit();

      // 2. フォロー先の followers サブコレクション内の自分のドキュメントを更新
      const followingSnap = await db.collection("users").doc(userId).collection("following").get();
      const batch2 = db.batch();
      for (const doc of followingSnap.docs) {
        batch2.update(db.collection("users").doc(doc.id).collection("followers").doc(userId), {
          nickname: newNickname, avatarUrl: newAvatar,
        });
      }
      if (followingSnap.docs.length > 0) await batch2.commit();

      // 3. 自分の投稿の userNickname / userAvatarUrl を更新
      const postsSnap = await db.collection("posts").where("userId", "==", userId).get();
      if (postsSnap.docs.length > 0) {
        const batch3 = db.batch();
        for (const doc of postsSnap.docs) {
          batch3.update(doc.ref, { userNickname: newNickname, userAvatarUrl: newAvatar });
        }
        await batch3.commit();
      }

      // 4. 主催大会の organizerName を更新
      if (nicknameChanged) {
        const tournsSnap = await db.collection("tournaments").where("organizerId", "==", userId).get();
        if (tournsSnap.docs.length > 0) {
          const batch4 = db.batch();
          for (const doc of tournsSnap.docs) {
            batch4.update(doc.ref, { organizerName: newNickname });
          }
          await batch4.commit();
        }
      }

      console.log(`[UserSync] Synced nickname/avatar for user ${userId}`);
    } catch (e) {
      console.warn(`[UserSync] Failed to sync denormalized data for ${userId}:`, e.message);
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
      const numFields = ["courts", "parking"];
      const boolFields = ["hasToilet", "hasChangeRoom", "hasShower", "hasGallery", "hasAC"];
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
  const numFields = ["courts", "parking"];
  for (const f of numFields) {
    if ((existing[f] || 0) !== (sheetData[f] || 0)) return false;
  }
  const boolFields = ["hasToilet", "hasChangeRoom", "hasShower", "hasGallery", "hasAC"];
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
      hasToilet: (row[7] || "").trim() === "あり",
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

exports.scheduledSyncVenues = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    // シート → Firestore インポート
    try {
      const importResult = await doImportVenues();
      console.log("Scheduled venue import:", JSON.stringify(importResult));
    } catch (e) {
      console.error("Scheduled venue import error:", e.message);
    }
    // Firestore → シート エクスポート
    try {
      const count = await doSyncVenuesToSheet();
      console.log("Scheduled venue sync:", count, "venues");
    } catch (e) {
      console.error("Scheduled venue sync error:", e.message);
    }
  });

exports.scheduledSyncGadgets = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    // シート → Firestore インポート
    try {
      const importResult = await doImportGadgets();
      console.log("Scheduled gadget import:", JSON.stringify(importResult));
    } catch (e) {
      console.error("Scheduled gadget import error:", e.message);
    }
    // Firestore → シート エクスポート
    try {
      const count = await doSyncGadgetsToSheet();
      console.log("Scheduled gadget sync:", count, "gadgets");
    } catch (e) {
      console.error("Scheduled gadget sync error:", e.message);
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 景品データ Firestore → Google Sheets 同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

async function doSyncPrizesToSheet() {
  const prizesSnap = await admin.firestore().collection("prizes")
    .orderBy("name").get();

  const prizeRows = prizesSnap.docs.map((doc) => {
    const p = doc.data();
    return [
      doc.id,
      p.name || "",
      p.category || "",
      p.priceRange || "",
      p.amazonUrl || "",
      p.amazonAffiliateUrl || "",
      p.imageUrl || "",
      p.memo || "",
      p.registeredBy || "",
      p.createdAt ? p.createdAt.toDate().toISOString().split("T")[0] : "",
      typeof p.rating === "number" ? p.rating.toFixed(1) : "0",
      typeof p.reviewCount === "number" ? String(p.reviewCount) : "0",
    ];
  });

  const sheetName = "景品一覧";
  const values = [
    ["景品ID", "景品名", "カテゴリ", "価格帯", "AmazonURL", "アフィリエイトURL", "画像URL", "メモ", "登録者", "登録日", "評価", "レビュー数"],
    ...prizeRows,
  ];

  try {
    await sheetsUpdate(PRIZE_SHEET_ID, `${sheetName}!A1`, values);
  } catch (e) {
    await sheetsAddSheet(PRIZE_SHEET_ID, sheetName);
    await sheetsUpdate(PRIZE_SHEET_ID, `${sheetName}!A1`, values);
  }
  const nextRow = values.length + 1;
  await sheetsClear(PRIZE_SHEET_ID, `${sheetName}!A${nextRow}:L10000`);

  return prizeRows.length;
}

exports.syncPrizesToSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const count = await doSyncPrizesToSheet();
    res.json({ success: true, count });
  } catch (e) {
    console.error("Prize sync error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Firestore トリガー: 景品変更時に自動同期
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.onPrizeWrite = functions.firestore
  .document("prizes/{prizeId}")
  .onWrite(async (change) => {
    if (change.before.exists && change.after.exists) {
      const before = change.before.data();
      const after = change.after.data();
      const fields = ["name", "category", "priceRange", "amazonUrl", "amazonAffiliateUrl", "imageUrl", "memo", "rating", "reviewCount"];
      const changed = fields.some((f) => String(before[f] || "") !== String(after[f] || ""));
      if (!changed) return;
    }
    try {
      const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
      const syncUrl = `https://us-central1-${projectId}.cloudfunctions.net/syncPrizesToSheet`;
      const ac = new AbortController();
      const tid = setTimeout(() => ac.abort(), 30000);
      await fetch(syncUrl, { method: "POST", signal: ac.signal }).finally(() => clearTimeout(tid));
    } catch (e) {
      console.warn("Auto prize sync failed (non-critical):", e.message);
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets → Firestore インポート (景品) 共通ロジック
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function isPrizeDataEqual(existing, sheetData) {
  const fields = ["name", "category", "priceRange", "amazonUrl", "amazonAffiliateUrl", "imageUrl", "memo"];
  for (const f of fields) {
    if ((existing[f] || "") !== (sheetData[f] || "")) return false;
  }
  return true;
}

async function doImportPrizes() {
  const rows = await sheetsRead(PRIZE_SHEET_ID, "景品一覧!A:L");
  if (rows.length < 2) return { imported: 0, updated: 0, skipped: 0, total: 0 };

  const db = admin.firestore();
  const dataRows = rows.slice(1);
  let imported = 0;
  let updated = 0;
  let skipped = 0;

  for (const row of dataRows) {
    const prizeId = (row[0] || "").trim();
    const name = (row[1] || "").trim();
    if (!name) { skipped++; continue; }

    const prizeData = {
      name,
      category: row[2] || "",
      priceRange: row[3] || "",
      amazonUrl: row[4] || "",
      amazonAffiliateUrl: row[5] || "",
      imageUrl: row[6] || "",
      memo: row[7] || "",
    };

    if (prizeId) {
      const existing = await db.collection("prizes").doc(prizeId).get();
      if (existing.exists) {
        if (isPrizeDataEqual(existing.data(), prizeData)) { skipped++; continue; }
        prizeData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await db.collection("prizes").doc(prizeId).update(prizeData);
        updated++;
      } else {
        prizeData.createdAt = admin.firestore.FieldValue.serverTimestamp();
        prizeData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        prizeData.registeredBy = "sheet_import";
        await db.collection("prizes").doc(prizeId).set(prizeData);
        imported++;
      }
    } else {
      prizeData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      prizeData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      prizeData.registeredBy = "sheet_import";
      await db.collection("prizes").add(prizeData);
      imported++;
    }
  }

  return { imported, updated, skipped, total: dataRows.length };
}

exports.importPrizesFromSheet = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const result = await doImportPrizes();
    res.json({ success: true, ...result });
  } catch (e) {
    console.error("Prize import error:", e);
    res.status(500).json({ error: e.message });
  }
});

exports.scheduledSyncPrizes = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    try {
      const importResult = await doImportPrizes();
      console.log("Scheduled prize import:", JSON.stringify(importResult));
    } catch (e) {
      console.error("Scheduled prize import error:", e.message);
    }
    try {
      const count = await doSyncPrizesToSheet();
      console.log("Scheduled prize sync:", count, "prizes");
    } catch (e) {
      console.error("Scheduled prize sync error:", e.message);
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// トーナメントポイント自動付与
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 順位係数
function rankMultiplier(rank) {
  switch (rank) {
    case 1: return 3.0;
    case 2: return 2.0;
    case 3: return 1.5;
    case 4: return 1.2;
    default: return 1.0;
  }
}

function calcRankPoints(teamCount, rank) {
  return Math.round(teamCount * rankMultiplier(rank));
}

function calcOrganizerBonus(teamCount) {
  return Math.round(teamCount * 0.3);
}

function calcStreakBonus(streak) {
  if (streak >= 4) return 15;
  if (streak >= 3) return 10;
  if (streak >= 2) return 5;
  return 0;
}

/**
 * 大会のステータスが「終了」に変わったらポイントを自動付与
 */
exports.onTournamentStatusChange = functions.firestore
  .document("tournaments/{tournamentId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // ステータスが「終了」に変わった場合のみ実行
    if (before.status === "終了" || after.status !== "終了") return null;
    // 二重付与防止
    if (after.pointsAwarded === true) return null;

    const db = admin.firestore();
    const tournamentId = context.params.tournamentId;
    const teamCount = after.currentTeams || 0;
    if (teamCount === 0) return null;

    const organizerId = after.organizerId || "";
    const tournamentName = after.title || after.name || "";
    const tournamentDate = after.date || "";

    console.log(`[Points] Awarding points for tournament: ${tournamentName} (${tournamentId}), teams: ${teamCount}`);

    // エントリーデータ取得
    const entriesSnap = await db.collection("tournaments").doc(tournamentId).collection("entries").get();
    const userTeamMap = {};  // uid -> teamId
    const teamUserMap = {};  // teamId -> [uids]

    for (const doc of entriesSnap.docs) {
      const data = doc.data();
      const teamId = data.teamId || doc.id;
      if (!teamUserMap[teamId]) teamUserMap[teamId] = [];

      // memberUids から取得（通常エントリー）
      if (data.memberUids && Array.isArray(data.memberUids)) {
        for (const uid of data.memberUids) {
          if (uid) {
            userTeamMap[uid] = teamId;
            teamUserMap[teamId].push(uid);
          }
        }
      }
      // leaderUid から取得（CSV登録でも設定される場合がある）
      if (data.leaderUid) {
        userTeamMap[data.leaderUid] = teamId;
        if (!teamUserMap[teamId].includes(data.leaderUid)) {
          teamUserMap[teamId].push(data.leaderUid);
        }
      }
      // enteredBy から取得
      if (data.enteredBy) {
        userTeamMap[data.enteredBy] = teamId;
        if (!teamUserMap[teamId].includes(data.enteredBy)) {
          teamUserMap[teamId].push(data.enteredBy);
        }
      }
    }

    const allUserIds = Object.keys(userTeamMap);

    // ━━━ 順位取得（ブラケットから） ━━━
    const teamRanks = {};
    const bracketsSnap = await db.collection("tournaments").doc(tournamentId).collection("brackets").get();

    for (const bDoc of bracketsSnap.docs) {
      const matchesSnap = await bDoc.ref.collection("matches")
        .where("status", "==", "completed").get();

      for (const mDoc of matchesSnap.docs) {
        const mData = mDoc.data();
        const result = mData.result || {};

        if ((mData.round === "final" || mData.round === "final_1st") && result.winner) {
          teamRanks[result.winner] = 1;
          const loserId = result.winner === mData.teamAId ? mData.teamBId : mData.teamAId;
          if (loserId) teamRanks[loserId] = 2;
        }

        if ((mData.round === "third_place" || mData.round === "final_3rd") && result.winner) {
          teamRanks[result.winner] = 3;
          const loserId = result.winner === mData.teamAId ? mData.teamBId : mData.teamAId;
          if (loserId) teamRanks[loserId] = 4;
        }

        if (mData.round === "final_5th" && result.winner) {
          teamRanks[result.winner] = 5;
          const loserId = result.winner === mData.teamAId ? mData.teamBId : mData.teamAId;
          if (loserId) teamRanks[loserId] = 6;
        }

        if (mData.round === "final_7th" && result.winner) {
          teamRanks[result.winner] = 7;
          const loserId = result.winner === mData.teamAId ? mData.teamBId : mData.teamAId;
          if (loserId) teamRanks[loserId] = 8;
        }
      }
    }

    // ━━━ ポイント付与 ━━━
    const batch = db.batch();
    const now = new Date();
    const season = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1; // 4月始まり

    const userPointData = {};

    for (const uid of allUserIds) {
      const teamId = userTeamMap[uid];
      const rank = teamRanks[teamId] || 99;
      const rankPoints = calcRankPoints(teamCount, rank);
      const totalEarned = rankPoints;

      const userRef = db.collection("users").doc(uid);
      batch.update(userRef, {
        totalPoints: admin.firestore.FieldValue.increment(totalEarned),
        seasonPoints: admin.firestore.FieldValue.increment(totalEarned),
        "stats.tournamentsPlayed": admin.firestore.FieldValue.increment(1),
        ...(rank === 1 ? { "stats.championships": admin.firestore.FieldValue.increment(1) } : {}),
      });

      // ポイント履歴
      const historyRef = userRef.collection("pointHistory").doc(tournamentId);
      batch.set(historyRef, {
        tournamentId,
        tournamentName,
        date: tournamentDate,
        teamCount,
        rank: rank <= 4 ? rank : null,
        rankPoints,
        streakBonus: 0,
        organizerBonus: 0,
        totalEarned,
        season,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      userPointData[uid] = { totalEarned, rank: rank <= 4 ? rank : null };

      // 通知
      const rankNames = { 1: "優勝", 2: "準優勝", 3: "3位", 4: "4位" };
      const detail = rank <= 4 ? `（${rankNames[rank]}）` : "";

      const notifRef = userRef.collection("notifications").doc();
      batch.set(notifRef, {
        type: "points_earned",
        senderId: "system",
        senderName: "ポイント獲得",
        message: `「${tournamentName}」で +${totalEarned}pt 獲得！${detail}`,
        tournamentId,
        points: totalEarned,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // ━━━ 主催者ボーナス ━━━
    if (organizerId) {
      const orgBonus = calcOrganizerBonus(teamCount);
      const userRef = db.collection("users").doc(organizerId);
      batch.update(userRef, {
        totalPoints: admin.firestore.FieldValue.increment(orgBonus),
        seasonPoints: admin.firestore.FieldValue.increment(orgBonus),
        "stats.tournamentsHosted": admin.firestore.FieldValue.increment(1),
      });

      const historyRef = userRef.collection("pointHistory").doc(tournamentId);
      if (userPointData[organizerId]) {
        // 参加者かつ主催者 → 履歴を更新
        batch.update(historyRef, {
          organizerBonus: orgBonus,
          totalEarned: admin.firestore.FieldValue.increment(orgBonus),
        });
      } else {
        // 主催者のみ（参加していない）
        batch.set(historyRef, {
          tournamentId,
          tournamentName,
          date: tournamentDate,
          teamCount,
          rank: null,
          rankPoints: 0,
          streakBonus: 0,
          organizerBonus: orgBonus,
          totalEarned: orgBonus,
          isOrganizer: true,
          season,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // 主催者通知
      const notifRef = userRef.collection("notifications").doc();
      batch.set(notifRef, {
        type: "points_earned",
        senderId: "system",
        senderName: "ポイント獲得",
        message: `「${tournamentName}」の主催ボーナス +${orgBonus}pt 獲得！`,
        tournamentId,
        points: orgBonus,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 二重付与防止フラグ
    batch.update(change.after.ref, { pointsAwarded: true });

    await batch.commit();
    console.log(`[Points] Awarded points to ${allUserIds.length} users for tournament ${tournamentId}`);

    // ━━━ ストリークボーナス（バッチ外で個別実行） ━━━
    // 期間ベース: 前回参加から30日以内なら連続、30日空いたらリセット
    const STREAK_WINDOW_DAYS = 30;
    for (const uid of allUserIds) {
      try {
        // 今回含む直近の履歴を日付降順で取得
        const histSnap = await db.collection("users").doc(uid)
          .collection("pointHistory")
          .orderBy("createdAt", "desc")
          .limit(20)
          .get();

        // 連続参加カウント（期間ベース）
        let streak = 1; // 今回の参加で最低1
        const docs = histSnap.docs;
        for (let i = 0; i < docs.length - 1; i++) {
          const current = docs[i].data().createdAt;
          const prev = docs[i + 1].data().createdAt;
          if (!current || !prev) break;
          const diffMs = current.toMillis() - prev.toMillis();
          const diffDays = diffMs / (1000 * 60 * 60 * 24);
          if (diffDays <= STREAK_WINDOW_DAYS) {
            streak++;
          } else {
            break;
          }
        }

        const streakBonus = calcStreakBonus(streak);

        if (streakBonus > 0) {
          await db.collection("users").doc(uid).update({
            totalPoints: admin.firestore.FieldValue.increment(streakBonus),
            seasonPoints: admin.firestore.FieldValue.increment(streakBonus),
            streak,
          });
          await db.collection("users").doc(uid)
            .collection("pointHistory").doc(tournamentId)
            .update({
              streakBonus,
              totalEarned: admin.firestore.FieldValue.increment(streakBonus),
            });
        } else {
          await db.collection("users").doc(uid).update({ streak });
        }
      } catch (e) {
        console.error(`[Points] Streak update error for ${uid}:`, e.message);
      }
    }

    return null;
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// フォロワー/フォロイング数の再計算（一括修正）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.recalcFollowCounts = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  try {
    const db = admin.firestore();
    const usersSnap = await db.collection("users").get();
    let updated = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const data = userDoc.data();

      // サブコレクションの実際のドキュメント数をカウント
      const followersSnap = await db.collection("users").doc(uid).collection("followers").get();
      const followingSnap = await db.collection("users").doc(uid).collection("following").get();

      // 存在しないユーザーを指すドキュメントを除外してカウント
      let validFollowers = 0;
      const followerDeleteBatch = db.batch();
      let hasFollowerDeletes = false;
      for (const fDoc of followersSnap.docs) {
        const followerRef = db.collection("users").doc(fDoc.id);
        const followerUser = await followerRef.get();
        if (followerUser.exists) {
          validFollowers++;
        } else {
          // 削除済みユーザーのフォロワードキュメントを削除
          followerDeleteBatch.delete(fDoc.ref);
          hasFollowerDeletes = true;
        }
      }

      let validFollowing = 0;
      const followingDeleteBatch = db.batch();
      let hasFollowingDeletes = false;
      for (const fDoc of followingSnap.docs) {
        const followingRef = db.collection("users").doc(fDoc.id);
        const followingUser = await followingRef.get();
        if (followingUser.exists) {
          validFollowing++;
        } else {
          // 削除済みユーザーのフォローイングドキュメントを削除
          followingDeleteBatch.delete(fDoc.ref);
          hasFollowingDeletes = true;
        }
      }

      // 削除済みユーザーのドキュメントをクリーンアップ
      if (hasFollowerDeletes) await followerDeleteBatch.commit();
      if (hasFollowingDeletes) await followingDeleteBatch.commit();

      // カウントが一致しない場合のみ更新
      const currentFollowers = data.followersCount || 0;
      const currentFollowing = data.followingCount || 0;

      if (currentFollowers !== validFollowers || currentFollowing !== validFollowing) {
        await db.collection("users").doc(uid).update({
          followersCount: validFollowers,
          followingCount: validFollowing,
        });
        updated++;
        console.log(`[RecalcFollow] ${uid}: followers ${currentFollowers}->${validFollowers}, following ${currentFollowing}->${validFollowing}`);
      }
    }

    res.json({ success: true, totalUsers: usersSnap.size, updated });
  } catch (e) {
    console.error("RecalcFollow error:", e);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 登録完了メール送信（プロフィール設定完了時）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ── onCreate: ドキュメント作成時に profileCompleted: true なら送信 ──
exports.sendWelcomeEmail = functions.firestore
  .document("users/{uid}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data.profileCompleted) return null;

    const uid = context.params.uid;
    let email;
    try {
      const userRecord = await admin.auth().getUser(uid);
      email = userRecord.email;
    } catch (e) {
      console.error("[WelcomeEmail] Failed to get user:", e.message);
      return null;
    }
    if (!email) return null;

    const nickname = data.nickname || "ユーザー";

    try {
      await sendWelcomeMailTo(email, nickname);
      await snap.ref.update({ welcomeEmailSent: true });
      console.log(`[WelcomeEmail] Sent to ${email} (onCreate)`);
    } catch (e) {
      console.error("[WelcomeEmail] Send failed:", e.message);
    }
    return null;
  });

// ── onUpdate: profileCompleted が false→true に変わったら送信 ──
exports.sendWelcomeEmailOnUpdate = functions.firestore
  .document("users/{uid}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // profileCompleted が false/未設定 → true に変わった時だけ
    if (before.profileCompleted || !after.profileCompleted) return null;
    // 既にウェルカムメール送信済みならスキップ
    if (after.welcomeEmailSent) return null;

    const uid = context.params.uid;
    let email;
    try {
      const userRecord = await admin.auth().getUser(uid);
      email = userRecord.email;
    } catch (e) {
      console.error("[WelcomeEmail] Failed to get user:", e.message);
      return null;
    }
    if (!email) return null;

    const nickname = after.nickname || "ユーザー";

    try {
      await sendWelcomeMailTo(email, nickname);
      // 重複送信防止フラグ
      await change.after.ref.update({ welcomeEmailSent: true });
      console.log(`[WelcomeEmail] Sent to ${email} (onUpdate)`);
    } catch (e) {
      console.error("[WelcomeEmail] Send failed:", e.message);
    }
    return null;
  });

// ── ウェルカムメール送信の共通関数 ──
async function sendWelcomeMailTo(email, nickname) {
  const gmailUser = process.env.GMAIL_USER || functions.config().gmail?.user;
  const gmailPass = process.env.GMAIL_PASS || functions.config().gmail?.pass;
  if (!gmailUser || !gmailPass) throw new Error("Gmail credentials not configured");

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user: gmailUser, pass: gmailPass },
  });

  await transporter.sendMail({
    from: `Sofvo <info@sofvo.com>`,
    to: email,
    subject: "Sofvoへようこそ！登録が完了しました",
    html: `
<div style="background-color:#f7f7f7;padding:40px 0;font-family:'Helvetica Neue',Arial,sans-serif">
  <div style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08)">
    <div style="background:linear-gradient(135deg,#1B3A5C,#2E5C8A);padding:32px;text-align:center">
      <h1 style="margin:0;font-size:32px;letter-spacing:3px">
        <span style="color:#ffffff;font-weight:900">Sof</span><span style="color:#C4A962;font-weight:900">vo</span>
      </h1>
      <p style="color:rgba(255,255,255,0.7);margin:8px 0 0;font-size:13px;letter-spacing:1px">ソフトバレーボール マッチングアプリ</p>
    </div>
    <div style="padding:32px">
      <h2 style="color:#1B3A5C;font-size:18px;margin:0 0 16px">${nickname}さん、ようこそ！</h2>
      <p style="color:#6B6B6B;font-size:14px;line-height:1.8;margin:0 0 24px">
        Sofvo へのご登録ありがとうございます。<br>
        アカウントの登録が完了しました。
      </p>
      <table style="width:100%;border-collapse:collapse;margin:0 0 20px">
        <tr>
          <td style="padding:10px 14px;border-bottom:1px solid #f0f0f0;vertical-align:top;width:32px"><span style="font-size:18px">&#x1F3D0;</span></td>
          <td style="padding:10px 14px;border-bottom:1px solid #f0f0f0;color:#6B6B6B;font-size:13px;line-height:1.6"><strong style="color:#1B3A5C">大会をさがす</strong> &ndash; お近くの大会を検索してエントリー</td>
        </tr>
        <tr>
          <td style="padding:10px 14px;border-bottom:1px solid #f0f0f0;vertical-align:top;width:32px"><span style="font-size:18px">&#x1F4AC;</span></td>
          <td style="padding:10px 14px;border-bottom:1px solid #f0f0f0;color:#6B6B6B;font-size:13px;line-height:1.6"><strong style="color:#1B3A5C">タイムライン</strong> &ndash; プレイヤーの投稿をチェック＆共有</td>
        </tr>
        <tr>
          <td style="padding:10px 14px;vertical-align:top;width:32px"><span style="font-size:18px">&#x1F91D;</span></td>
          <td style="padding:10px 14px;color:#6B6B6B;font-size:13px;line-height:1.6"><strong style="color:#1B3A5C">仲間とつながる</strong> &ndash; フォローして情報を共有</td>
        </tr>
      </table>
      <p style="text-align:center;margin:0 0 24px">
        <a href="https://sofvo.com/welcome" style="color:#2E5C8A;font-size:14px;font-weight:bold;text-decoration:none">詳しくはこちら &rarr;</a>
      </p>
      <div style="text-align:center;margin:0 0 8px">
        <a href="https://sofvo.com" style="background-color:#1B3A5C;color:#ffffff;text-decoration:none;padding:14px 48px;border-radius:8px;font-size:15px;font-weight:bold;display:inline-block">Sofvo を開く</a>
      </div>
      <p style="color:#B0B0B0;font-size:12px;line-height:1.6;margin:24px 0 0;border-top:1px solid #eee;padding-top:16px">
        このメールに心当たりがない場合は、このメールを無視してください。
      </p>
    </div>
    <div style="background:#f7f7f7;padding:16px;text-align:center">
      <p style="color:#B0B0B0;font-size:11px;margin:0">&copy; 2026 Sofvo. All rights reserved.</p>
    </div>
  </div>
</div>
    `,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// アカウント削除完了メール送信
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exports.sendAccountDeletedEmail = functions.firestore
  .document("users/{uid}")
  .onDelete(async (snap, context) => {
    const data = snap.data();
    const uid = context.params.uid;

    // Firestoreドキュメント削除時点ではAuth userはまだ存在する
    // （deleteAccount()ではuserRef.delete()の後にuser.delete()を呼ぶため）
    let email;
    try {
      const authUser = await admin.auth().getUser(uid);
      email = authUser.email;
    } catch (e) {
      // Auth userが既に削除済み or 存在しない場合はスキップ
      console.log(`[DeleteEmail] Auth user not found for ${uid}, skipping`);
      return null;
    }

    if (!email) return null;

    const nickname = data.nickname || "ユーザー";

    try {
      await sendAccountDeletedMailTo(email, nickname);
      console.log(`[DeleteEmail] Sent to ${email}`);
    } catch (e) {
      console.error("[DeleteEmail] Send failed:", e.message);
    }
    return null;
  });

// ── アカウント削除メール送信の共通関数 ──
async function sendAccountDeletedMailTo(email, nickname) {
  const gmailUser = process.env.GMAIL_USER || functions.config().gmail?.user;
  const gmailPass = process.env.GMAIL_PASS || functions.config().gmail?.pass;
  if (!gmailUser || !gmailPass) throw new Error("Gmail credentials not configured");

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user: gmailUser, pass: gmailPass },
  });

  await transporter.sendMail({
    from: `Sofvo <info@sofvo.com>`,
    to: email,
    subject: "アカウント削除が完了しました - Sofvo",
    html: `
<div style="background-color:#f7f7f7;padding:40px 0;font-family:'Helvetica Neue',Arial,sans-serif">
  <div style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08)">
    <div style="background:linear-gradient(135deg,#1B3A5C,#2E5C8A);padding:32px;text-align:center">
      <h1 style="margin:0;font-size:32px;letter-spacing:3px">
        <span style="color:#ffffff;font-weight:900">Sof</span><span style="color:#C4A962;font-weight:900">vo</span>
      </h1>
      <p style="color:rgba(255,255,255,0.7);margin:8px 0 0;font-size:13px;letter-spacing:1px">ソフトバレーボール マッチングアプリ</p>
    </div>
    <div style="padding:32px">
      <h2 style="color:#1B3A5C;font-size:18px;margin:0 0 16px">${nickname}さん</h2>
      <p style="color:#6B6B6B;font-size:14px;line-height:1.8;margin:0 0 24px">
        Sofvo のアカウント削除が完了しました。<br>
        ご利用いただきありがとうございました。
      </p>
      <div style="background:#f8f9fa;border-radius:8px;padding:20px;margin:0 0 24px">
        <p style="color:#6B6B6B;font-size:13px;line-height:1.8;margin:0">
          <strong style="color:#1B3A5C">削除された情報：</strong><br>
          ・プロフィール情報<br>
          ・投稿・コメント・いいね<br>
          ・フォロー・フォロワー情報<br>
          ・大会のエントリー情報
        </p>
      </div>
      <p style="color:#6B6B6B;font-size:14px;line-height:1.8;margin:0 0 24px">
        またいつでもお戻りいただけます。<br>
        新しいアカウントで再登録が可能です。
      </p>
      <div style="text-align:center;margin:0 0 8px">
        <a href="https://sofvo.com" style="background-color:#1B3A5C;color:#ffffff;text-decoration:none;padding:14px 48px;border-radius:8px;font-size:15px;font-weight:bold;display:inline-block">Sofvo を開く</a>
      </div>
      <p style="color:#B0B0B0;font-size:12px;line-height:1.6;margin:24px 0 0;border-top:1px solid #eee;padding-top:16px">
        このメールに心当たりがない場合は、このメールを無視してください。<br>
        ご不明な点がございましたら、お気軽にお問い合わせください。
      </p>
    </div>
    <div style="background:#f7f7f7;padding:16px;text-align:center">
      <p style="color:#B0B0B0;font-size:11px;margin:0">&copy; 2026 Sofvo. All rights reserved.</p>
    </div>
  </div>
</div>
    `,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// エントリー追加時に currentTeams を自動インクリメント
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onEntryCreated = functions.firestore
  .document("tournaments/{tournamentId}/entries/{entryId}")
  .onCreate(async (snap, context) => {
    const tournamentId = context.params.tournamentId;
    const db = admin.firestore();
    await db.collection("tournaments").doc(tournamentId).update({
      currentTeams: admin.firestore.FieldValue.increment(1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// エントリー削除時に currentTeams を自動デクリメント
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onEntryDeleted = functions.firestore
  .document("tournaments/{tournamentId}/entries/{entryId}")
  .onDelete(async (snap, context) => {
    const tournamentId = context.params.tournamentId;
    const db = admin.firestore();
    await db.collection("tournaments").doc(tournamentId).update({
      currentTeams: admin.firestore.FieldValue.increment(-1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 全大会の currentTeams を entries 数から再計算して修復
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.repairCurrentTeams = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const tournamentsSnap = await db.collection("tournaments").get();
  let fixed = 0;

  for (const doc of tournamentsSnap.docs) {
    const entriesSnap = await db.collection("tournaments").doc(doc.id).collection("entries").get();
    const actual = entriesSnap.size;
    const current = doc.data().currentTeams || 0;

    if (actual !== current) {
      await db.collection("tournaments").doc(doc.id).update({ currentTeams: actual });
      fixed++;
      console.log(`Fixed ${doc.id}: ${current} -> ${actual}`);
    }
  }

  res.json({ message: `Repaired ${fixed} tournaments`, total: tournamentsSnap.size });
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 投稿いいね数の自動更新
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onPostLikeCreated = functions.firestore
  .document("posts/{postId}/likes/{likeId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("posts").doc(context.params.postId).update({
      likesCount: admin.firestore.FieldValue.increment(1),
    });
  });

exports.onPostLikeDeleted = functions.firestore
  .document("posts/{postId}/likes/{likeId}")
  .onDelete(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("posts").doc(context.params.postId).update({
      likesCount: admin.firestore.FieldValue.increment(-1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 投稿コメント数の自動更新
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onPostCommentCreated = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("posts").doc(context.params.postId).update({
      commentsCount: admin.firestore.FieldValue.increment(1),
    });
  });

exports.onPostCommentDeleted = functions.firestore
  .document("posts/{postId}/comments/{commentId}")
  .onDelete(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("posts").doc(context.params.postId).update({
      commentsCount: admin.firestore.FieldValue.increment(-1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 大会タイムラインいいね数の自動更新
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onTimelineLikeCreated = functions.firestore
  .document("tournaments/{tournamentId}/timeline/{postId}/likes/{likeId}")
  .onCreate(async (snap, context) => {
    const { tournamentId, postId } = context.params;
    const db = admin.firestore();
    await db.collection("tournaments").doc(tournamentId)
      .collection("timeline").doc(postId).update({
        likesCount: admin.firestore.FieldValue.increment(1),
      });
  });

exports.onTimelineLikeDeleted = functions.firestore
  .document("tournaments/{tournamentId}/timeline/{postId}/likes/{likeId}")
  .onDelete(async (snap, context) => {
    const { tournamentId, postId } = context.params;
    const db = admin.firestore();
    await db.collection("tournaments").doc(tournamentId)
      .collection("timeline").doc(postId).update({
        likesCount: admin.firestore.FieldValue.increment(-1),
      });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// フォロワー数の自動更新
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onFollowerCreated = functions.firestore
  .document("users/{userId}/followers/{followerId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("users").doc(context.params.userId).update({
      followersCount: admin.firestore.FieldValue.increment(1),
    });
  });

exports.onFollowerDeleted = functions.firestore
  .document("users/{userId}/followers/{followerId}")
  .onDelete(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("users").doc(context.params.userId).update({
      followersCount: admin.firestore.FieldValue.increment(-1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// フォロー数の自動更新
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onFollowingCreated = functions.firestore
  .document("users/{userId}/following/{followId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("users").doc(context.params.userId).update({
      followingCount: admin.firestore.FieldValue.increment(1),
    });
  });

exports.onFollowingDeleted = functions.firestore
  .document("users/{userId}/following/{followId}")
  .onDelete(async (snap, context) => {
    const db = admin.firestore();
    await db.collection("users").doc(context.params.userId).update({
      followingCount: admin.firestore.FieldValue.increment(-1),
    });
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ポイント付与（サーバーサイド）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.distributePoints = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "ログインが必要です");

  const { tournamentId, tournamentName, userPoints } = data;
  if (!tournamentId || !userPoints || !Array.isArray(userPoints)) {
    throw new functions.https.HttpsError("invalid-argument", "パラメータが不正です");
  }

  // 主催者権限チェック
  const db = admin.firestore();
  const tournDoc = await db.collection("tournaments").doc(tournamentId).get();
  if (!tournDoc.exists) throw new functions.https.HttpsError("not-found", "大会が見つかりません");
  const tournData = tournDoc.data();
  const isOrganizer = tournData.organizerId === context.auth.uid;
  const isEditor = (tournData.editors || []).includes(context.auth.uid);
  if (!isOrganizer && !isEditor) {
    throw new functions.https.HttpsError("permission-denied", "権限がありません");
  }

  const batch = db.batch();
  for (const entry of userPoints) {
    const { uid, rankPoints, rank } = entry;
    const userRef = db.collection("users").doc(uid);
    const updateData = {
      totalPoints: admin.firestore.FieldValue.increment(rankPoints),
      seasonPoints: admin.firestore.FieldValue.increment(rankPoints),
      "stats.tournamentsPlayed": admin.firestore.FieldValue.increment(1),
    };
    if (rank === 1) updateData["stats.championships"] = admin.firestore.FieldValue.increment(1);
    batch.update(userRef, updateData);

    const historyRef = userRef.collection("pointHistory").doc(tournamentId);
    batch.set(historyRef, {
      tournamentId,
      tournamentName: tournamentName || "",
      rankPoints,
      totalEarned: rankPoints,
      rank: rank <= 3 ? rank : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  return { success: true, updated: userPoints.length };
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 大会作成時にフォロワーへ通知
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onTournamentCreate = functions.firestore
  .document("tournaments/{tournamentId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    const data = snap.data();
    const organizerId = data.organizerId || "";
    const tournamentName = data.title || "";
    const tournamentId = context.params.tournamentId;

    if (!organizerId || !tournamentName) return null;

    // 主催者のフォロワー一覧を取得
    const followersSnap = await db
      .collection("users").doc(organizerId)
      .collection("followers").get();

    if (followersSnap.empty) return null;

    // 主催者のアバター取得
    const userDoc = await db.collection("users").doc(organizerId).get();
    const userData = userDoc.data() || {};
    const organizerName = userData.nickname || userData.displayName || "";
    const organizerAvatar = userData.avatarUrl || "";

    // フォロワーに通知を送信（バッチ上限500件ずつ）
    const followerIds = followersSnap.docs.map((d) => d.id);
    const batchSize = 450;
    for (let i = 0; i < followerIds.length; i += batchSize) {
      const batch = db.batch();
      const chunk = followerIds.slice(i, i + batchSize);
      for (const followerId of chunk) {
        const ref = db.collection("users").doc(followerId)
          .collection("notifications").doc();
        batch.set(ref, {
          type: "tournament_created",
          senderId: organizerId,
          senderName: organizerName,
          senderAvatar: organizerAvatar,
          message: `${organizerName}さんが「${tournamentName}」の募集を開始しました`,
          tournamentId: tournamentId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    console.log(`[TournamentCreated] Notified ${followerIds.length} followers of ${organizerName}'s tournament: ${tournamentName}`);
    return null;
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 保存した大会の締切接近 & 残り枠通知（毎日9時に実行）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.checkBookmarkAlerts = functions.pubsub
  .schedule("0 9 * * *")
  .timeZone("Asia/Tokyo")
  .onRun(async () => {
    const db = admin.firestore();

    // 募集中の大会を取得
    const tournamentsSnap = await db.collection("tournaments")
      .where("status", "==", "募集中")
      .get();

    if (tournamentsSnap.empty) return null;

    const now = new Date();
    const todayStr = `${now.getFullYear()}/${String(now.getMonth() + 1).padStart(2, "0")}/${String(now.getDate()).padStart(2, "0")}`;

    for (const tDoc of tournamentsSnap.docs) {
      const t = tDoc.data();
      const tournamentId = tDoc.id;
      const tournamentName = t.title || "";
      const deadline = t.deadline || "";
      const maxTeams = t.maxTeams || 0;
      const currentTeams = t.currentTeams || 0;
      const remaining = maxTeams - currentTeams;

      // 締切日までの残り日数を計算
      let daysLeft = -1;
      if (deadline) {
        const deadlineDate = new Date(deadline.replace(/\//g, "-"));
        const diffMs = deadlineDate.getTime() - now.getTime();
        daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
      }

      const shouldNotifyDeadline = daysLeft >= 0 && daysLeft <= 3;
      const shouldNotifySlots = remaining > 0 && remaining <= 2;

      if (!shouldNotifyDeadline && !shouldNotifySlots) continue;

      // この大会をブックマークしているユーザーを検索
      const usersSnap = await db.collectionGroup("bookmarks")
        .where("targetId", "==", tournamentId)
        .where("type", "==", "tournament")
        .get();

      if (usersSnap.empty) continue;

      const batch = db.batch();
      let count = 0;

      for (const bDoc of usersSnap.docs) {
        // パスから userId を取得: users/{uid}/bookmarks/{docId}
        const userId = bDoc.ref.parent.parent.id;
        const alerts = bDoc.data().alerts || [];

        // 締切通知（まだ送っていない場合）
        if (shouldNotifyDeadline && !alerts.includes("deadline")) {
          const ref = db.collection("users").doc(userId)
            .collection("notifications").doc();
          const msg = daysLeft === 0
            ? `「${tournamentName}」のエントリー締切は本日です！`
            : `「${tournamentName}」のエントリー締切まであと${daysLeft}日です`;
          batch.set(ref, {
            type: "deadline_approaching",
            senderId: "system",
            senderName: "システム",
            senderAvatar: "",
            message: msg,
            tournamentId: tournamentId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          // alerts に deadline を追加して二重送信防止
          batch.update(bDoc.ref, {
            alerts: admin.firestore.FieldValue.arrayUnion("deadline"),
          });
          count++;
        }

        // 残り枠通知（まだ送っていない場合）
        if (shouldNotifySlots && !alerts.includes("slots")) {
          const ref = db.collection("users").doc(userId)
            .collection("notifications").doc();
          batch.set(ref, {
            type: "slots_low",
            senderId: "system",
            senderName: "システム",
            senderAvatar: "",
            message: `「${tournamentName}」の残り枠があと${remaining}チームです！`,
            tournamentId: tournamentId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          batch.update(bDoc.ref, {
            alerts: admin.firestore.FieldValue.arrayUnion("slots"),
          });
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        console.log(`[BookmarkAlerts] ${tournamentName}: sent ${count} notifications`);
      }
    }

    return null;
  });

// ── テスト送信用（管理者のみ） ──
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 招待ページ用: 公開プロフィール取得（未認証OK）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.getPublicProfile = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const uid = req.query.uid;
  if (!uid) { res.status(400).json({error: "uid is required"}); return; }

  try {
    const doc = await admin.firestore().collection("users").doc(uid).get();
    if (!doc.exists) { res.status(404).json({error: "user not found"}); return; }
    const data = doc.data();
    res.json({
      nickname: data.nickname || null,
      avatarUrl: data.avatarUrl || null,
    });
  } catch (e) {
    res.status(500).json({error: e.message});
  }
});

exports.testWelcomeEmail = functions.https.onRequest(async (req, res) => {
  try {
    const email = req.body.email || req.query.email;
    const nickname = req.body.nickname || req.query.nickname || "テストユーザー";
    if (!email) {
      res.status(400).json({ error: "email が必要です" });
      return;
    }

    await sendWelcomeMailTo(email, nickname);
    res.json({ success: true, message: `${email} に送信しました` });
  } catch (e) {
    console.error("[testWelcomeEmail] Error:", e.message);
    res.status(500).json({ error: e.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// フォロー数の自動更新（Firestoreトリガー）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// followers サブコレクションが作成された → followersCount +1
exports.onFollowerCreated = functions.firestore
  .document("users/{userId}/followers/{followerId}")
  .onCreate(async (snap, context) => {
    const { userId } = context.params;
    try {
      await admin.firestore().collection("users").doc(userId).update({
        followersCount: admin.firestore.FieldValue.increment(1),
      });
    } catch (e) {
      console.error(`[onFollowerCreated] ${userId}: ${e.message}`);
    }
  });

// followers サブコレクションが削除された → followersCount -1
exports.onFollowerDeleted = functions.firestore
  .document("users/{userId}/followers/{followerId}")
  .onDelete(async (snap, context) => {
    const { userId } = context.params;
    try {
      await admin.firestore().collection("users").doc(userId).update({
        followersCount: admin.firestore.FieldValue.increment(-1),
      });
    } catch (e) {
      console.error(`[onFollowerDeleted] ${userId}: ${e.message}`);
    }
  });

// following サブコレクションが作成された → followingCount +1
exports.onFollowingCreated = functions.firestore
  .document("users/{userId}/following/{followId}")
  .onCreate(async (snap, context) => {
    const { userId } = context.params;
    try {
      await admin.firestore().collection("users").doc(userId).update({
        followingCount: admin.firestore.FieldValue.increment(1),
      });
    } catch (e) {
      console.error(`[onFollowingCreated] ${userId}: ${e.message}`);
    }
  });

// following サブコレクションが削除された → followingCount -1
exports.onFollowingDeleted = functions.firestore
  .document("users/{userId}/following/{followId}")
  .onDelete(async (snap, context) => {
    const { userId } = context.params;
    try {
      await admin.firestore().collection("users").doc(userId).update({
        followingCount: admin.firestore.FieldValue.increment(-1),
      });
    } catch (e) {
      console.error(`[onFollowingDeleted] ${userId}: ${e.message}`);
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// サンプルデータ投入（App Store 審査用）
// firebase functions:shell → seedReviewData()
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.seedReviewData = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const TEST_UID = "nRE9MEEBq2YNGRNIqCiMe66x8ah1";

  // ── ダミーユーザー（主催者・投稿者として使う）──
  const dummyUsers = [
    { uid: "dummy_user_001", nickname: "バレー太郎", area: "東京都", experience: "5〜10年", searchId: "volley_taro", bio: "ソフトバレー歴8年。週末は都内で活動中！" },
    { uid: "dummy_user_002", nickname: "スパイク花子", area: "神奈川県", experience: "3〜5年", searchId: "spike_hanako", bio: "横浜でチーム運営してます。初心者歓迎！" },
    { uid: "dummy_user_003", nickname: "レシーブ次郎", area: "大阪府", experience: "10年以上", searchId: "receive_jiro", bio: "関西のソフトバレー仲間を探しています。" },
    { uid: "dummy_user_004", nickname: "トス美咲", area: "愛知県", experience: "1〜3年", searchId: "toss_misaki", bio: "名古屋で初心者チームを作りました！" },
    { uid: "dummy_user_005", nickname: "サーブ健太", area: "福岡県", experience: "3〜5年", searchId: "serve_kenta", bio: "福岡でソフトバレーを楽しんでます。" },
  ];

  for (const u of dummyUsers) {
    await db.collection("users").doc(u.uid).set({
      uid: u.uid,
      nickname: u.nickname,
      area: u.area,
      experience: u.experience,
      searchId: u.searchId,
      bio: u.bio,
      avatarUrl: "",
      totalPoints: Math.floor(Math.random() * 500) + 100,
      seasonPoints: Math.floor(Math.random() * 200) + 50,
      followersCount: Math.floor(Math.random() * 30) + 5,
      followingCount: Math.floor(Math.random() * 20) + 3,
      profileCompleted: true,
      stats: {
        tournamentsPlayed: Math.floor(Math.random() * 15) + 3,
        tournamentsHosted: Math.floor(Math.random() * 5),
        wins: Math.floor(Math.random() * 20) + 5,
        losses: Math.floor(Math.random() * 15) + 2,
        championships: Math.floor(Math.random() * 3),
        helperCount: Math.floor(Math.random() * 5),
      },
      createdAt: now,
      updatedAt: now,
    }, { merge: true });
  }

  // ── テストユーザーのプロフィールを充実 ──
  await db.collection("users").doc(TEST_UID).update({
    totalPoints: 320,
    seasonPoints: 150,
    followersCount: 8,
    followingCount: 5,
    stats: {
      tournamentsPlayed: 6,
      tournamentsHosted: 0,
      wins: 12,
      losses: 8,
      championships: 1,
      helperCount: 2,
    },
    updatedAt: now,
  });

  // ── 大会データ（6件）──
  const tournaments = [
    {
      title: "第12回 東京ソフトバレーボール交流大会",
      date: "2026/04/20",
      location: "東京体育館",
      venueAddress: "東京都渋谷区千駄ヶ谷1-17-1",
      area: "東京都",
      type: "混合",
      description: "初心者から経験者まで楽しめる交流大会です。試合後に懇親会も予定しています。お気軽にご参加ください！",
      status: "募集中",
      organizerId: "dummy_user_001",
      organizerName: "バレー太郎",
      icon: "emoji_events",
      maxTeams: 16,
      currentTeams: 10,
      entryFee: 3000,
      courts: 3,
      openTime: "08:30",
      receptionTime: "09:00",
      matchStartTime: "09:30",
      finalTime: "15:00",
      closingTime: "16:00",
    },
    {
      title: "横浜カップ 春季ソフトバレー大会",
      date: "2026/04/27",
      location: "横浜文化体育館",
      venueAddress: "神奈川県横浜市中区不老町2-7",
      area: "神奈川県",
      type: "混合",
      description: "横浜エリア最大級のソフトバレー大会！チーム戦で白熱の試合を楽しもう。",
      status: "募集中",
      organizerId: "dummy_user_002",
      organizerName: "スパイク花子",
      icon: "sports_volleyball",
      maxTeams: 24,
      currentTeams: 18,
      entryFee: 4000,
      courts: 4,
      openTime: "08:00",
      receptionTime: "08:30",
      matchStartTime: "09:00",
      finalTime: "16:00",
      closingTime: "17:00",
    },
    {
      title: "関西ソフトバレーフェスティバル",
      date: "2026/05/05",
      location: "大阪市中央体育館",
      venueAddress: "大阪府大阪市港区田中3-1-40",
      area: "大阪府",
      type: "混合",
      description: "GW特別企画！関西のソフトバレー愛好家が集まるお祭りイベント。初心者大歓迎！",
      status: "募集中",
      organizerId: "dummy_user_003",
      organizerName: "レシーブ次郎",
      icon: "celebration",
      maxTeams: 20,
      currentTeams: 12,
      entryFee: 3500,
      courts: 3,
      openTime: "09:00",
      receptionTime: "09:30",
      matchStartTime: "10:00",
      finalTime: "16:00",
      closingTime: "17:00",
    },
    {
      title: "名古屋初心者ソフトバレー体験会",
      date: "2026/05/11",
      location: "名古屋市スポーツセンター",
      venueAddress: "愛知県名古屋市中区栄1-25-10",
      area: "愛知県",
      type: "混合",
      description: "ソフトバレー未経験者・初心者向けの体験イベントです。道具は全て無料貸出！",
      status: "募集中",
      organizerId: "dummy_user_004",
      organizerName: "トス美咲",
      icon: "school",
      maxTeams: 12,
      currentTeams: 5,
      entryFee: 1500,
      courts: 2,
      openTime: "10:00",
      receptionTime: "10:15",
      matchStartTime: "10:30",
      finalTime: "14:00",
      closingTime: "15:00",
    },
    {
      title: "福岡ソフトバレーリーグ 第3節",
      date: "2026/05/18",
      location: "福岡市総合体育館",
      venueAddress: "福岡県福岡市東区香椎照葉6-1-1",
      area: "福岡県",
      type: "混合",
      description: "福岡リーグ戦の第3節です。リーグポイントを賭けた真剣勝負！",
      status: "募集中",
      organizerId: "dummy_user_005",
      organizerName: "サーブ健太",
      icon: "leaderboard",
      maxTeams: 8,
      currentTeams: 7,
      entryFee: 2500,
      courts: 2,
      openTime: "09:00",
      receptionTime: "09:15",
      matchStartTime: "09:30",
      finalTime: "15:00",
      closingTime: "15:30",
    },
    {
      title: "第5回 全日本シニアソフトバレー選手権",
      date: "2026/04/13",
      location: "代々木第二体育館",
      venueAddress: "東京都渋谷区神南2-1-1",
      area: "東京都",
      type: "混合",
      description: "全国から集まったシニアチームの大会です。熱い戦いが繰り広げられました！",
      status: "終了",
      organizerId: "dummy_user_001",
      organizerName: "バレー太郎",
      icon: "emoji_events",
      maxTeams: 32,
      currentTeams: 32,
      entryFee: 5000,
      courts: 6,
      openTime: "08:00",
      receptionTime: "08:30",
      matchStartTime: "09:00",
      finalTime: "16:00",
      closingTime: "17:00",
    },
  ];

  const tournamentIds = [];
  for (const t of tournaments) {
    const ref = await db.collection("tournaments").add({
      ...t,
      entryTeamIds: [],
      rules: {},
      createdAt: now,
      updatedAt: now,
    });
    tournamentIds.push({ id: ref.id, ...t });
  }

  // ── メンバー募集（4件）──
  const recruitments = [
    {
      tournamentId: tournamentIds[0].id,
      tournamentName: tournamentIds[0].title,
      tournamentDate: tournamentIds[0].date,
      userId: "dummy_user_001",
      nickname: "バレー太郎",
      experience: "5〜10年",
      recruitCount: 2,
      comment: "東京交流大会に一緒に出ませんか？あと2人募集中です。初心者でもOK！楽しくやりましょう！",
      status: "募集中",
      needed: 2,
      approvedCount: 0,
      pendingCount: 1,
    },
    {
      tournamentId: tournamentIds[1].id,
      tournamentName: tournamentIds[1].title,
      tournamentDate: tournamentIds[1].date,
      userId: "dummy_user_002",
      nickname: "スパイク花子",
      experience: "3〜5年",
      recruitCount: 1,
      comment: "横浜カップに出場予定！セッターができる方を1名探しています。女性歓迎です！",
      status: "募集中",
      needed: 1,
      approvedCount: 0,
      pendingCount: 0,
    },
    {
      tournamentId: tournamentIds[2].id,
      tournamentName: tournamentIds[2].title,
      tournamentDate: tournamentIds[2].date,
      userId: "dummy_user_003",
      nickname: "レシーブ次郎",
      experience: "10年以上",
      recruitCount: 3,
      comment: "GWの関西フェスに参加します！チームメンバー3名募集。経験不問、楽しめる方大歓迎！",
      status: "募集中",
      needed: 3,
      approvedCount: 1,
      pendingCount: 0,
    },
    {
      tournamentId: tournamentIds[3].id,
      tournamentName: tournamentIds[3].title,
      tournamentDate: tournamentIds[3].date,
      userId: "dummy_user_004",
      nickname: "トス美咲",
      experience: "1〜3年",
      recruitCount: 4,
      comment: "名古屋の体験会、一緒に参加しませんか？初心者チームなので気軽に来てください！",
      status: "募集中",
      needed: 4,
      approvedCount: 2,
      pendingCount: 1,
    },
  ];

  for (const r of recruitments) {
    await db.collection("recruitments").add({
      ...r,
      avatarUrl: "",
      createdAt: now,
      updatedAt: now,
    });
  }

  // ── 投稿（5件）──
  const posts = [
    {
      userId: "dummy_user_001",
      userNickname: "バレー太郎",
      userAvatarUrl: "",
      text: "今日の練習、新しいフォーメーション試してみました！なかなか良い感じ。来週の大会が楽しみです💪",
      images: [],
      likesCount: 12,
      commentsCount: 3,
      autoGenerated: false,
    },
    {
      userId: "dummy_user_002",
      userNickname: "スパイク花子",
      userAvatarUrl: "",
      text: "横浜カップの会場下見してきました。きれいな体育館で設備も充実！参加チーム募集中なのでお気軽にどうぞ。",
      images: [],
      likesCount: 8,
      commentsCount: 2,
      autoGenerated: false,
    },
    {
      userId: "dummy_user_003",
      userNickname: "レシーブ次郎",
      userAvatarUrl: "",
      text: "GWの関西フェスティバル、続々エントリーいただいてます！残り枠わずかなのでお早めに〜",
      images: [],
      likesCount: 15,
      commentsCount: 5,
      autoGenerated: false,
    },
    {
      userId: "dummy_user_004",
      userNickname: "トス美咲",
      userAvatarUrl: "",
      text: "初心者チームで練習始めて3ヶ月、みんな上達してきてうれしい！名古屋で仲間増やしたいです。",
      images: [],
      likesCount: 20,
      commentsCount: 4,
      autoGenerated: false,
    },
    {
      userId: "dummy_user_005",
      userNickname: "サーブ健太",
      userAvatarUrl: "",
      text: "福岡リーグ第2節、チームが2位に入りました！次は優勝目指して頑張ります。応援よろしく！",
      images: [],
      likesCount: 25,
      commentsCount: 7,
      autoGenerated: false,
    },
  ];

  for (const p of posts) {
    await db.collection("posts").add({
      ...p,
      createdAt: now,
      updatedAt: now,
    });
  }

  // ── テストユーザーのフォロー関係 ──
  for (const u of dummyUsers.slice(0, 3)) {
    await db.collection("users").doc(TEST_UID).collection("following").doc(u.uid).set({
      uid: u.uid,
      nickname: u.nickname,
      createdAt: now,
    });
    await db.collection("users").doc(u.uid).collection("followers").doc(TEST_UID).set({
      uid: TEST_UID,
      createdAt: now,
    });
  }

  // ── テストユーザーのポイント履歴 ──
  const pointHistory = [
    { type: "tournament_participation", points: 50, description: "大会参加ポイント", tournamentName: "第5回 全日本シニアソフトバレー選手権" },
    { type: "tournament_participation", points: 50, description: "大会参加ポイント", tournamentName: "春季交流大会" },
    { type: "tournament_win", points: 100, description: "優勝ポイント", tournamentName: "春季交流大会" },
    { type: "daily_login", points: 10, description: "ログインボーナス" },
    { type: "profile_complete", points: 30, description: "プロフィール完成ボーナス" },
    { type: "first_follow", points: 20, description: "初フォローボーナス" },
  ];

  for (const ph of pointHistory) {
    await db.collection("users").doc(TEST_UID).collection("pointHistory").add({
      ...ph,
      createdAt: now,
    });
  }

  res.json({ success: true, message: "サンプルデータ投入完了", tournaments: tournamentIds.length, recruitments: recruitments.length, posts: posts.length });
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FCMプッシュ通知ヘルパー
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/**
 * ユーザーの通知設定を確認し、FCMトークンを取得
 * @param {string} userId - 送信先ユーザーID
 * @param {string} settingKey - notificationSettings内のキー (例: 'chat', 'follow')
 * @returns {Promise<string|null>} FCMトークン（通知OFF/トークンなしならnull）
 */
/**
 * ユーザーの通知設定を確認し、有効なFCMトークン一覧を返す
 * @returns {string[]} トークン配列（設定OFFまたはトークンなしの場合は空配列）
 */
async function getFcmTokensIfEnabled(userId, settingKey) {
  const db = admin.firestore();
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) return [];

  const settings = userDoc.data()?.notificationSettings || {};
  if (settings.push === false) return [];
  if (settingKey && settings[settingKey] === false) return [];

  const privateDoc = await db
    .collection("users").doc(userId)
    .collection("private").doc("info")
    .get();
  const data = privateDoc.data() || {};
  // 複数デバイス対応: fcmTokens配列を優先、なければfcmToken単体
  const tokens = data.fcmTokens || [];
  if (tokens.length > 0) return [...new Set(tokens)]; // 重複除去
  return data.fcmToken ? [data.fcmToken] : [];
}

// 後方互換: 単一トークンを返す旧API
async function getFcmTokenIfEnabled(userId, settingKey) {
  const tokens = await getFcmTokensIfEnabled(userId, settingKey);
  return tokens.length > 0 ? tokens[0] : null;
}

/**
 * 複数トークンにFCM送信 + 無効トークン自動削除
 */
async function sendFcmToTokens(tokens, payload) {
  if (tokens.length === 0) return;
  const db = admin.firestore();

  // ユーザーごとにバッジカウントをインクリメントしてから送信
  const results = await Promise.allSettled(
    tokens.map(async (t) => {
      // badgeCount をインクリメント
      const privateRef = db.collection("users").doc(t.userId)
        .collection("private").doc("info");
      await privateRef.set(
        { badgeCount: admin.firestore.FieldValue.increment(1) },
        { merge: true }
      );
      const privateDoc = await privateRef.get();
      const badgeCount = privateDoc.data()?.badgeCount || 1;

      const enrichedPayload = {
        ...payload,
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: payload.notification?.title || "",
                body: payload.notification?.body || "",
              },
              badge: badgeCount,
              sound: "default",
              "mutable-content": 1,
            },
          },
          ...(payload.apns || {}),
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "chat_messages",
            ...(payload.android?.notification || {}),
          },
          ...(payload.android || {}),
        },
      };
      return admin.messaging().send({ ...enrichedPayload, token: t.token });
    })
  );

  for (let i = 0; i < results.length; i++) {
    if (results[i].status === "rejected") {
      const error = results[i].reason;
      if (
        error?.code === "messaging/registration-token-not-registered" ||
        error?.code === "messaging/invalid-registration-token"
      ) {
        const invalidToken = tokens[i].token;
        await db
          .collection("users").doc(tokens[i].userId)
          .collection("private").doc("info")
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove([invalidToken]),
          })
          .catch(() => {});
      }
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// チャットメッセージ送信時のプッシュ通知
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onChatMessageCreated = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const { chatId } = context.params;
    const message = snap.data();
    const senderId = message.senderId;
    const senderName = message.senderName || "ユーザー";
    const type = message.type || "text";

    let body;
    if (type === "image") {
      body = "📷 画像を送信しました";
    } else if (type === "file") {
      body = `📎 ${message.fileName || "ファイル"}`;
    } else {
      body = (message.text || "").substring(0, 100);
    }
    if (!body) return null;

    const db = admin.firestore();
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) return null;
    const chatData = chatDoc.data();
    const members = chatData.members || [];
    const chatType = chatData.type || "dm";
    const chatName = chatData.name || "";

    // unreadCountの更新はクライアント側で送信時にincrementしているため、ここでは行わない

    const tokens = [];
    for (const memberId of members) {
      if (memberId === senderId) continue;
      // ミュートチェック
      const mutedDoc = await db.collection("users").doc(memberId).collection("mutedChats").doc(chatId).get();
      if (mutedDoc.exists) continue;
      const memberTokens = await getFcmTokensIfEnabled(memberId, "chat");
      for (const t of memberTokens) {
        tokens.push({ token: t, userId: memberId });
      }
    }

    const title = chatType === "dm" ? senderName : chatName;
    const notificationBody = chatType === "dm" ? body : `${senderName}: ${body}`;

    await sendFcmToTokens(tokens, {
      notification: { title, body: notificationBody },
      data: { type: "chat", targetId: chatId, chatType, senderId },
    });
    return null;
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// いいね通知のプッシュ通知
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onNotificationCreatedPush = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const { userId } = context.params;
    const data = snap.data();
    const notifType = data.type || "";
    const senderId = data.senderId || "";
    const senderName = data.senderName || "";
    const message = data.message || "";

    // 自分自身への通知はスキップ
    if (senderId === userId) return null;

    // 通知タイプ → 設定キーのマッピング
    const settingKeyMap = {
      like: "likeComment",
      comment: "likeComment",
      follow: "follow",
      tournament_announcement: "organizer",
      tournament_end: "tournament",
      waitlist_available: "tournament",
      points_earned: "tournament",
      tournament_created: "tournament",
      deadline_approaching: "reminder",
      slots_low: "tournament",
      official: "official",
      team_join: "team",
      team_leave: "team",
    };

    const settingKey = settingKeyMap[notifType];
    if (!settingKey) return null;

    const userTokens = await getFcmTokensIfEnabled(userId, settingKey);
    if (userTokens.length === 0) return null;

    // 通知タイトルの決定
    let title;
    switch (notifType) {
      case "like":
        title = "いいね";
        break;
      case "comment":
        title = "コメント";
        break;
      case "follow":
        title = "フォロー";
        break;
      case "tournament_announcement":
        title = "大会運営者からのお知らせ";
        break;
      case "tournament_end":
        title = "大会結果";
        break;
      case "waitlist_available":
        title = "空き通知";
        break;
      case "deadline_approaching":
        title = "リマインダー";
        break;
      case "official":
        title = "Sofvo公式";
        break;
      case "team_join":
      case "team_leave":
        title = "チーム";
        break;
      default:
        title = "Sofvo";
    }

    const body = senderName ? `${senderName}${message}` : message;

    // 遷移先データ
    const navData = { type: notifType };
    if (data.tournamentId) navData.tournamentId = data.tournamentId;
    if (data.postId) navData.targetId = data.postId;
    if (notifType === "follow" && senderId) navData.targetId = senderId;

    await sendFcmToTokens(
      userTokens.map((t) => ({ token: t, userId })),
      {
        notification: { title, body: body.substring(0, 100) },
        data: navData,
      }
    );
    return null;
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 大会前日リマインダー（毎日9:00 JST実行）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.sendTournamentReminders = functions.pubsub
  .schedule("0 0 * * *") // UTC 0:00 = JST 9:00
  .timeZone("Asia/Tokyo")
  .onRun(async () => {
    const db = admin.firestore();
    // 明日の日付を取得 (YYYY/MM/DD形式)
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const yyyy = tomorrow.getFullYear();
    const mm = String(tomorrow.getMonth() + 1).padStart(2, "0");
    const dd = String(tomorrow.getDate()).padStart(2, "0");
    const tomorrowStr = `${yyyy}/${mm}/${dd}`;

    // 明日開催の大会を取得
    const tournaments = await db.collection("tournaments")
      .where("date", "==", tomorrowStr)
      .where("status", "in", ["募集中", "締切"])
      .get();

    for (const tDoc of tournaments.docs) {
      const tData = tDoc.data();
      const tournamentName = tData.title || "大会";

      // 参加者を取得
      const entries = await tDoc.ref.collection("entries").get();
      const participantUids = new Set();
      for (const entry of entries.docs) {
        const eData = entry.data();
        if (Array.isArray(eData.memberUids)) {
          eData.memberUids.forEach((uid) => { if (uid) participantUids.add(uid); });
        }
        if (eData.enteredBy) participantUids.add(eData.enteredBy);
      }

      // 各参加者にリマインダー通知
      const batch = db.batch();
      for (const uid of participantUids) {
        const notifRef = db.collection("users").doc(uid).collection("notifications").doc();
        batch.set(notifRef, {
          type: "deadline_approaching",
          senderId: "system",
          senderName: "",
          senderAvatar: "",
          message: `明日は「${tournamentName}」の開催日です！`,
          tournamentId: tDoc.id,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    return null;
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Sofvo公式通知の送信（管理者用 Callable Function）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.sendOfficialNotification = functions.https.onCall(async (data, context) => {
  // 管理者チェック
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "ログインが必要です");
  const db = admin.firestore();
  const callerDoc = await db.collection("users").doc(context.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data()?.isAdmin !== true) {
    throw new functions.https.HttpsError("permission-denied", "管理者権限が必要です");
  }

  const { title, message } = data;
  if (!title || !message) {
    throw new functions.https.HttpsError("invalid-argument", "title と message は必須です");
  }

  // 全ユーザーに通知
  const usersSnap = await db.collection("users").get();
  let count = 0;
  const batchSize = 500;
  let batch = db.batch();

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    if (uid === context.auth.uid) continue;
    const notifRef = db.collection("users").doc(uid).collection("notifications").doc();
    batch.set(notifRef, {
      type: "official",
      senderId: "sofvo_official",
      senderName: "Sofvo公式",
      senderAvatar: "",
      message: `【${title}】${message}`,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    count++;
    if (count % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (count % batchSize !== 0) await batch.commit();

  return { success: true, sentCount: count };
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// お知らせ作成時に全ユーザーへFCMプッシュ通知（トピック送信）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
exports.onNoticeCreated = functions.firestore
  .document("notices/{noticeId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const title = data.title || "お知らせ";
    const body = (data.body || "").substring(0, 100);

    const message = {
      topic: "all_users",
      notification: {
        title,
        body,
      },
      data: {
        type: "notice",
        noticeId: context.params.noticeId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
      android: {
        notification: {
          sound: "default",
        },
      },
    };

    try {
      await admin.messaging().send(message);
      functions.logger.info(`Notice push sent to topic all_users: ${title}`);
    } catch (err) {
      functions.logger.error("Failed to send notice push:", err);
    }
    return null;
  });
