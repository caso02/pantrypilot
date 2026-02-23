import tls from "node:tls";
import axios from "axios";
import { getEnv } from "../config/env.js";
import { withRetry } from "../utils/retry.js";
import type { MigrosProduct, MigrosSearchResult } from "./types.js";

const BASE_URL = "https://www.migros.ch";
const AUTH_URL = `${BASE_URL}/authentication/public/v1/api/guest`;
const SEARCH_URL = `${BASE_URL}/onesearch-oc-seaapi/public/v5/search`;
const PRODUCT_CARDS_URL = `${BASE_URL}/product-display/public/v4/product-cards`;

const USER_AGENT =
  "Mozilla/5.0 (X11; Linux x86_64; rv:144.0) Gecko/20100101 Firefox/144.0";

let cachedToken: string | undefined;
let tokenExpiresAt = 0;

/**
 * Forces TLS 1.3 during request to bypass Cloudflare fingerprinting,
 * same technique used by migros-api-wrapper.
 */
async function tlsBypassGet(
  url: string,
  headers: Record<string, string>
): Promise<{ data: any; headers: Record<string, any> }> {
  const prev = tls.DEFAULT_MIN_VERSION;
  tls.DEFAULT_MIN_VERSION = "TLSv1.3";
  try {
    const res = await axios.get(url, { headers });
    return { data: res.data, headers: res.headers };
  } finally {
    tls.DEFAULT_MIN_VERSION = prev;
  }
}

async function tlsBypassPost(
  url: string,
  body: unknown,
  headers: Record<string, string>
): Promise<{ data: any; headers: Record<string, any> }> {
  const prev = tls.DEFAULT_MIN_VERSION;
  tls.DEFAULT_MIN_VERSION = "TLSv1.3";
  try {
    const res = await axios.post(url, body, { headers });
    return { data: res.data, headers: res.headers };
  } finally {
    tls.DEFAULT_MIN_VERSION = prev;
  }
}

async function getToken(): Promise<string> {
  if (cachedToken && Date.now() < tokenExpiresAt) {
    return cachedToken;
  }

  const { headers } = await tlsBypassGet(
    `${AUTH_URL}?authorizationNotRequired=true`,
    {
      accept: "application/json, text/plain, */*",
      "User-Agent": USER_AGENT,
    }
  );

  const token = headers["leshopch"];
  if (!token) {
    throw new Error("No guest token in response headers");
  }

  cachedToken = token;
  tokenExpiresAt = Date.now() + 20 * 60 * 1000;
  return cachedToken!;
}

function extractProduct(hit: Record<string, any>): MigrosProduct | null {
  try {
    const id = (hit.uid ?? hit.migrosId ?? hit.id)?.toString();
    if (!id) return null;

    const name: string = hit.title ?? hit.name ?? "Unknown";

    const brand: string | undefined =
      hit.brand?.name ?? hit.brand ?? undefined;

    const ean: string | undefined = hit.gtins?.[0] ?? undefined;

    let unitText: string | undefined;
    if (hit.offer?.quantity) {
      unitText = hit.offer.quantity;
    } else if (hit.versioning) {
      unitText = hit.versioning;
    }

    const categoryPath: string[] = [];
    if (hit.breadcrumb && Array.isArray(hit.breadcrumb)) {
      for (const bc of hit.breadcrumb) {
        if (typeof bc === "string") categoryPath.push(bc);
        else if (bc?.name) categoryPath.push(bc.name);
      }
    }

    let imageUrl: string | undefined;
    if (hit.images?.[0]?.url) {
      imageUrl = hit.images[0].url.replace("{stack}", "original");
    } else if (hit.imageTransparent?.url) {
      imageUrl = hit.imageTransparent.url.replace("{stack}", "original");
    }

    return {
      remoteId: id,
      name,
      brand,
      ean,
      unitText,
      categoryPath,
      imageUrl,
    };
  } catch {
    return null;
  }
}

export async function searchProducts(
  query: string,
  limit = 20
): Promise<MigrosSearchResult> {
  const env = getEnv();

  return withRetry(
    async () => {
      const token = await getToken();

      // Step 1: Search returns product IDs
      const searchBody = {
        query,
        regionId: env.MIGROS_REGION,
        language: env.MIGROS_LANGUAGE,
        productIds: [],
        sortFields: [],
        sortOrder: "asc",
        algorithm: "DEFAULT",
      };

      const { data: searchData } = await tlsBypassPost(SEARCH_URL, searchBody, {
        accept: "application/json, text/plain, */*",
        "content-type": "application/json",
        "User-Agent": USER_AGENT,
        leshopch: token,
      });

      const productIds: number[] = searchData?.productIds ?? [];
      const totalHits: number = searchData?.numberOfProducts ?? productIds.length;

      if (productIds.length === 0) {
        return { products: [], totalHits: 0 };
      }

      // Step 2: Fetch product cards for the IDs
      const idsToFetch = productIds.slice(0, limit);
      const { data: cardsData } = await tlsBypassPost(PRODUCT_CARDS_URL, {
        productFilter: { uids: idsToFetch },
        offerFilter: { storeType: "OFFLINE", region: "national" },
      }, {
        accept: "application/json, text/plain, */*",
        "content-type": "application/json",
        "User-Agent": USER_AGENT,
        leshopch: token,
      });

      // Response is an object with numeric keys ("0", "1", ...)
      const products: MigrosProduct[] = [];
      const cardValues = Array.isArray(cardsData)
        ? cardsData
        : Object.values(cardsData ?? {});

      for (const card of cardValues) {
        const p = extractProduct(card as Record<string, any>);
        if (p) products.push(p);
        if (products.length >= limit) break;
      }

      return { products, totalHits };
    },
    { maxAttempts: 3, baseDelayMs: 1000 }
  );
}

export async function getProductById(
  remoteId: string
): Promise<MigrosProduct | null> {
  return withRetry(
    async () => {
      const token = await getToken();
      const uid = parseInt(remoteId, 10);
      if (isNaN(uid)) return null;

      const body = {
        productFilter: { uids: [uid] },
        offerFilter: {
          storeType: "OFFLINE",
          region: "national",
          ongoingOfferDate:
            new Date().toISOString().split("T")[0] + "T00:00:00",
        },
      };

      const { data } = await tlsBypassPost(PRODUCT_CARDS_URL, body, {
        accept: "application/json, text/plain, */*",
        "content-type": "application/json",
        "User-Agent": USER_AGENT,
        leshopch: token,
      });

      const cardValues = Array.isArray(data)
        ? data
        : Object.values(data ?? {});
      if (cardValues.length === 0) return null;

      return extractProduct(cardValues[0] as Record<string, any>);
    },
    { maxAttempts: 2, baseDelayMs: 500 }
  );
}
