import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { matchLines } from "../services/matching-service.js";
import {
  parseReceiptLines,
  isLLMConfigured,
} from "../services/llm-service.js";
import { upsertNormalization } from "../services/normalization-service.js";

const matchBodySchema = z.object({
  merchant: z.string().default("migros"),
  useLLM: z.boolean().default(true),
  lines: z
    .array(
      z.object({
        rawText: z.string().min(1).max(500),
        priceText: z.string().optional(),
        quantityText: z.string().optional(),
        unitText: z.string().optional(),
      })
    )
    .min(1)
    .max(100),
});

export async function matchRoutes(app: FastifyInstance): Promise<void> {
  app.post("/v1/products/match", async (request, reply) => {
    const parsed = matchBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid request body",
        details: parsed.error.flatten(),
      });
    }

    const { lines, useLLM } = parsed.data;

    // Step 1: Try direct DB matching first
    const directMatches = await matchLines(lines);

    // Check which lines have weak matches (score < 0.4)
    const weakLines: { index: number; rawText: string }[] = [];
    for (let i = 0; i < directMatches.length; i++) {
      const best = directMatches[i].suggestions[0];
      if (!best || best.score < 0.4) {
        weakLines.push({ index: i, rawText: lines[i].rawText });
      }
    }

    // Step 2: If LLM is available and there are weak matches, use LLM to re-interpret
    if (useLLM && isLLMConfigured() && weakLines.length > 0) {
      try {
        const llmParsed = await parseReceiptLines(
          weakLines.map((w) => w.rawText)
        );

        // Re-match LLM-interpreted names against DB
        const llmMatchInput = llmParsed.map((r) => ({
          rawText: r.productName || r.rawText,
        }));
        const llmMatches = await matchLines(llmMatchInput);

        // Merge LLM results back into direct matches
        for (let i = 0; i < weakLines.length; i++) {
          const origIndex = weakLines[i].index;
          const llmMatch = llmMatches[i];
          const llmLine = llmParsed[i];

          if (
            llmMatch &&
            llmMatch.suggestions.length > 0 &&
            llmMatch.suggestions[0].score >
              (directMatches[origIndex].suggestions[0]?.score ?? 0)
          ) {
            // LLM match is better — use it
            directMatches[origIndex].suggestions = llmMatch.suggestions;
            directMatches[origIndex].rawKey += ` → LLM: ${llmLine.productName}`;

            // Auto-learn: save the mapping for future direct matches
            if (llmMatch.suggestions[0].score >= 0.4) {
              try {
                await upsertNormalization(
                  weakLines[i].rawText,
                  llmMatch.suggestions[0].canonicalName,
                  llmLine.category ?? undefined
                );
              } catch {
                // Non-critical
              }
            }
          }
        }
      } catch (err: any) {
        // LLM failed — still return direct matches
        request.log.warn({ err }, "LLM fallback failed, using direct matches");
      }
    }

    return {
      matches: directMatches,
      llmUsed: useLLM && isLLMConfigured() && weakLines.length > 0,
    };
  });
}
