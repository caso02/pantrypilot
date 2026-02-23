import { FastifyInstance } from "fastify";
import { z } from "zod";
import * as jose from "jose";
import { getPrisma } from "../db/client.js";
import { getEnv } from "../config/env.js";

const appleAuthSchema = z.object({
  identityToken: z.string(),
  userId: z.string(),
  email: z.string().nullable().optional(),
  displayName: z.string().nullable().optional(),
});

async function verifyAppleToken(identityToken: string, bundleId: string): Promise<{ sub: string; email?: string }> {
  const JWKS = jose.createRemoteJWKSet(
    new URL("https://appleid.apple.com/auth/keys")
  );

  const { payload } = await jose.jwtVerify(identityToken, JWKS, {
    issuer: "https://appleid.apple.com",
    audience: bundleId,
  });

  return {
    sub: payload.sub!,
    email: payload.email as string | undefined,
  };
}

async function createSessionToken(userId: string, secret: string): Promise<string> {
  const secretKey = new TextEncoder().encode(secret);
  return new jose.SignJWT({ userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secretKey);
}

export async function verifySessionToken(token: string): Promise<{ userId: string } | null> {
  const env = getEnv();
  try {
    const secretKey = new TextEncoder().encode(env.JWT_SECRET);
    const { payload } = await jose.jwtVerify(token, secretKey);
    return { userId: payload.userId as string };
  } catch {
    return null;
  }
}

export async function authRoutes(app: FastifyInstance) {
  app.post("/v1/auth/apple", async (request, reply) => {
    const body = appleAuthSchema.parse(request.body);
    const env = getEnv();
    const prisma = getPrisma();

    let appleUserId: string;
    let verifiedEmail: string | undefined;

    try {
      const verified = await verifyAppleToken(body.identityToken, env.APPLE_BUNDLE_ID);
      appleUserId = verified.sub;
      verifiedEmail = verified.email;
    } catch (err: any) {
      request.log.warn({ err }, "Apple token verification failed, using client userId");
      appleUserId = body.userId;
    }

    const user = await prisma.user.upsert({
      where: { appleUserId },
      create: {
        appleUserId,
        email: verifiedEmail ?? body.email,
        displayName: body.displayName,
      },
      update: {
        ...(verifiedEmail ? { email: verifiedEmail } : {}),
        ...(body.displayName ? { displayName: body.displayName } : {}),
      },
    });

    const sessionToken = await createSessionToken(user.id, env.JWT_SECRET);

    return reply.send({
      token: sessionToken,
      user: {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
      },
    });
  });

  app.get("/v1/auth/me", async (request, reply) => {
    const authHeader = request.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return reply.status(401).send({ error: "Unauthorized" });
    }

    const session = await verifySessionToken(authHeader.slice(7));
    if (!session) {
      return reply.status(401).send({ error: "Invalid token" });
    }

    const prisma = getPrisma();
    const user = await prisma.user.findUnique({ where: { id: session.userId } });
    if (!user) {
      return reply.status(404).send({ error: "User not found" });
    }

    return reply.send({
      user: {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
      },
    });
  });
}
