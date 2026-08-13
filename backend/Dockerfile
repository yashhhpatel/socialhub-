# SocialHub backend (NestJS) — production image (Milestone 6.2)
#
# Multi-stage: the builder compiles TypeScript and generates the Prisma
# client; the runtime carries only the compiled output and pruned
# production dependencies, so the shipped image has no toolchain in it.

# ---- builder ----
FROM node:22.12-bookworm-slim AS builder
WORKDIR /app

# Install against the lockfile first, as its own layer, so dependencies are
# only re-fetched when the lockfile actually changes.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Prisma 7 dropped the automatic client generation from @prisma/client's
# install, so it must be run explicitly. prisma.config.ts resolves
# env('DATABASE_URL') while loading even though generation never connects,
# so a syntactically valid placeholder has to be present at build time.
ENV DATABASE_URL="postgresql://build:build@localhost:5432/build"
RUN npx prisma generate
RUN npm run build

# Drop devDependencies (the Nest CLI, ts toolchain, prisma CLI) while
# keeping @prisma/client and its just-generated output, which are runtime.
RUN npm prune --omit=dev

# ---- runtime ----
FROM node:22.12-bookworm-slim AS runtime
WORKDIR /app

# Run as the built-in unprivileged user rather than root.
ENV NODE_ENV=production
USER node

COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/dist ./dist
COPY --chown=node:node --from=builder /app/package.json ./package.json

EXPOSE 3000

# Real configuration (DATABASE_URL, JWT/token secrets, etc.) is injected at
# runtime by the platform — never baked into the image. The build-time
# DATABASE_URL above is a throwaway used only for `prisma generate`.
CMD ["node", "dist/main"]
