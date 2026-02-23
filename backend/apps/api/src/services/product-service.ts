import { getPrisma } from "../db/client.js";
import { searchProducts } from "../migros/provider.js";
import {
  tokenize,
  buildCanonicalName,
  expandUmlauts,
} from "../utils/normalize.js";

export async function ensureMerchant(): Promise<string> {
  const prisma = getPrisma();
  const merchant = await prisma.merchant.upsert({
    where: { code: "migros" },
    update: {},
    create: { code: "migros", name: "Migros" },
  });
  return merchant.id;
}

export async function upsertProductsFromSearch(
  query: string
): Promise<number> {
  const merchantId = await ensureMerchant();
  const prisma = getPrisma();

  const result = await searchProducts(query);
  let count = 0;

  for (const p of result.products) {
    const canonical = buildCanonicalName(p.name);
    const keywords = tokenize(
      [p.name, p.brand, ...(p.categoryPath ?? [])].filter(Boolean).join(" ")
    );

    await prisma.product.upsert({
      where: {
        merchantId_remoteId: { merchantId, remoteId: p.remoteId },
      },
      update: {
        name: p.name,
        canonicalName: canonical,
        brand: p.brand ?? null,
        ean: p.ean ?? null,
        categoryPath: p.categoryPath,
        unitText: p.unitText ?? null,
        keywords,
        imageUrl: p.imageUrl ?? null,
        lastSeenAt: new Date(),
      },
      create: {
        merchantId,
        remoteId: p.remoteId,
        name: p.name,
        canonicalName: canonical,
        brand: p.brand ?? null,
        ean: p.ean ?? null,
        categoryPath: p.categoryPath,
        unitText: p.unitText ?? null,
        keywords,
        imageUrl: p.imageUrl ?? null,
      },
    });

    // Derive aliases from name tokens
    const aliasText = expandUmlauts(p.name.toUpperCase().trim());
    const existing = await prisma.productAlias.findFirst({
      where: { alias: aliasText, product: { merchantId, remoteId: p.remoteId } },
    });

    if (!existing) {
      const product = await prisma.product.findUnique({
        where: { merchantId_remoteId: { merchantId, remoteId: p.remoteId } },
      });
      if (product) {
        await prisma.productAlias.create({
          data: {
            productId: product.id,
            alias: aliasText,
            source: "derived",
          },
        });
      }
    }

    count++;
  }

  return count;
}

export async function searchLocalProducts(
  query: string,
  limit = 20
): Promise<
  Array<{
    id: string;
    canonicalName: string;
    name: string;
    ean: string | null;
    unitText: string | null;
    categoryPath: string[];
    imageUrl: string | null;
  }>
> {
  const prisma = getPrisma();
  const queryTokens = tokenize(query);

  if (queryTokens.length === 0) {
    return prisma.product.findMany({
      take: limit,
      orderBy: { lastSeenAt: "desc" },
      select: {
        id: true,
        canonicalName: true,
        name: true,
        ean: true,
        unitText: true,
        categoryPath: true,
        imageUrl: true,
      },
    });
  }

  // Use Prisma full-text-ish search via keyword array overlap
  const products = await prisma.product.findMany({
    where: {
      keywords: { hasSome: queryTokens },
    },
    take: limit * 2,
    orderBy: { lastSeenAt: "desc" },
    select: {
      id: true,
      canonicalName: true,
      name: true,
      ean: true,
      unitText: true,
      categoryPath: true,
      imageUrl: true,
      keywords: true,
    },
  });

  return products.slice(0, limit).map(({ keywords: _k, ...rest }) => rest);
}
