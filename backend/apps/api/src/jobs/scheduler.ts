import { getSyncQueue } from "./queues.js";

export async function scheduleNightlyRefresh(): Promise<void> {
  const queue = getSyncQueue();

  // Remove existing repeatable if present, then re-add
  const repeatables = await queue.getRepeatableJobs();
  for (const r of repeatables) {
    if (r.name === "nightly-refresh") {
      await queue.removeRepeatableByKey(r.key);
    }
  }

  await queue.add(
    "nightly-refresh",
    { type: "nightly-refresh", categories: [] },
    {
      repeat: { pattern: "0 3 * * *" }, // 03:00 daily
      jobId: "nightly-refresh",
    }
  );

  console.log("[scheduler] Nightly refresh scheduled at 03:00");
}

export async function enqueueSearchEnrich(query: string): Promise<void> {
  const queue = getSyncQueue();
  await queue.add("search-enrich", { type: "search-enrich", query }, {
    jobId: `enrich-${query.toLowerCase().replace(/\s+/g, "-")}`,
    deduplication: { id: `enrich-${query.toLowerCase().replace(/\s+/g, "-")}` },
  });
}
