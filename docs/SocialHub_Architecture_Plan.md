# SocialHub — Architecture & Planning Document

## 1. Product Vision Analysis

SocialHub's core promise — *Create Once → Optimize Automatically → Publish Everywhere* — is really three products stitched into one funnel:

1. **A design tool** (Canva-competitor)
2. **A publishing/automation engine** (Buffer/Hootsuite-competitor)
3. **An analytics layer** (Later/Sprout-competitor)

The hardest part isn't any single feature — it's the **seams between them**. A design created in the editor has to survive a lossless handoff into platform-specific renditions, each with different aspect ratios, compression, caption limits, and metadata requirements, and then get analytics attributed back to the *original* content object, not five disconnected posts. That traceability (content → variant → publish job → performance) is the architectural spine everything else hangs off of.

---

## 2. Key Technical Challenges

| Challenge | Why it's hard |
|---|---|
| Multi-platform publishing reliability | Each platform has different rate limits, media specs, auth flows, and failure modes. One slow/down platform must not block others. |
| Editor performance in Flutter Web | Canvas-heavy apps (layers, undo/redo, real-time filters) are CPU/GPU intensive; Flutter Web's rendering (CanvasKit vs HTML renderer) affects this significantly. |
| Token lifecycle management | OAuth tokens expire, get revoked, or require re-consent — publishing must degrade gracefully, not silently fail. |
| Content-to-variant consistency | Auto-generating 5 platform versions from 1 asset while preserving brand intent (not just blind resizing). |
| AI cost control | Captions, hashtags, viral scoring, etc. at scale can create runaway inference costs — needs caching, batching, and tiered access. |
| Analytics normalization | Each platform reports metrics differently (e.g., "reach" vs "impressions" definitions vary) — needs a canonical schema with platform-specific mapping. |
| PWA installability + offline editing | Users mid-edit should not lose work on network drop; requires local-first state with sync reconciliation. |

---

## 3. Social Platform API Constraints (as of current public documentation)

> These change frequently — before implementation, each adapter should be verified against the live developer docs.

- **Instagram (via Meta Graph API):** Requires a connected Facebook Page + Instagram Business/Creator account. Images/videos must be publicly hosted at a URL (no direct binary upload) — this drives the need for a media CDN (Cloudinary/S3) in the pipeline. Strict aspect ratio and duration limits for Reels vs feed vs Stories.
- **Facebook (Graph API):** Page-level publishing needs `pages_manage_posts` permission and goes through App Review for production access. Feed, Reels, and Stories each have distinct endpoints.
- **Threads API:** Newer, more limited — narrower media type support and stricter rate limits than Instagram/Facebook; no full feature parity yet with Meta's more mature APIs.
- **X (Twitter) API:** Tiered access (Free/Basic/Pro/Enterprise) gates posting volume and media upload endpoints — pricing tier directly caps product tier (e.g., a "Free plan" user in SocialHub may not be able to auto-publish to X at all without a paid X API tier on the backend).
- **LinkedIn API:** Organization (Company Page) posting requires partner-level access approval for many endpoints; personal profile posting has a narrower, more accessible API surface.

**Design implication:** every adapter must expose a `capabilities()` contract (supported media types, max duration, caption length, rate limit window) so the editor and scheduler can validate *before* attempting a publish, not after a failure.

---

## 4. Recommended Overall Architecture

**Pattern:** Modular monolith at MVP → extract to services at V1/V2 as load justifies it. A full microservices split on day one is a common early-stage SaaS mistake — it multiplies operational cost before there's traffic to justify it.

```
┌─────────────────────────────────────────────┐
│              Flutter Web (PWA)                │
│  Editor · Dashboard · Scheduler · Analytics    │
└───────────────────┬───────────────────────────┘
                     │ REST/GraphQL (BFF layer)
┌───────────────────▼───────────────────────────┐
│                NestJS API Gateway               │
│   Auth · RBAC · Rate Limiting · Validation      │
└───┬────────┬────────┬────────┬────────┬────────┘
    │        │        │        │        │
 Content   Publishing  AI     Analytics  Billing
 Module    Module     Module   Module    Module
    │        │        │        │        │
┌───▼────────▼────────▼────────▼────────▼────┐
│      PostgreSQL (Prisma) + Redis (queues)     │
└───────────────────────────────────────────────┘
    │
 Background Workers (BullMQ) → Platform Adapters → Social APIs
    │
 Cloudinary/S3 (media) · CloudWatch/Datadog (observability)
```

Each "module" above follows Clean Architecture internally: **controller → use-case → domain → repository**, so the eventual extraction into a standalone service (if warranted at scale) is a deployment change, not a rewrite.

---

## 5. Database Schema (Core Entities)

```
User (id, email, password_hash, role, org_id, created_at)
Organization (id, name, plan_tier, brand_kit_id)
SocialAccount (id, user_id, platform, access_token_enc, refresh_token_enc, expires_at, status)
ContentAsset (id, org_id, type[image/video], canvas_json, brand_kit_id, created_by, created_at)
ContentVariant (id, asset_id, platform, rendered_media_url, caption, hashtags, status)
PublishJob (id, variant_id, social_account_id, scheduled_at, status, attempt_count, last_error)
PostMetric (id, variant_id, platform, metric_type, value, captured_at)
Template (id, org_id, category, canvas_json, is_public)
BrandKit (id, org_id, colors, fonts, logo_url)
AuditLog (id, user_id, action, resource_type, resource_id, timestamp)
```

