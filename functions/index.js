const functions = require("firebase-functions");
const crypto = require("crypto");
const fetch = require("node-fetch");

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Amazon PA-API v5 共通ヘルパー
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const PAAPI_HOST = "webservices.amazon.co.jp";
const PAAPI_REGION = "us-west-2";
const PAAPI_SERVICE = "ProductAdvertisingAPI";

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

  return {
    asin: item.ASIN || "",
    title: info.Title?.DisplayValue || "",
    imageUrl:
      images.Primary?.Large?.URL ||
      images.Primary?.Medium?.URL ||
      "",
    detailPageUrl: item.DetailPageURL || "",
    price:
      item.Offers?.Listings?.[0]?.Price?.DisplayAmount || null,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cloud Function: Amazon 商品キーワード検索
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

    if (!response.ok) {
      console.error("PA-API error:", JSON.stringify(data));
      res.status(response.status).json({
        error: data.Errors?.[0]?.Message || "PA-API request failed",
      });
      return;
    }

    const items = (data.SearchResult?.Items || []).map(extractItem);
    res.json(items);
  } catch (error) {
    console.error("amazonSearch error:", error);
    res.status(500).json({ error: error.message });
  }
});

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Cloud Function: ASIN で商品情報取得
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

    if (!response.ok) {
      console.error("PA-API error:", JSON.stringify(data));
      res.status(response.status).json({
        error: data.Errors?.[0]?.Message || "PA-API request failed",
      });
      return;
    }

    const items = data.ItemsResult?.Items || [];
    if (items.length === 0) {
      res.status(404).json({ error: "Product not found" });
      return;
    }

    res.json(extractItem(items[0]));
  } catch (error) {
    console.error("amazonProduct error:", error);
    res.status(500).json({ error: error.message });
  }
});
