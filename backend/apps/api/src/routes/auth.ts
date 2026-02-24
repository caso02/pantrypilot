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

const googleAuthSchema = z.object({
  idToken: z.string(),
  displayName: z.string().nullable().optional(),
});

async function verifyGoogleToken(
  idToken: string,
  clientId: string
): Promise<{ sub: string; email?: string; name?: string }> {
  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  if (!res.ok) {
    throw new Error(`Google tokeninfo request failed: ${res.status}`);
  }
  const data: any = await res.json();
  if (data.error) {
    throw new Error(`Invalid Google ID token: ${data.error}`);
  }
  if (data.aud !== clientId) {
    throw new Error("Google token audience mismatch");
  }
  return { sub: data.sub, email: data.email, name: data.name };
}

export async function authRoutes(app: FastifyInstance) {
  app.post("/v1/auth/google", async (request, reply) => {
    const env = getEnv();
    if (!env.GOOGLE_CLIENT_ID) {
      return reply.status(503).send({
        error: "Google Sign-In not configured",
        message: "Set GOOGLE_CLIENT_ID environment variable.",
      });
    }

    const parsed = googleAuthSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid request body",
        details: parsed.error.flatten(),
      });
    }

    const body = parsed.data;
    const prisma = getPrisma();

    let googleUserId: string;
    let verifiedEmail: string | undefined;
    let verifiedName: string | undefined;

    try {
      const verified = await verifyGoogleToken(body.idToken, env.GOOGLE_CLIENT_ID);
      if (!verified.sub) {
        request.log.warn({ verified }, "Google tokeninfo returned no sub");
        return reply.status(401).send({ error: "Google token missing sub claim" });
      }
      googleUserId = verified.sub;
      verifiedEmail = verified.email;
      verifiedName = verified.name;
    } catch (err: any) {
      request.log.warn({ err: err.message }, "Google token verification failed");
      return reply.status(401).send({
        error: "Invalid Google ID token",
        detail: err.message,
      });
    }

    const existingUser = await prisma.user.findUnique({
      where: { googleUserId },
      select: { id: true },
    });
    const isNewUser = !existingUser;

    let user: Awaited<ReturnType<typeof prisma.user.upsert>>;
    try {
      user = await prisma.user.upsert({
        where: { googleUserId },
        create: {
          googleUserId,
          email: verifiedEmail,
          displayName: verifiedName ?? body.displayName,
        },
        update: {
          ...(verifiedEmail ? { email: verifiedEmail } : {}),
          ...(verifiedName ? { displayName: verifiedName } : {}),
        },
      });
    } catch (err: any) {
      request.log.error({ err }, "DB upsert failed for Google user");
      return reply.status(500).send({ error: "Database error", message: err.message });
    }

    const sessionToken = await createSessionToken(user.id, env.JWT_SECRET);

    return reply.send({
      token: sessionToken,
      isNewUser,
      user: {
        id: user.id,
        displayName: user.displayName,
        email: user.email,
      },
    });
  });

  app.post("/v1/auth/apple", async (request, reply) => {
    const parsed = appleAuthSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.status(400).send({
        error: "Invalid request body",
        details: parsed.error.flatten(),
      });
    }

    const body = parsed.data;
    const env = getEnv();
    const prisma = getPrisma();

    let appleUserId: string;
    let verifiedEmail: string | undefined;

    try {
      const verified = await verifyAppleToken(body.identityToken, env.APPLE_BUNDLE_ID);
      appleUserId = verified.sub;
      verifiedEmail = verified.email;
    } catch (err: any) {
      request.log.warn({ err }, "Apple token verification failed");
      return reply.status(401).send({
        error: "Invalid Apple identity token",
      });
    }

    const existingUser = await prisma.user.findUnique({
      where: { appleUserId },
      select: { id: true },
    });
    const isNewUser = !existingUser;

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
      isNewUser,
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
