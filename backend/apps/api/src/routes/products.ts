import type { FastifyInstance } from "fastify";
import { z } from "zod";
import {
  searchLocalProducts,
  upsertProductsFromSearch,
} from "../services/product-service.js";
import { tokenize } from "../utils/normalize.js";
import { combinedScore } from "../utils/scoring.js";

const searchQuerySchema = z.object({
  q: z.string().min(1).max(200),
});

export async function productRoutes(app: FastifyInstance): Promise<void> {
  app.get("/v1/products/search", async (request, reply) => {
    const parsed = searchQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid query",
        details: parsed.error.flatten(),
      });
    }

    const { q } = parsed.data;
    let results = await searchLocalProducts(q, 20);

    // If local DB has few results, fetch from Migros and retry
    if (results.length < 5) {
      try {
        await upsertProductsFromSearch(q);
        results = await searchLocalProducts(q, 20);
      } catch (err) {
        app.log.warn({ err, query: q }, "Migros search-enrich failed");
      }
    }

    // Score and sort
    const queryTokens = tokenize(q);
    const scored = results.map((r) => {
      const candTokens = tokenize(r.canonicalName);
      const score = combinedScore(queryTokens, candTokens);
      return { ...r, score: Math.round(score * 1000) / 1000 };
    });
    scored.sort((a, b) => b.score - a.score);

    return { results: scored.slice(0, 20) };
  });
}
