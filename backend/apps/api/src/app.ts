import Fastify from "fastify";
import { getEnv } from "./config/env.js";
import { healthRoutes } from "./routes/health.js";
import { productRoutes } from "./routes/products.js";
import { matchRoutes } from "./routes/match.js";
import { normalizationRoutes } from "./routes/normalization.js";
import { receiptRoutes } from "./routes/receipts.js";
import { authRoutes } from "./routes/auth.js";
import { syncRoutes } from "./routes/sync.js";

export function buildApp() {
  const env = getEnv();

  const app = Fastify({
    logger: {
      level: env.NODE_ENV === "production" ? "info" : "debug",
    },
  });

  // Optional API key auth
  if (env.API_KEY) {
    app.addHook("onRequest", async (request, reply) => {
      // Skip auth for health endpoint
      if (request.url === "/v1/health" || request.url === "/v1/auth/apple") return;

      const key = request.headers["x-api-key"];
      if (key !== env.API_KEY) {
        return reply
          .status(401)
          .send({ error: "Unauthorized", message: "Invalid or missing x-api-key header" });
      }
    });
  }

  // Global error handler
  app.setErrorHandler((error: Error & { statusCode?: number }, request, reply) => {
    request.log.error({ err: error }, "Request error");

    const statusCode = error.statusCode ?? 500;
    return reply.status(statusCode).send({
      error: error.name ?? "InternalError",
      message:
        statusCode >= 500 ? "Internal server error" : error.message,
    });
  });

  // Register routes
  app.register(healthRoutes);
  app.register(productRoutes);
  app.register(matchRoutes);
  app.register(normalizationRoutes);
  app.register(receiptRoutes);
  app.register(authRoutes);
  app.register(syncRoutes);

  return app;
}
