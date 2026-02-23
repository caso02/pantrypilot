import { PrismaClient } from "@prisma/client";
import { getEnv } from "../config/env.js";

let prisma: PrismaClient | undefined;

export function getPrisma(): PrismaClient {
  if (!prisma) {
    prisma = new PrismaClient({
      log: getEnv().NODE_ENV === "development" ? ["warn", "error"] : ["error"],
    });
  }
  return prisma;
}

export async function disconnectPrisma(): Promise<void> {
  if (prisma) {
    await prisma.$disconnect();
    prisma = undefined;
  }
}
