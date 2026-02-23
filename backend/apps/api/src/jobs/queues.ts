import { Queue, Worker, type Job } from "bullmq";
import { getRedis } from "../db/redis.js";

export const MIGROS_SYNC_QUEUE = "migros-sync";

export type SyncJobData =
  | { type: "nightly-refresh"; categories: string[] }
  | { type: "search-enrich"; query: string };

let syncQueue: Queue<SyncJobData> | undefined;

export function getSyncQueue(): Queue<SyncJobData> {
  if (!syncQueue) {
    syncQueue = new Queue<SyncJobData>(MIGROS_SYNC_QUEUE, {
      connection: getRedis(),
      defaultJobOptions: {
        attempts: 3,
        backoff: { type: "exponential", delay: 2000 },
        removeOnComplete: 100,
        removeOnFail: 200,
      },
    });
  }
  return syncQueue;
}

export function createSyncWorker(
  processor: (job: Job<SyncJobData>) => Promise<void>
): Worker<SyncJobData> {
  return new Worker<SyncJobData>(MIGROS_SYNC_QUEUE, processor, {
    connection: getRedis(),
    concurrency: 2,
    limiter: { max: 4, duration: 5000 },
  });
}
