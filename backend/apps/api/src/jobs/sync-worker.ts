import type { Job } from "bullmq";
import { createSyncWorker, type SyncJobData } from "./queues.js";
import { upsertProductsFromSearch } from "../services/product-service.js";

const SEED_QUERIES = [
  "Milch", "Brot", "Käse", "Joghurt", "Butter", "Eier", "Poulet",
  "Rindfleisch", "Pasta", "Reis", "Kartoffeln", "Tomaten", "Salat",
  "Äpfel", "Bananen", "Orangensaft", "Mineralwasser", "Kaffee",
  "Schokolade", "Müesli", "Mehl", "Zucker", "Olivenöl", "Zwiebeln",
  "Karotten", "Gurke", "Paprika", "Pouletbrust", "Lachs", "Rahm",
];

async function processSyncJob(job: Job<SyncJobData>): Promise<void> {
  const { data } = job;

  if (data.type === "nightly-refresh") {
    const queries = data.categories.length > 0 ? data.categories : SEED_QUERIES;
    let processed = 0;

    for (const query of queries) {
      await upsertProductsFromSearch(query);
      processed++;
      await job.updateProgress(Math.round((processed / queries.length) * 100));
      // Rate-limit: pause between queries
      await new Promise((r) => setTimeout(r, 1500));
    }
  } else if (data.type === "search-enrich") {
    await upsertProductsFromSearch(data.query);
  }
}

let workerStarted = false;

export function startSyncWorker(): void {
  if (workerStarted) return;
  workerStarted = true;

  const worker = createSyncWorker(processSyncJob);

  worker.on("completed", (job) => {
    console.log(`[sync] Job ${job.id} (${job.data.type}) completed`);
  });

  worker.on("failed", (job, err) => {
    console.error(
      `[sync] Job ${job?.id} (${job?.data?.type}) failed:`,
      err.message
    );
  });

  console.log("[sync] Worker started");
}
