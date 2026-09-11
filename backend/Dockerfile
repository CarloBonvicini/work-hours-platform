FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 8080

# wget di busybox invece di un processo node: parte in millisecondi, cosi' un
# picco di carico sul portatile non fa scattare autoheal. Timeout/retries larghi:
# unhealthy solo dopo ~2.5 min di fallimenti consecutivi.
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=5 \
  CMD wget -qO- --timeout=8 http://127.0.0.1:8080/health >/dev/null || exit 1

CMD ["node", "dist/index.js"]

