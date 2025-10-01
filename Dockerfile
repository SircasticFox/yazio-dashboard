# ---- deps (install with clean, reproducible CI) ----
FROM node:22-alpine AS deps
WORKDIR /app
ENV NODE_ENV=development
# Speed up installs on Alpine
RUN apk add --no-cache libc6-compat
COPY package*.json ./
RUN npm ci

# ---- build (compile Next.js) ----
FROM node:22-alpine AS build
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Build the Next.js app
RUN npm run build
# Prune dev deps for smaller runtime
RUN npm prune --omit=dev

# ---- runtime (serve with next start) ----
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# Only copy what's needed to run
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/.next            ./.next
COPY --from=build /app/public           ./public
COPY --from=build /app/node_modules     ./node_modules
COPY --from=build /app/next.config.js   ./next.config.js

# Healthcheck: expects 200 on /
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null 2>&1 || exit 1

EXPOSE 3000
USER nextjs
CMD ["npx", "next", "start", "-p", "3000"]