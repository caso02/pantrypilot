import type { FastifyInstance } from "fastify";

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get("/v1/health", async () => {
    return { ok: true, timestamp: new Date().toISOString() };
  });
}
