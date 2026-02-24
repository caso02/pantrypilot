import { buildApp } from "./app.js";
import { getEnv } from "./config/env.js";
import { disconnectPrisma } from "./db/client.js";
import { disconnectRedis } from "./db/redis.js";
import { startSyncWorker } from "./jobs/sync-worker.js";
import { scheduleNightlyRefresh } from "./jobs/scheduler.js";

async function main() {
  const env = getEnv();
  const app = buildApp();

  // Start background workers
  if (env.ENABLE_BACKGROUND_JOBS) {
    try {
      startSyncWorker();
      await scheduleNightlyRefresh();
    } catch (err) {
      app.log.warn({ err }, "Could not start background jobs (Redis may be unavailable)");
    }
  } else {
    app.log.info("Background jobs disabled (set ENABLE_BACKGROUND_JOBS=1 to enable)");
  }

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    app.log.info(`Received ${signal}, shutting down…`);
    await app.close();
    await disconnectPrisma();
    await disconnectRedis();
    process.exit(0);
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  await app.listen({ port: env.PORT, host: "0.0.0.0" });
  app.log.info(`PantryPilot API listening on port ${env.PORT}`);
}

main().catch((err) => {
  console.error("Fatal startup error:", err);
  process.exit(1);
});
