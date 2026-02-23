import { getPrisma } from "../db/client.js";
import { upsertProductsFromSearch } from "../services/product-service.js";

const SEED_QUERIES = [
  "Milch", "Brot", "Käse", "Joghurt", "Butter", "Eier",
  "Poulet", "Pasta", "Reis", "Kartoffeln", "Tomaten",
  "Äpfel", "Bananen", "Kaffee", "Schokolade",
];

async function seed() {
  const prisma = getPrisma();

  // Ensure Migros merchant exists
  await prisma.merchant.upsert({
    where: { code: "migros" },
    update: { name: "Migros" },
    create: { code: "migros", name: "Migros" },
  });

  console.log("[seed] Migros merchant ensured");

  for (const query of SEED_QUERIES) {
    console.log(`[seed] Searching: ${query}`);
    try {
      const count = await upsertProductsFromSearch(query);
      console.log(`[seed]   -> ${count} products upserted`);
    } catch (err) {
      console.error(`[seed]   -> Error for "${query}":`, err);
    }
    await new Promise((r) => setTimeout(r, 2000));
  }

  console.log("[seed] Done");
  await prisma.$disconnect();
  process.exit(0);
}

seed().catch((err) => {
  console.error("[seed] Fatal:", err);
  process.exit(1);
});
