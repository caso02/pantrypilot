import IORedis from "ioredis";
import { getEnv } from "../config/env.js";

let redis: IORedis | undefined;

export function getRedis(): IORedis {
  if (!redis) {
    redis = new IORedis(getEnv().REDIS_URL, {
      maxRetriesPerRequest: null,
    });
  }
  return redis;
}

export async function disconnectRedis(): Promise<void> {
  if (redis) {
    await redis.quit();
    redis = undefined;
  }
}
