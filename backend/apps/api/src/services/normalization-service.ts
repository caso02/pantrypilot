import { getPrisma } from "../db/client.js";
import { normalizeRawKey } from "../utils/normalize.js";

export async function upsertNormalization(
  rawText: string,
  canonicalName: string,
  categoryHint?: string
): Promise<{ rawKey: string; canonicalName: string; categoryHint: string | null }> {
  const prisma = getPrisma();
  const rawKey = normalizeRawKey(rawText);

  const record = await prisma.receiptLineNormalization.upsert({
    where: { rawKey },
    update: {
      canonicalName,
      categoryHint: categoryHint ?? null,
    },
    create: {
      rawKey,
      canonicalName,
      categoryHint: categoryHint ?? null,
    },
  });

  return {
    rawKey: record.rawKey,
    canonicalName: record.canonicalName,
    categoryHint: record.categoryHint,
  };
}
