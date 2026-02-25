import { getPrisma } from "../db/client.js";
import { normalizeRawKey, tokenize, expandUmlauts } from "../utils/normalize.js";
import {
  combinedScore,
  levenshteinSimilarity,
  type ScoredCandidate,
} from "../utils/scoring.js";
import { enqueueSearchEnrich } from "../jobs/scheduler.js";

export interface MatchLineInput {
  rawText: string;
  priceText?: string;
  quantityText?: string;
  unitText?: string;
}

export interface MatchSuggestion {
  productId: string;
  canonicalName: string;
  unitText: string | null;
  categoryPath: string[];
  imageUrl: string | null;
  score: number;
}

export interface MatchLineResult {
  rawText: string;
  rawKey: string;
  suggestions: MatchSuggestion[];
}

const MIN_SCORE_THRESHOLD = 0.15;

export async function matchLines(
  lines: MatchLineInput[]
): Promise<MatchLineResult[]> {
  const prisma = getPrisma();
  const results: MatchLineResult[] = [];

  for (const line of lines) {
    const rawKey = normalizeRawKey(line.rawText);
    const queryTokens = tokenize(rawKey);

    // 1) Check normalization override
    const override = await prisma.receiptLineNormalization.findUnique({
      where: { rawKey },
    });

    if (override) {
      // Find the best product matching the override canonical name
      const overrideProducts = await prisma.product.findMany({
        where: { canonicalName: { contains: override.canonicalName, mode: "insensitive" } },
        take: 3,
        select: {
          id: true,
          canonicalName: true,
          unitText: true,
          categoryPath: true,
          imageUrl: true,
        },
      });

      results.push({
        rawText: line.rawText,
        rawKey,
        suggestions: overrideProducts.map((p: {
          id: string;
          canonicalName: string;
          unitText: string | null;
          categoryPath: string[];
          imageUrl: string | null;
        }) => ({
          productId: p.id,
          canonicalName: p.canonicalName,
          unitText: p.unitText,
          categoryPath: p.categoryPath,
          imageUrl: p.imageUrl,
          score: 1.0,
        })),
      });
      continue;
    }

    // 2) Search aliases
    const aliasKey = expandUmlauts(rawKey);
    const aliasMatches = await prisma.productAlias.findMany({
      where: {
        alias: { contains: aliasKey, mode: "insensitive" },
      },
      take: 20,
      include: {
        product: {
          select: {
            id: true,
            canonicalName: true,
            unitText: true,
            categoryPath: true,
            keywords: true,
            imageUrl: true,
          },
        },
      },
    });

    // 3) Search by keyword overlap
    const keywordProducts = queryTokens.length > 0
      ? await prisma.product.findMany({
          where: { keywords: { hasSome: queryTokens } },
          take: 50,
          select: {
            id: true,
            canonicalName: true,
            unitText: true,
            categoryPath: true,
            keywords: true,
            imageUrl: true,
          },
        })
      : [];

    // Deduplicate candidates
    const candidateMap = new Map<
      string,
      {
        id: string;
        canonicalName: string;
        unitText: string | null;
        categoryPath: string[];
        keywords: string[];
        imageUrl: string | null;
      }
    >();

    for (const am of aliasMatches) {
      candidateMap.set(am.product.id, am.product);
    }
    for (const kp of keywordProducts) {
      if (!candidateMap.has(kp.id)) {
        candidateMap.set(kp.id, kp);
      }
    }

    // 4) Score candidates
    const scored: ScoredCandidate<{
      id: string;
      canonicalName: string;
      unitText: string | null;
      categoryPath: string[];
      imageUrl: string | null;
    }>[] = [];

    for (const [, candidate] of candidateMap) {
      const candTokens = candidate.keywords;
      let score = combinedScore(queryTokens, candTokens);

      // Boost Levenshtein for top candidates
      if (score > MIN_SCORE_THRESHOLD) {
        const levBoost = levenshteinSimilarity(
          rawKey.toLowerCase(),
          candidate.canonicalName.toLowerCase()
        );
        score = score * 0.7 + levBoost * 0.3;
      }

      scored.push({
        item: {
          id: candidate.id,
          canonicalName: candidate.canonicalName,
          unitText: candidate.unitText,
          categoryPath: candidate.categoryPath,
          imageUrl: candidate.imageUrl,
        },
        score: Math.round(score * 1000) / 1000,
      });
    }

    scored.sort((a, b) => b.score - a.score);
    const top = scored.slice(0, 3);

    // 5) If no good matches, enqueue remote search
    if (top.length === 0 || (top[0] && top[0].score < 0.3)) {
      try {
        await enqueueSearchEnrich(rawKey);
      } catch {
        // Non-critical: queue may not be available in test
      }
    }

    results.push({
      rawText: line.rawText,
      rawKey,
      suggestions: top.map((s) => ({
        productId: s.item.id,
        canonicalName: s.item.canonicalName,
        unitText: s.item.unitText,
        categoryPath: s.item.categoryPath,
        imageUrl: s.item.imageUrl,
        score: s.score,
      })),
    });
  }

  return results;
}
