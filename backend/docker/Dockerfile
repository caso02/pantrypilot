FROM node:20-alpine AS base
WORKDIR /app

COPY apps/api/package.json apps/api/package-lock.json* ./apps/api/
COPY prisma/ ./prisma/

WORKDIR /app/apps/api
RUN npm install --production=false

WORKDIR /app
COPY apps/api/ ./apps/api/

WORKDIR /app/apps/api
RUN npx prisma generate --schema=../../prisma/schema.prisma
RUN npx tsc

FROM node:20-alpine AS runner
WORKDIR /app

COPY --from=base /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=base /app/apps/api/dist ./apps/api/dist
COPY --from=base /app/apps/api/package.json ./apps/api/
COPY --from=base /app/prisma ./prisma

WORKDIR /app/apps/api

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy --schema=../../prisma/schema.prisma && node dist/server.js"]
