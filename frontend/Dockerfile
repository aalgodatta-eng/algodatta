# ---- deps ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./package.json
RUN npm install --legacy-peer-deps || true

# ---- build ----
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_DISABLE_ESLINT=1 NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ---- runtime ----
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY public ./public
EXPOSE 3000
CMD ["npm", "start"]
