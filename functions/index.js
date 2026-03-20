const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
// v3: totalResults対応 + CI自動デプロイ

admin.initializeApp();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Google Sheets 連携設定 (googleapis不使用 — 直接REST API)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const GADGET_SHEET_ID = "1IITgU-IvD1xpIqig0MtnlMfQAsoGWcwtbcPLKkNwv60";
const VENUE_SHEET_ID = "1HNRinSk-Bk_NdekTLiZ8cOhhgVWs4CV4KvRdnYUKtFk";
const PRIZE_SHEET_ID = "1p2WXADT519w65qk3wZ_Nrz5jQUDMyy0V7J0gKe4gBC4";

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
        <a href="https://sofvo-19d84.web.app/welcome" style="color:#2E5C8A;font-size:14px;font-weight:bold;text-decoration:none">詳しくはこちら &rarr;</a>
      </p>
      <div style="text-align:center;margin:0 0 8px">
        <a href="https://sofvo-19d84.web.app" style="background-color:#1B3A5C;color:#ffffff;text-decoration:none;padding:14px 48px;border-radius:8px;font-size:15px;font-weight:bold;display:inline-block">Sofvo を開く</a>
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

// ── テスト送信用（管理者のみ） ──
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