Key relationships: one `ContentAsset` → many `ContentVariant` (one per platform) → each variant has its own `PublishJob` and its own `PostMetric` stream. This is what keeps "one piece of content, five platform outcomes" queryable as a single unit later in analytics.

---

## 6. REST API Design (Representative Endpoints)

```
POST   /auth/register | /auth/login | /auth/refresh
POST   /social-accounts/:platform/connect        (OAuth init)
GET    /social-accounts                          (list connected)

POST   /content/assets                           (create design)
PATCH  /content/assets/:id                        (autosave canvas state)
POST   /content/assets/:id/variants               (generate platform variants)

POST   /ai/caption                                 (generate caption)
POST   /ai/hashtags
POST   /ai/best-time

POST   /publish/schedule                           (queue PublishJob(s))
GET    /publish/jobs/:id/status

GET    /analytics/overview?org_id=
GET    /analytics/posts/:variant_id
```

GraphQL is layered in only for the analytics/dashboard aggregation views, where clients need to compose nested, variable-shaped queries (e.g., "give me top 5 posts across 3 platforms with 4 metrics each") — REST would otherwise require many round trips.

---

## 7. Flutter Web Architecture

- **State management:** Riverpod (testable, no BuildContext coupling — good fit for a large modular app).
- **Structure:** Feature-first folders (`/features/editor`, `/features/scheduler`, `/features/analytics`), each with `data/domain/presentation` layers.
- **Rendering:** CanvasKit renderer for the editor (better fidelity for canvas-heavy work); evaluate HTML renderer for marketing/dashboard-only routes to reduce initial bundle size.
- **PWA:** `manifest.json` + service worker for offline shell caching; editor autosaves to local storage (Hive/IndexedDB) with sync-on-reconnect to avoid losing in-progress designs.
- **Editor engine:** Custom `CustomPainter`-based canvas rather than a heavy third-party package, to keep full control over layers/undo-redo/smart-guides performance.
- **Responsive strategy:** Desktop-first layout with breakpoint-driven collapsing (toolbars → bottom sheets on mobile web).

---

## 8. Backend Architecture

- **Framework:** NestJS (modular, DI-native, matches the Clean Architecture module boundaries above).
- **ORM:** Prisma + PostgreSQL, with row-level org scoping enforced at the repository layer (not just application logic) to prevent cross-tenant leaks.
- **Queueing:** Redis + BullMQ for publish jobs, AI generation jobs, and media rendering — each platform adapter runs as an isolated queue/worker so a Meta API outage doesn't back up LinkedIn publishing.
- **AI Engineer's note:** Route AI calls through an internal `AIGateway` service, not directly from controllers — this lets you swap models/providers, add caching, and enforce per-plan usage quotas in one place.
- **Security Engineer's note:** OAuth tokens stored encrypted at rest (KMS-managed key), never returned in any API response, rotated on refresh.

---

## 9. Deployment Architecture

- **Containers:** Docker for all services; docker-compose for local dev parity.
- **Orchestration:** Start on AWS ECS Fargate (lower ops overhead than EKS at MVP stage); revisit Kubernetes only if workload diversity/scale demands it.
- **CI/CD:** GitHub Actions — lint/test → build image → push to ECR → deploy; separate pipelines for Flutter Web (build → S3/CloudFront) and NestJS backend.
- **Media:** Cloudinary for transformation-heavy needs (auto-cropping per platform spec) fronted by CDN.
- **Observability:** Structured logging → CloudWatch, error tracking via Sentry, uptime/queue health dashboards.

---

## 10. UI/UX System

- **Design tokens:** Centralized color/spacing/typography scale (Stripe-dashboard-like restraint: neutral base palette, one accent color, generous whitespace).
- **Modes:** Light/dark via theme tokens, not hardcoded colors, from day one.
- **Navigation:** Persistent left rail (Notion/Linear-style) for desktop; collapses to bottom nav on mobile web.
- **Editor UX:** Right-side contextual property panel (Canva pattern) rather than modal-heavy editing, to keep flow uninterrupted.

---

## 11. Phased Roadmap

**MVP (prove the core loop)**
- Auth, single-org accounts, connect 2 platforms (e.g., Instagram + X)
- Basic editor (image only, core tools: crop/resize/text/layers)
- Manual publish (no scheduling queue yet) to connected platforms
- Simple caption AI (one model call, no tone/viral-score layer yet)

**V1 (make it a real product)**
- All 5 platforms, full scheduling + queue-based publishing with retries
- Full editor feature set (video, templates, brand kit)
- Unified analytics dashboard
- Team roles/RBAC

**V2 (differentiate)**
- Full AI suite (viral score, best time, tone conversion, content calendar)
- Collaboration (comments, approval workflows)
- Template marketplace

**Enterprise**
- SSO/SAML, advanced audit logs, dedicated rate-limit pools per org, white-labeling, SLA-backed uptime

---

### Suggested next step
Pick one MVP module (I'd suggest starting with **auth + social account OAuth connection**, since every other feature depends on it) and we build that end-to-end — schema, API, and Flutter screens — before moving to the next.
