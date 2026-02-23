import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { upsertNormalization } from "../services/normalization-service.js";

const overrideBodySchema = z.object({
  rawText: z.string().min(1).max(500),
  canonicalName: z.string().min(1).max(300),
  categoryHint: z.string().max(100).optional(),
});

export async function normalizationRoutes(app: FastifyInstance): Promise<void> {
  app.post("/v1/normalization/override", async (request, reply) => {
    const parsed = overrideBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid request body",
        details: parsed.error.flatten(),
      });
    }

    const { rawText, canonicalName, categoryHint } = parsed.data;
    const result = await upsertNormalization(rawText, canonicalName, categoryHint);

    return { ok: true, ...result };
  });
}
