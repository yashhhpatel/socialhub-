# SocialHub — Complete Database Design

Schema is presented as it exists at the end of the roadmap (MVP → Enterprise), built incrementally by the migrations each blueprint phase introduces. PostgreSQL + Prisma, as specified in the architecture doc.

> **Authoritative source (as of 2026-08-22):** `backend/prisma/schema.prisma` and
> the 23 applied migrations under `backend/prisma/migrations/`. Sections 1–7 below
> reflect the original design; the schema has since grown (billing, notifications,
> media, account-security, Google auth). **See [§10 — Schema delta since initial
> design](#10-schema-delta-since-initial-design)** for what was added, and defer to
> the Prisma file for exact field definitions.

---

## 1. ER Diagram

```mermaid
erDiagram
    ORGANIZATION ||--o{ USER : "has members"
    ORGANIZATION ||--o{ SOCIAL_ACCOUNT : "connects"
    ORGANIZATION ||--o{ CONTENT_ASSET : "owns"
    ORGANIZATION ||--o{ TEMPLATE : "owns"
    ORGANIZATION ||--o| BRAND_KIT : "has one"
    ORGANIZATION ||--o{ INVITE : "sends"
    ORGANIZATION ||--o{ AUDIT_LOG : "generates"
    ORGANIZATION ||--o{ AI_USAGE_LOG : "consumes"
    ORGANIZATION ||--o| SSO_CONFIG : "configures"

    USER ||--o{ REFRESH_TOKEN : "holds"
    USER ||--o{ CONTENT_ASSET : "creates"
    USER ||--o{ COMMENT : "writes"
    USER ||--o{ AUDIT_LOG : "performs"
    USER ||--o{ INVITE : "invited via"

    SOCIAL_ACCOUNT ||--o{ PUBLISH_JOB : "publishes via"

    CONTENT_ASSET ||--o{ CONTENT_VARIANT : "generates"
    CONTENT_ASSET ||--o{ COMMENT : "receives"
    CONTENT_ASSET }o--o| TEMPLATE : "cloned from"
    CONTENT_ASSET }o--o| BRAND_KIT : "styled by"

    CONTENT_VARIANT ||--o{ PUBLISH_JOB : "scheduled as"
    CONTENT_VARIANT ||--o{ POST_METRIC : "measured by"

    TEMPLATE }o--o| ORGANIZATION : "authored by (nullable if public)"

    ORGANIZATION {
        uuid id PK
        string name
        enum plan_tier
        uuid brand_kit_id FK
        boolean requires_approval
        timestamp created_at
    }
    USER {
        uuid id PK
        string email UK
        string password_hash
        enum role
        uuid org_id FK
        timestamp created_at
    }
    REFRESH_TOKEN {
        uuid id PK
        uuid user_id FK
        string token_hash UK
        timestamp expires_at
        boolean revoked
    }
    SOCIAL_ACCOUNT {
        uuid id PK
        uuid org_id FK
        enum platform
        string access_token_enc
        string refresh_token_enc
        timestamp expires_at
        enum status
    }
    CONTENT_ASSET {
        uuid id PK
        uuid org_id FK
        uuid created_by FK
        enum type
        jsonb canvas_json
        uuid template_id FK
        uuid brand_kit_id FK
        enum approval_status
        timestamp created_at
        timestamp updated_at
    }
    CONTENT_VARIANT {
        uuid id PK
        uuid asset_id FK
        enum platform
        string rendered_media_url
        text caption
        text hashtags
        enum status
    }
    PUBLISH_JOB {
        uuid id PK
        uuid variant_id FK
        uuid social_account_id FK
        timestamp scheduled_at
        enum status
        int attempt_count
        text last_error
    }
    POST_METRIC {
        uuid id PK
        uuid variant_id FK
        enum platform
        enum metric_type
        numeric value
        timestamp captured_at
    }
    TEMPLATE {
        uuid id PK
        uuid org_id FK "nullable if public marketplace item"
        string category
        jsonb canvas_json
        boolean is_public
        timestamp created_at
    }
    BRAND_KIT {
        uuid id PK
        uuid org_id FK UK
        jsonb colors
        jsonb fonts
        string logo_url
    }
    COMMENT {
        uuid id PK
        uuid asset_id FK
        uuid user_id FK
        text body
        timestamp created_at
    }
    INVITE {
        uuid id PK
        uuid org_id FK
        string email
        enum role
        string token UK
        enum status
        timestamp expires_at
    }
    AUDIT_LOG {
        uuid id PK
        uuid org_id FK
        uuid user_id FK
        string action
        string resource_type
        uuid resource_id
        jsonb metadata
        timestamp timestamp
    }
    AI_USAGE_LOG {
        uuid id PK
        uuid org_id FK
        enum feature
        int tokens_used
        timestamp created_at
    }
    SSO_CONFIG {
        uuid id PK
        uuid org_id FK UK
        string idp_entity_id
        string idp_metadata_url
        boolean enabled
    }
```

---

## 2. Tables

| Table | Introduced In | Purpose |
|---|---|---|
| `organization` | Phase 1 | Tenant boundary — every other table scopes to this |
| `user` | Phase 1 | Individual login identity, belongs to exactly one org |
| `refresh_token` | Phase 1 | Rotatable session tokens, allows revocation without password reset |
| `social_account` | Phase 2 | Connected external platform account + encrypted OAuth tokens |
| `content_asset` | Phase 3 | The canonical design a user creates — one per "piece of content" |
| `content_variant` | Phase 4 | Per-platform rendition of an asset (the "publish everywhere" fan-out) |
| `publish_job` | Phase 4/7 | A single publish attempt of one variant to one connected account |
| `post_metric` | Phase 10 | Normalized performance data pulled back from each platform |
| `template` | Phase 9/14 | Reusable design starting point; also doubles as marketplace listing when public |
| `brand_kit` | Phase 9 | Org-level colors/fonts/logo, applied inside the editor |
| `comment` | Phase 13 | Threaded feedback on a content asset |
| `invite` | Phase 11 | Pending team invitation, consumed on acceptance |
| `audit_log` | Phase 1 (stub) / 15 (full) | Immutable record of who did what, for compliance |
| `ai_usage_log` | Phase 5 | Per-org AI feature consumption, backs quota enforcement |
| `sso_config` | Phase 15 | Per-org SAML IdP configuration |

---

## 3. Relationships

- **Organization → User**: one-to-many. Every user belongs to exactly one org (no multi-org membership at this stage — a deliberate simplification; revisit only if Enterprise customers require users spanning multiple orgs).
- **Organization → SocialAccount**: one-to-many. Accounts are connected at the org level, not the individual user level, so any authorized team member can publish through them.
- **User → RefreshToken**: one-to-many. Multiple active sessions (devices/browsers) per user.
- **ContentAsset → ContentVariant**: one-to-many. This is the structural core of "create once, publish everywhere" — one asset fans out into N platform-specific variants.
- **ContentVariant → PublishJob**: one-to-many. A variant can be republished or rescheduled, each attempt getting its own job row for full history.
- **SocialAccount → PublishJob**: one-to-many. Every job is tied to the specific connected account it published through.
- **ContentVariant → PostMetric**: one-to-many, time-series. Multiple metric rows per variant over time (e.g., daily impressions snapshots), not a single mutable counter — preserves historical trend data.
- **Template → ContentAsset**: optional one-to-many. An asset may reference the template it was started from; nullable because most assets aren't template-based.
- **ContentAsset → Comment**: one-to-many, cascades on asset deletion.
- **Organization → BrandKit**: one-to-one.
- **Organization → SsoConfig**: one-to-one, nullable (only Enterprise orgs have a row).

---

## 4. Indexes

| Table | Index | Reason |
|---|---|---|
| `user` | unique on `email` | Login lookup, enforced uniqueness |
| `user` | on `org_id` | Team member listing, RBAC scoping on every request |
| `refresh_token` | unique on `token_hash` | Fast validation lookup, never store raw token |
| `refresh_token` | on `(user_id, revoked)` | Session listing/cleanup queries |
| `social_account` | on `org_id` | Connected-accounts screen load |
| `social_account` | unique on `(org_id, platform, external_account_id)` | Prevent duplicate connection of the same external account |
| `content_asset` | on `org_id` | Asset library listing (most common query in the app) |
| `content_asset` | on `(org_id, approval_status)` | Approval queue filtering (Phase 13) |
| `content_variant` | on `asset_id` | Loading all platform variants for one asset |
| `publish_job` | on `(status, scheduled_at)` | Cron/worker polling for due jobs — this is a hot-path query, index is critical |
| `publish_job` | on `variant_id` | Job history per variant |
| `post_metric` | on `(variant_id, metric_type, captured_at)` | Time-series lookups for charts — composite index supports range scans |
| `post_metric` | on `(org_id via variant→asset join path materialized, captured_at)` — *see §8 on denormalization* | Dashboard aggregation across an org's entire history |
| `template` | on `(is_public, category)` | Marketplace browse/filter |
| `comment` | on `asset_id` | Comment thread load |
| `invite` | unique on `token` | Invite acceptance lookup |
| `audit_log` | on `(org_id, timestamp)` | Audit log table filtering/pagination — append-only, so index write cost is acceptable |
| `ai_usage_log` | on `(org_id, created_at)` | Quota window calculation (e.g., "usage in the last 30 days") |

---

## 5. Constraints

- **Foreign keys** on every relational column, `ON DELETE CASCADE` for strictly-owned children (`content_variant`, `comment`, `refresh_token`), `ON DELETE RESTRICT` for anything that should block deletion until explicitly handled (`social_account` referenced by `publish_job` history — you don't want to silently orphan publish history by disconnecting an account).
- **NOT NULL** on all foreign keys except the deliberately nullable ones called out above (`content_asset.template_id`, `template.org_id` for public marketplace items, `content_asset.brand_kit_id`).
- **CHECK constraint** on `publish_job.attempt_count >= 0`.
- **CHECK constraint** on `post_metric.value >= 0` (metrics are counts/rates, never negative).
- **UNIQUE constraint** on `(org_id, platform, external_account_id)` in `social_account` — prevents the same Instagram account being connected twice to one org.
- **UNIQUE constraint** on `brand_kit.org_id` and `sso_config.org_id` — enforces the one-to-one relationship at the database level, not just application logic.
- **Row-level org scoping**: every tenant-owned table carries `org_id` directly (not inferred through a join chain), so a repository-layer guard can filter `WHERE org_id = :currentOrg` on literally every query without needing multi-hop joins — this is what makes the multi-tenancy boundary enforceable rather than just conventional.

---

## 6. Enums

```
PlanTier          = free | starter | pro | enterprise
UserRole          = owner | admin | editor | viewer
Platform          = instagram | facebook | threads | x | linkedin
SocialAccountStatus = connected | expired | revoked | error
ContentAssetType  = image | video
ApprovalStatus    = draft | pending_approval | approved | rejected
VariantStatus     = pending | ready | failed
PublishJobStatus  = queued | scheduled | processing | published | failed | cancelled
MetricType        = impressions | reach | likes | comments | shares | followers | engagement_rate
InviteStatus      = pending | accepted | expired | revoked
AIFeature         = caption | hashtags | tone | viral_score | best_time
```

Enums are implemented as native Postgres enum types (via Prisma `enum`), not free-text columns — this makes invalid states unrepresentable at the DB layer, not just validated in application code.

---

## 7. Prisma Models

> Schema definitions only — no resolvers, services, or business logic.

```prisma
// schema.prisma

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum PlanTier {
  free
  starter
  pro
  enterprise
}

enum UserRole {
  owner
  admin
  editor
  viewer
}

enum Platform {
  instagram
  facebook
  threads
  x
  linkedin
}

enum SocialAccountStatus {
  connected
  expired
  revoked
  error
}

enum ContentAssetType {
  image
  video
}

enum ApprovalStatus {
  draft
  pending_approval
  approved
  rejected
}

enum VariantStatus {
  pending
  ready
  failed
}

enum PublishJobStatus {
  queued
  scheduled
  processing
  published
  failed
  cancelled
}

enum MetricType {
  impressions
  reach
  likes
  comments
  shares
  followers
  engagement_rate
}

enum InviteStatus {
  pending
  accepted
  expired
  revoked
}

enum AIFeature {
  caption
  hashtags
  tone
  viral_score
  best_time
}

model Organization {
  id               String     @id @default(uuid())
  name             String
  planTier         PlanTier   @default(free)
  requiresApproval Boolean    @default(false)
  brandKit         BrandKit?
  ssoConfig        SsoConfig?
  users            User[]
  socialAccounts   SocialAccount[]
  contentAssets    ContentAsset[]
  templates        Template[]
  invites          Invite[]
  auditLogs        AuditLog[]
  aiUsageLogs      AiUsageLog[]
  createdAt        DateTime   @default(now())

  @@map("organization")
}

model User {
  id            String         @id @default(uuid())
  email         String         @unique
  passwordHash  String
  role          UserRole       @default(member: editor)
  orgId         String
  organization  Organization   @relation(fields: [orgId], references: [id])
  refreshTokens RefreshToken[]
  contentAssets ContentAsset[] @relation("CreatedAssets")
  comments      Comment[]
  auditLogs     AuditLog[]
  createdAt     DateTime       @default(now())

  @@index([orgId])
  @@map("user")
}

model RefreshToken {
  id        String   @id @default(uuid())
  userId    String
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  tokenHash String   @unique
  expiresAt DateTime
  revoked   Boolean  @default(false)

  @@index([userId, revoked])
  @@map("refresh_token")
}

model SocialAccount {
  id                String               @id @default(uuid())
  orgId             String
  organization      Organization         @relation(fields: [orgId], references: [id])
  platform          Platform
  externalAccountId String
  accessTokenEnc    String
  refreshTokenEnc   String?
  expiresAt         DateTime?
  status            SocialAccountStatus  @default(connected)
  publishJobs       PublishJob[]
  createdAt         DateTime             @default(now())

  @@unique([orgId, platform, externalAccountId])
  @@index([orgId])
  @@map("social_account")
}

model ContentAsset {
  id              String         @id @default(uuid())
  orgId           String
  organization    Organization   @relation(fields: [orgId], references: [id])
  createdById     String
  createdBy       User           @relation("CreatedAssets", fields: [createdById], references: [id])
  type            ContentAssetType
  canvasJson      Json
  templateId      String?
  template        Template?      @relation(fields: [templateId], references: [id])
  brandKitId      String?
  brandKit        BrandKit?      @relation(fields: [brandKitId], references: [id])
  approvalStatus  ApprovalStatus @default(draft)
  variants        ContentVariant[]
  comments        Comment[]
  createdAt       DateTime       @default(now())
  updatedAt       DateTime       @updatedAt

  @@index([orgId])
  @@index([orgId, approvalStatus])
  @@map("content_asset")
}

model ContentVariant {
  id                String        @id @default(uuid())
  assetId           String
  asset             ContentAsset  @relation(fields: [assetId], references: [id], onDelete: Cascade)
  platform          Platform
  renderedMediaUrl  String?
  caption           String?
  hashtags          String?
  status            VariantStatus @default(pending)
  publishJobs       PublishJob[]
  postMetrics       PostMetric[]

  @@index([assetId])
  @@map("content_variant")
}

model PublishJob {
  id              String            @id @default(uuid())
  variantId       String
  variant         ContentVariant    @relation(fields: [variantId], references: [id], onDelete: Cascade)
  socialAccountId String
  socialAccount   SocialAccount     @relation(fields: [socialAccountId], references: [id], onDelete: Restrict)
  scheduledAt     DateTime?
  status          PublishJobStatus  @default(queued)
  attemptCount    Int               @default(0)
  lastError       String?

  @@index([status, scheduledAt])
  @@index([variantId])
  @@map("publish_job")
}

model PostMetric {
  id          String       @id @default(uuid())
  variantId   String
  variant     ContentVariant @relation(fields: [variantId], references: [id], onDelete: Cascade)
  platform    Platform
  metricType  MetricType
  value       Decimal
  capturedAt  DateTime

  @@index([variantId, metricType, capturedAt])
  @@map("post_metric")
}

model Template {
  id            String         @id @default(uuid())
  orgId         String?
  organization  Organization?  @relation(fields: [orgId], references: [id])
  category      String
  canvasJson    Json
  isPublic      Boolean        @default(false)
  contentAssets ContentAsset[]
  createdAt     DateTime       @default(now())

  @@index([isPublic, category])
  @@map("template")
}

model BrandKit {
  id            String         @id @default(uuid())
  orgId         String         @unique
  organization  Organization   @relation(fields: [orgId], references: [id])
  colors        Json
  fonts         Json
  logoUrl       String?
  contentAssets ContentAsset[]

  @@map("brand_kit")
}

model Comment {
  id        String        @id @default(uuid())
  assetId   String
  asset     ContentAsset  @relation(fields: [assetId], references: [id], onDelete: Cascade)
  userId    String
  user      User          @relation(fields: [userId], references: [id])
  body      String
  createdAt DateTime      @default(now())

  @@index([assetId])
  @@map("comment")
}

model Invite {
  id           String       @id @default(uuid())
  orgId        String
  organization Organization @relation(fields: [orgId], references: [id])
  email        String
  role         UserRole
  token        String       @unique
  status       InviteStatus @default(pending)
  expiresAt    DateTime

  @@map("invite")
}

model AuditLog {
  id           String       @id @default(uuid())
  orgId        String
  organization Organization @relation(fields: [orgId], references: [id])
  userId       String?
  user         User?        @relation(fields: [userId], references: [id])
  action       String
  resourceType String
  resourceId   String?
  metadata     Json?
  timestamp    DateTime     @default(now())

  @@index([orgId, timestamp])
  @@map("audit_log")
}

model AiUsageLog {
  id        String     @id @default(uuid())
  orgId     String
  organization Organization @relation(fields: [orgId], references: [id])
  feature   AIFeature
  tokensUsed Int
  createdAt DateTime   @default(now())

  @@index([orgId, createdAt])
  @@map("ai_usage_log")
}

model SsoConfig {
  id             String       @id @default(uuid())
  orgId          String       @unique
  organization   Organization @relation(fields: [orgId], references: [id])
  idpEntityId    String
  idpMetadataUrl String
  enabled        Boolean      @default(false)

  @@map("sso_config")
}
```

*(Note: `role UserRole @default(member: editor)` above is illustrative shorthand — in real Prisma syntax this would simply be `role UserRole @default(editor)`; flagged here since this is schema definition, not business logic, and worth getting exactly right before the first migration.)*

---

## 8. Migration Strategy

- **One migration per schema-changing milestone**, generated via `prisma migrate dev` locally, named descriptively (`20260101_add_content_asset`, not `update_1`) — this keeps the migration history itself readable as a build log, matching the blueprint's milestone-by-milestone structure.
- **Additive-first discipline**: within a phase, prefer additive changes (new nullable columns, new tables) over destructive ones (dropping/renaming columns) so a mid-deploy rollback never leaves the app pointed at a schema it can't read.
- **Expand/contract pattern for breaking changes**: when a column must be renamed or a type changed, do it in two migrations across two deploys — (1) add the new column, dual-write, backfill; (2) remove the old column — never one migration that does both atomically in a live system.
- **Migration review is mandatory** (per the Git workflow's `CODEOWNERS` rule): the Database Architect reviews every PR touching `schema.prisma`, checking for missing indexes on new foreign keys and confirming cascade behavior is intentional, not default-accidental.
- **Staging-gate rule** (per the CI/CD strategy): a migration must run cleanly on staging before the same migration is permitted to run on production — enforced by the `deploy-production.yml` pipeline referencing the already-applied staging migration state, not re-running blind.
- **Seed data** (`prisma/seed.ts`) is environment-aware: local/staging seed realistic fixture data (fake orgs, sandbox social accounts); production seed is limited to genuinely static reference data only (e.g., plan tier definitions), never fake accounts.
- **No down-migrations relied upon in production**: Postgres migrations here are forward-only:  a bad migration is fixed by a new forward migration, not a `down` script, because destructive rollbacks against live data are a much higher-risk operation than shipping a fix forward.

---

## 9. Scalability Considerations

- **`post_metric` is the highest-growth table by far** (time-series, one row per metric per variant per capture interval). Plan for:
  - **Partitioning by `captured_at`** (monthly range partitions) once volume justifies it — keeps index size and vacuum cost manageable as history accumulates.
  - **Aggregation rollups**: a scheduled job that pre-aggregates daily/weekly summaries into a separate `post_metric_daily` rollup table for dashboard queries, so the dashboard doesn't scan raw per-capture rows as history grows into years.
- **`publish_job` and `audit_log` are append-heavy, read-light-recent**: both are good candidates for periodic archival of old rows (e.g., >12 months) into cold storage (S3 + Athena/Glue) rather than keeping unbounded history in the hot Postgres instance.
- **Multi-tenancy scaling path**: current design is a single shared Postgres instance with `org_id`-scoped rows (shared-schema multi-tenancy). This is the right starting point for cost and simplicity. If a small number of Enterprise customers later need hard data isolation (compliance requirement, not just scale), the schema's consistent `org_id` scoping makes it straightforward to peel a specific org into a dedicated schema or database without redesigning tables — the boundary is already explicit everywhere.
- **Read replicas**: analytics dashboard queries (Phase 10) are read-heavy and tolerant of slight staleness — route `analytics.resolver.ts` queries to a read replica once write load on the primary becomes a contention point, rather than scaling the primary vertically indefinitely.
- **Connection pooling**: NestJS + Prisma against RDS should sit behind PgBouncer (or RDS Proxy) once concurrent background workers (BullMQ processors) plus API instances start approaching Postgres's native connection limits — this becomes relevant once Phase 8's five parallel platform-queue processors are all running concurrently in production.
- **JSONB fields (`canvas_json`) are intentionally schemaless** for editor flexibility, but that means they're **not indexed for querying by internal structure** — any future feature needing to query "designs containing a video layer," for example, would need either a GIN index on the JSONB column or a denormalized boolean/enum column added alongside it. Don't reach for deep JSONB querying as a default; add a real column when a real query need appears.

---

## 10. Schema delta since initial design

*(Reconciliation as of 2026-08-22. The live schema is `backend/prisma/schema.prisma`;
these are the tables/enums/fields added after §1–7 were written. Field-level detail
lives in the Prisma file to avoid re-drift.)*

**New models (Phases 16–19 + auth follow-ups):**

| Model | Purpose |
|---|---|
| `Subscription` | Stripe subscription state per org (customer/subscription id, `planTier`, `SubscriptionStatus`, period end, cancel-at-period-end). Billing (Phase 18). |
| `Invoice` | Per-org invoice records mirrored from Stripe (amount due/paid, currency, status, hosted URL). Billing (Phase 18). |
| `Notification` | Per-user in-app notifications (`type`, `title`, `body`, `linkPath`, `readAt`). Phase 19. |
| `MediaAsset` | Persistent org-scoped media library items (`url`, `publicId`, `type`, `name`, `posterUrl`). Phase 19. |
| `MfaRecoveryCode` | One-time TOTP recovery codes. Phase 17.3. |
| `UserToken` | Single-use, expiring tokens (`UserTokenType`, hashed, `consumedAt`) — email verification, password reset, and the Google login handoff. Phase 17.1 / Google auth. |
| `DataDeletionRequest` | Meta data-deletion callback tracking. Phase 16. |
| `IngestionRun` | Analytics ingestion run bookkeeping (`IngestionStatus`). Phase 10 ingestion cron. |

**New enums:** `SubscriptionStatus`, `UserTokenType` (`email_verification`,
`password_reset`, `google_login_handoff`), `IngestionStatus`.

**`User` model changes:**
- `passwordHash` is now **nullable** (accounts that only sign in with Google have none).
- Added `googleId` (unique, nullable) — links a Google identity.
- Added `emailVerifiedAt` (Phase 17.1), `mfaEnabled` + `mfaSecretEnc` (Phase 17.3),
  and the `notifications` relation.

**Corrections to §7 as written:**
- `User.role` uses `@default(editor)` (the doc's `@default(member: editor)` was never
  valid Prisma and does not match the code).
- `AIUsageLog` is the actual model name (doc shows `AiUsageLog`).

**Migration reality:** migrations are applied with `prisma migrate deploy` (or
`migrate dev` locally) — there is no `deploy-production.yml`, `CODEOWNERS` review gate,
or `prisma/seed.ts` in the repo yet; §8's references to those remain aspirational.
