import type { FastifyInstance } from "fastify";
import { z } from "zod";
import {
  parseReceiptLines,
  isLLMConfigured,
  type ParsedReceiptLine,
} from "../services/llm-service.js";
import { matchLines } from "../services/matching-service.js";
import { upsertNormalization } from "../services/normalization-service.js";

const parseBodySchema = z.object({
  lines: z.array(z.string().min(1).max(2000)).min(1).max(200),
  autoMatch: z.boolean().default(true),
  autoLearn: z.boolean().default(true),
});

export interface ParsedAndMatchedLine {
  rawText: string;
  llm: ParsedReceiptLine;
  match: {
    productId: string;
    canonicalName: string;
    unitText: string | null;
    categoryPath: string[];
    imageUrl: string | null;
    score: number;
  } | null;
}

export async function receiptRoutes(app: FastifyInstance): Promise<void> {
  app.post("/v1/receipts/parse", async (request, reply) => {
    if (!isLLMConfigured()) {
      return reply.status(503).send({
        error: "LLM not configured",
        message:
          "Set OPENAI_API_KEY, ANTHROPIC_API_KEY, PERPLEXITY_API_KEY, or GEMINI_API_KEY to enable receipt parsing.",
      });
    }

    const inLines = (request.body as any)?.lines ?? [];
    request.log.info({ lineCount: inLines.length, lines: inLines }, "Receipt parse request received");

    const parsed = parseBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid request body",
        details: parsed.error.flatten(),
      });
    }

    const { lines, autoMatch, autoLearn } = parsed.data;

    let llmResults: ParsedReceiptLine[];
    try {
      llmResults = await parseReceiptLines(lines, request.log);
    } catch (err: any) {
      request.log.error({ err }, "LLM parsing failed");
      return reply.status(502).send({
        error: "LLM parsing failed",
        message: err.message,
      });
    }


    const output: ParsedAndMatchedLine[] = [];

    // Step 2: Match LLM-interpreted names against DB
    if (autoMatch && llmResults.length > 0) {
      const matchInput = llmResults.map((r) => ({
        rawText: r.productName || r.rawText,
        priceText: undefined,
        quantityText: r.quantity?.toString(),
        unitText: r.unit ?? undefined,
      }));

      const matchResults = await matchLines(matchInput);

      for (let i = 0; i < llmResults.length; i++) {
        const llm = llmResults[i];
        const matchResult = matchResults[i];
        const bestMatch =
          matchResult?.suggestions?.[0]?.score >= 0.4
            ? matchResult.suggestions[0]
            : null;

        // Step 3: Auto-learn — save successful matches as normalization overrides
        if (autoLearn && bestMatch && bestMatch.score >= 0.4) {
          try {
            await upsertNormalization(
              llm.rawText,
              bestMatch.canonicalName,
              llm.category ?? undefined
            );
          } catch {
            // Non-critical
          }
        }

        output.push({
          rawText: llm.rawText,
          llm,
          match: bestMatch
            ? {
                productId: bestMatch.productId,
                canonicalName: bestMatch.canonicalName,
                unitText: bestMatch.unitText,
                categoryPath: bestMatch.categoryPath,
                imageUrl: bestMatch.imageUrl,
                score: bestMatch.score,
              }
            : null,
        });
      }
    } else {
      for (const llm of llmResults) {
        output.push({ rawText: llm.rawText, llm, match: null });
      }
    }

    request.log.debug({
      matchSummary: output.map((o) => ({
        name: o.llm.productName,
        score: o.match?.score ?? null,
        hasImage: o.match?.imageUrl != null,
        imageUrl: o.match?.imageUrl ?? null,
      })),
    }, "Match results with imageUrl");

    return {
      parsed: output,
      stats: {
        total: output.length,
        matched: output.filter((o) => o.match !== null).length,
        highConfidence: llmResults.filter((r) => r.confidence === "high").length,
      },
    };
  });
}
