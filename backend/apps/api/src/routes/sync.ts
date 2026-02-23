import { FastifyInstance } from "fastify";
import { z } from "zod";
import { getPrisma } from "../db/client.js";
import { verifySessionToken } from "./auth.js";

const inventoryItemSchema = z.object({
  clientId: z.string(),
  canonicalName: z.string(),
  quantity: z.number(),
  unit: z.string(),
  location: z.string(),
  purchaseDate: z.string(),
  estimatedExpiryDate: z.string().nullable().optional(),
  opened: z.boolean().default(false),
  notes: z.string().nullable().optional(),
  category: z.string().nullable().optional(),
});

const shoppingItemSchema = z.object({
  clientId: z.string(),
  name: z.string(),
  targetQuantity: z.number().nullable().optional(),
  unit: z.string().nullable().optional(),
  addedAt: z.string(),
  isCompleted: z.boolean().default(false),
});

const syncPushSchema = z.object({
  inventory: z.array(inventoryItemSchema),
  shoppingList: z.array(shoppingItemSchema),
});

async function extractUserId(authHeader: string | undefined): Promise<string | null> {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const session = await verifySessionToken(authHeader.slice(7));
  return session?.userId ?? null;
}

export async function syncRoutes(app: FastifyInstance) {
  app.post("/v1/sync/push", async (request, reply) => {
    const userId = await extractUserId(request.headers.authorization);
    if (!userId) return reply.status(401).send({ error: "Unauthorized" });

    const body = syncPushSchema.parse(request.body);
    const prisma = getPrisma();

    for (const item of body.inventory) {
      await prisma.syncInventoryItem.upsert({
        where: { userId_clientId: { userId, clientId: item.clientId } },
        create: {
          userId,
          clientId: item.clientId,
          canonicalName: item.canonicalName,
          quantity: item.quantity,
          unit: item.unit,
          location: item.location,
          purchaseDate: new Date(item.purchaseDate),
          estimatedExpiryDate: item.estimatedExpiryDate ? new Date(item.estimatedExpiryDate) : null,
          opened: item.opened,
          notes: item.notes,
          category: item.category,
        },
        update: {
          canonicalName: item.canonicalName,
          quantity: item.quantity,
          unit: item.unit,
          location: item.location,
          purchaseDate: new Date(item.purchaseDate),
          estimatedExpiryDate: item.estimatedExpiryDate ? new Date(item.estimatedExpiryDate) : null,
          opened: item.opened,
          notes: item.notes,
          category: item.category,
        },
      });
    }

    for (const item of body.shoppingList) {
      await prisma.syncShoppingItem.upsert({
        where: { userId_clientId: { userId, clientId: item.clientId } },
        create: {
          userId,
          clientId: item.clientId,
          name: item.name,
          targetQuantity: item.targetQuantity,
          unit: item.unit,
          addedAt: new Date(item.addedAt),
          isCompleted: item.isCompleted,
        },
        update: {
          name: item.name,
          targetQuantity: item.targetQuantity,
          unit: item.unit,
          addedAt: new Date(item.addedAt),
          isCompleted: item.isCompleted,
        },
      });
    }

    const inventoryIds = body.inventory.map(i => i.clientId);
    if (inventoryIds.length > 0) {
      await prisma.syncInventoryItem.deleteMany({
        where: { userId, clientId: { notIn: inventoryIds } },
      });
    }

    const shoppingIds = body.shoppingList.map(i => i.clientId);
    if (shoppingIds.length > 0) {
      await prisma.syncShoppingItem.deleteMany({
        where: { userId, clientId: { notIn: shoppingIds } },
      });
    }

    return reply.send({ ok: true, synced: { inventory: body.inventory.length, shoppingList: body.shoppingList.length } });
  });

  app.get("/v1/sync/pull", async (request, reply) => {
    const userId = await extractUserId(request.headers.authorization);
    if (!userId) return reply.status(401).send({ error: "Unauthorized" });

    const prisma = getPrisma();

    const inventory = await prisma.syncInventoryItem.findMany({ where: { userId } });
    const shoppingList = await prisma.syncShoppingItem.findMany({ where: { userId } });

    return reply.send({
      inventory: inventory.map(i => ({
        clientId: i.clientId,
        canonicalName: i.canonicalName,
        quantity: i.quantity,
        unit: i.unit,
        location: i.location,
        purchaseDate: i.purchaseDate.toISOString(),
        estimatedExpiryDate: i.estimatedExpiryDate?.toISOString() ?? null,
        opened: i.opened,
        notes: i.notes,
        category: i.category,
      })),
      shoppingList: shoppingList.map(s => ({
        clientId: s.clientId,
        name: s.name,
        targetQuantity: s.targetQuantity,
        unit: s.unit,
        addedAt: s.addedAt.toISOString(),
        isCompleted: s.isCompleted,
      })),
    });
  });
}
