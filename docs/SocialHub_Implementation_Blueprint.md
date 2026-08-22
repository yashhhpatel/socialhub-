# SocialHub — Implementation Blueprint
### Phases → Milestones (no code, planning only)

Each **Phase** defines the scope. Each **Milestone** inside it is sized to ~1–3 hours of focused work and builds on the one before it.

> **Implementation status (as of 2026-08-22):** **Phases 0–15 are implemented**, as are
> the four follow-on phases (16 Meta compliance, 17 account security, 18 billing, 19
> notifications + media library) that were originally proposed in `GAP_ANALYSIS.md`.
> Only **Phase 20 (production hardening / GA)** remains open. This document is retained
> as the planning/history record; for the live, per-feature status and the current gap
> list, see **`GAP_ANALYSIS.md`** (the reconciled source of truth).

---

# PHASE 0 — Project Foundation & Tooling

**Goal:** A working, empty skeleton that all future work plugs into.
**Features:** Repo structure, CI skeleton, local dev environment.
**Frontend tasks:** Initialize Flutter Web project, folder structure (feature-first), theme token scaffold, routing skeleton (go_router).
**Backend tasks:** Initialize NestJS project, module folder structure, config module (env validation), health-check endpoint.
**Database tasks:** Provision PostgreSQL (local via Docker), initialize Prisma, empty base schema.
**APIs to implement:** `GET /health`
**Third-party integrations:** None yet.
**UI components:** App shell (empty nav rail + content area), light/dark theme toggle stub.
**Testing requirements:** CI runs `flutter analyze`, `flutter test` (smoke), `nest test` (smoke) on every push.
**Dependencies:** None — this is the root.
**Estimated complexity:** Low.
**Definition of Done:** `docker-compose up` boots Postgres + backend + frontend locally; CI pipeline is green on an empty commit.

### Milestone 0.1 — Repo & Monorepo Structure
- Prerequisites: none
- Files/folders created: `/frontend`, `/backend`, `/docs`, `.github/workflows/ci.yml`, root `README.md`, `.gitignore`
- Files/folders modified: none
- Expected output: Two empty-but-runnable apps side by side in one repo with CI wired to both
- Git commit message: `chore: initialize monorepo structure with CI skeleton`

### Milestone 0.2 — Flutter Web App Shell
- Prerequisites: 0.1
- Files/folders created: `/frontend/lib/app`, `/frontend/lib/core/theme`, `/frontend/lib/core/router`, `/frontend/web/manifest.json`
- Files/folders modified: `/frontend/pubspec.yaml`
- Expected output: Blank installable PWA shell with light/dark theme toggle and empty route table
- Git commit message: `feat(frontend): app shell, theming, and PWA manifest`

### Milestone 0.3 — NestJS API Skeleton + Config
- Prerequisites: 0.1
- Files/folders created: `/backend/src/config`, `/backend/src/health`, `/backend/.env.example`
- Files/folders modified: `/backend/src/app.module.ts`
- Expected output: `GET /health` returns 200 with env validated at boot
- Git commit message: `feat(backend): config module, env validation, health endpoint`

### Milestone 0.4 — Database Provisioning & Prisma Init
- Prerequisites: 0.3
- Files/folders created: `/backend/prisma/schema.prisma`, `/backend/docker-compose.yml`
- Files/folders modified: `/backend/.env.example`
- Expected output: `prisma migrate dev` runs cleanly against local Postgres with zero models
- Git commit message: `chore(db): provision Postgres and initialize Prisma`

---

# PHASE 1 — Auth & Multi-Tenant Org Model

**Goal:** Users can register, log in, and belong to an organization.
**Features:** Register, login, JWT + refresh tokens, org creation on signup.
**Frontend tasks:** Login/register screens, auth state (Riverpod), protected route guard, token storage/refresh interceptor.
**Backend tasks:** Auth module (JWT strategy), password hashing, refresh-token rotation, org auto-creation on signup, RBAC guard scaffold (roles: owner/admin/member — enforcement expands in Phase 11).
**Database tasks:** `User`, `Organization`, `RefreshToken` tables + migration.
**APIs to implement:** `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /users/me`
**Third-party integrations:** None.
**UI components:** Auth form components, toast/error banner, loading button.
**Testing requirements:** Backend unit tests for auth service (hash, token issuance, refresh rotation); frontend widget test for login form validation; one e2e happy-path test (register → login → fetch profile).
**Dependencies:** Phase 0 complete.
**Estimated complexity:** Medium.
**Definition of Done:** A new user can register, receive a session, refresh it, and hit a protected endpoint from the Flutter app.

### Milestone 1.1 — Backend Auth Module
- Prerequisites: 0.4
- Files/folders created: `/backend/src/auth/*`, `/backend/src/users/*`
- Files/folders modified: `schema.prisma`, `app.module.ts`
- Expected output: `/auth/register` and `/auth/login` work via Postman/curl, returning access + refresh tokens
- Git commit message: `feat(backend): auth module with JWT + refresh token rotation`

### Milestone 1.2 — Org Auto-Creation & RBAC Guard Scaffold
- Prerequisites: 1.1
- Files/folders created: `/backend/src/organizations/*`, `/backend/src/common/guards/roles.guard.ts`
- Files/folders modified: `schema.prisma` (add `Organization`, `org_id` on `User`)
- Expected output: Registering a user creates an org and assigns `owner` role; `@Roles()` decorator usable on any route
- Git commit message: `feat(backend): organization model and RBAC guard scaffold`

### Milestone 1.3 — Frontend Auth Screens & State
- Prerequisites: 0.2
- Files/folders created: `/frontend/lib/features/auth/*`
- Files/folders modified: `/frontend/lib/core/router/app_router.dart`
- Expected output: Login/register UI functional against a mocked auth provider
- Git commit message: `feat(frontend): auth screens with Riverpod state`

### Milestone 1.4 — Wire Frontend Auth to Backend + Token Refresh Interceptor
- Prerequisites: 1.1, 1.3
- Files/folders created: `/frontend/lib/core/network/auth_interceptor.dart`
- Files/folders modified: `/frontend/lib/features/auth/*`
- Expected output: Full login flow works end-to-end; expired tokens silently refresh
- Git commit message: `feat(frontend): connect auth flow to backend with token refresh`

---

# PHASE 2 — Social Account Connection (OAuth) — MVP Platforms

**Goal:** Users can connect Instagram and X accounts to their org.
**Features:** OAuth connect/disconnect flow, encrypted token storage, connection status display.
**Frontend tasks:** "Connected Accounts" settings screen, OAuth redirect handling, connection status cards.
**Backend tasks:** OAuth module per platform, token encryption service (KMS or app-level AES), platform adapter interface (`capabilities()`, `connect()`, `refresh()`).
**Database tasks:** `SocialAccount` table (encrypted token columns).
**APIs to implement:** `GET /social-accounts`, `POST /social-accounts/:platform/connect`, `DELETE /social-accounts/:id`, OAuth callback routes.
**Third-party integrations:** Meta Graph API (Instagram), X API (developer app registration required for both, sandbox credentials for dev).
**UI components:** Connection card, OAuth popup/redirect handler, empty state.
**Testing requirements:** Backend integration tests using mocked platform OAuth responses; token encryption round-trip test; frontend widget test for connection card states (connected/disconnected/error).
**Dependencies:** Phase 1 complete.
**Estimated complexity:** Medium-High (external API/OAuth quirks).
**Definition of Done:** A user can connect a real Instagram or X sandbox account and see it listed as connected, with tokens encrypted at rest.

### Milestone 2.1 — Platform Adapter Interface & Token Encryption Service
- Prerequisites: 1.2
- Files/folders created: `/backend/src/social-accounts/adapters/adapter.interface.ts`, `/backend/src/common/crypto/token-encryption.service.ts`
- Files/folders modified: none
- Expected output: Interface contract defined; encryption service passes round-trip unit test
- Git commit message: `feat(backend): platform adapter interface and token encryption service`

### Milestone 2.2 — SocialAccount Model + Instagram OAuth Adapter
- Prerequisites: 2.1
- Files/folders created: `/backend/src/social-accounts/adapters/instagram.adapter.ts`
- Files/folders modified: `schema.prisma`
- Expected output: `POST /social-accounts/instagram/connect` completes OAuth against sandbox and stores encrypted tokens
- Git commit message: `feat(backend): Instagram OAuth adapter and SocialAccount model`

### Milestone 2.3 — X (Twitter) OAuth Adapter
- Prerequisites: 2.1
- Files/folders created: `/backend/src/social-accounts/adapters/x.adapter.ts`
- Files/folders modified: `/backend/src/social-accounts/social-accounts.service.ts`
- Expected output: X connect/disconnect works against sandbox credentials
- Git commit message: `feat(backend): X (Twitter) OAuth adapter`

### Milestone 2.4 — Frontend Connected Accounts Screen
- Prerequisites: 2.2, 2.3, 1.4
- Files/folders created: `/frontend/lib/features/social_accounts/*`
- Files/folders modified: `/frontend/lib/core/router/app_router.dart`
- Expected output: Settings screen lists real connection state, connect/disconnect buttons functional
- Git commit message: `feat(frontend): connected accounts settings screen`

---

# PHASE 3 — Content Asset Model & Basic Editor (Image Only)

**Goal:** Users can create and save a simple image design.
**Features:** Canvas with text/image layers, crop, resize, rotate, undo/redo, autosave.
**Frontend tasks:** `CustomPainter`-based canvas engine, layer panel, property panel, undo/redo stack, autosave debounce.
**Backend tasks:** Content module, canvas JSON persistence, autosave endpoint.
**Database tasks:** `ContentAsset` table (canvas_json as JSONB).
**APIs to implement:** `POST /content/assets`, `PATCH /content/assets/:id`, `GET /content/assets/:id`, `GET /content/assets`
**Third-party integrations:** Cloudinary (image upload/storage for user-added images).
**UI components:** Canvas surface, layer list, toolbar, property panel, image upload dropzone.
**Testing requirements:** Frontend unit tests for undo/redo stack logic; backend tests for autosave debounce/versioning; one e2e test (create asset → edit → reload → state persists).
**Dependencies:** Phase 1 complete (assets belong to an org/user).
**Estimated complexity:** High (canvas engine is the most complex frontend piece in the whole product).
**Definition of Done:** A user can create a single-image design with a text layer, resize/rotate it, undo/redo changes, and have it persist across a page reload.

### Milestone 3.1 — ContentAsset Backend Model + Autosave Endpoint
- Prerequisites: 1.2
- Files/folders created: `/backend/src/content/*`
- Files/folders modified: `schema.prisma`
- Expected output: `PATCH /content/assets/:id` accepts arbitrary canvas JSON and persists it
- Git commit message: `feat(backend): content asset model with autosave endpoint`

### Milestone 3.2 — Cloudinary Upload Integration
- Prerequisites: 3.1
- Files/folders created: `/backend/src/media/cloudinary.service.ts`
- Files/folders modified: `/backend/src/content/content.controller.ts`
- Expected output: Image upload returns a hosted URL usable inside canvas JSON
- Git commit message: `feat(backend): Cloudinary media upload integration`

### Milestone 3.3 — Canvas Engine Core (render + select + move)
- Prerequisites: 0.2
- Files/folders created: `/frontend/lib/features/editor/canvas/*`
- Files/folders modified: none
- Expected output: Canvas renders shapes/images/text and supports select + drag
- Git commit message: `feat(frontend): core canvas engine with layer selection and drag`

### Milestone 3.4 — Layer Panel, Property Panel, Toolbar
- Prerequisites: 3.3
- Files/folders created: `/frontend/lib/features/editor/panels/*`
- Files/folders modified: `/frontend/lib/features/editor/editor_screen.dart`
- Expected output: Selecting a layer shows editable properties (position, size, rotation, color)
- Git commit message: `feat(frontend): layer panel and property panel`

### Milestone 3.5 — Undo/Redo + Autosave Wiring
- Prerequisites: 3.4, 3.2
- Files/folders created: `/frontend/lib/features/editor/state/history_controller.dart`
- Files/folders modified: `/frontend/lib/features/editor/editor_screen.dart`
- Expected output: Ctrl+Z/Ctrl+Y work; changes autosave to backend with debounce and reload correctly
- Git commit message: `feat(frontend): undo/redo stack and autosave integration`

---

# PHASE 4 — Manual Publish Pipeline (MVP)

**Goal:** A finished design can be published immediately (no scheduling yet) to a connected Instagram or X account.
**Features:** Platform variant preview, manual "Publish Now," publish status feedback.
**Frontend tasks:** Publish modal (platform picker + preview), publish status indicator.
**Backend tasks:** `ContentVariant` generation (basic — resize per platform spec), `PublishJob` creation, synchronous publish call through the relevant adapter (async queue arrives in Phase 7).
**Database tasks:** `ContentVariant`, `PublishJob` tables.
**APIs to implement:** `POST /content/assets/:id/variants`, `POST /publish/now`, `GET /publish/jobs/:id`
**Third-party integrations:** Instagram + X publish endpoints (media upload + post creation).
**UI components:** Publish modal, per-platform preview card, status badge (pending/success/failed).
**Testing requirements:** Backend integration test mocking each platform's publish endpoint (success + failure paths); frontend test for publish modal state transitions.
**Dependencies:** Phase 2, Phase 3 complete.
**Estimated complexity:** Medium-High.
**Definition of Done:** A user can take a saved design, preview platform-specific renditions, click Publish, and see a live post appear on a connected sandbox/test account.

### Milestone 4.1 — Variant Generation Service (Resize/Crop per Platform Spec)
- Prerequisites: 3.5, 2.4
- Files/folders created: `/backend/src/content/variant-generator.service.ts`
- Files/folders modified: `schema.prisma`
- Expected output: `POST /content/assets/:id/variants` produces correctly-sized outputs per platform capability contract
- Git commit message: `feat(backend): platform-specific content variant generation`

### Milestone 4.2 — Publish Service (Synchronous, Instagram + X)
- Prerequisites: 4.1
- Files/folders created: `/backend/src/publishing/*`
- Files/folders modified: `schema.prisma`
- Expected output: `POST /publish/now` posts to a real sandbox Instagram/X account and records a `PublishJob` result
- Git commit message: `feat(backend): synchronous publish service for MVP platforms`

### Milestone 4.3 — Frontend Publish Modal & Status Feedback
- Prerequisites: 4.2
- Files/folders created: `/frontend/lib/features/publish/*`
- Files/folders modified: `/frontend/lib/features/editor/editor_screen.dart`
- Expected output: Full click-to-publish flow works from the editor with live status feedback
- Git commit message: `feat(frontend): publish modal with platform preview and status`

---

# PHASE 5 — AI Caption Generation (MVP)

**Goal:** Users can generate a caption suggestion inside the editor/publish flow.
**Features:** One-click AI caption generation, editable output, basic usage cap per org plan.
**Frontend tasks:** "Generate caption" button + result panel inside publish modal, loading/error states.
**Backend tasks:** `AIGateway` service (provider-agnostic wrapper), caption prompt template, per-org usage quota check.
**Database tasks:** `AIUsageLog` table (for quota tracking).
**APIs to implement:** `POST /ai/caption`
**Third-party integrations:** Anthropic API (Claude) for generation.
**UI components:** Caption suggestion panel, regenerate button, quota-reached banner.
**Testing requirements:** Backend test for quota enforcement; mocked AI response test (no live API calls in CI); frontend test for loading/error/success states.
**Dependencies:** Phase 4 complete (captions live inside the publish flow).
**Estimated complexity:** Low-Medium.
**Definition of Done:** From the publish modal, a user can generate a caption suggestion, edit it, and publish with it — with quota enforcement working.

### Milestone 5.1 — AIGateway Service + Caption Endpoint
- Prerequisites: 1.2
- Files/folders created: `/backend/src/ai/ai-gateway.service.ts`, `/backend/src/ai/ai.controller.ts`
- Files/folders modified: `schema.prisma`
- Expected output: `POST /ai/caption` returns a generated caption given asset context
- Git commit message: `feat(backend): AI gateway service with caption generation`

### Milestone 5.2 — Usage Quota Enforcement
- Prerequisites: 5.1
- Files/folders created: `/backend/src/ai/quota.guard.ts`
- Files/folders modified: `schema.prisma`
- Expected output: Requests beyond plan quota return a clear 429 with reset time
- Git commit message: `feat(backend): AI usage quota enforcement per org plan`

### Milestone 5.3 — Frontend Caption Panel in Publish Modal
- Prerequisites: 5.1, 4.3
- Files/folders created: `/frontend/lib/features/publish/widgets/caption_panel.dart`
- Files/folders modified: `/frontend/lib/features/publish/publish_modal.dart`
- Expected output: Generate/edit/regenerate caption flow fully functional
- Git commit message: `feat(frontend): AI caption generation panel`

---

# PHASE 6 — MVP Polish, Testing & Deploy

**Goal:** Ship the MVP to a live environment.
**Features:** Error boundary handling, empty states, deploy pipeline, smoke monitoring.
**Frontend tasks:** Global error boundary, empty/loading states audit across all MVP screens, PWA install prompt polish.
**Backend tasks:** Global exception filter, request logging, rate limiting on public endpoints.
**Database tasks:** Migration review/squash for MVP schema baseline.
**APIs to implement:** None new — hardening pass only.
**Third-party integrations:** Sentry (error tracking), CloudWatch (logs).
**UI components:** Error boundary screen, 404 screen, offline banner.
**Testing requirements:** Full MVP regression pass (register → connect account → design → publish → view result); load test on `/publish/now` and `/ai/caption`.
**Dependencies:** Phases 1–5 complete.
**Estimated complexity:** Medium.
**Definition of Done:** MVP is deployed to a staging URL, passes the full regression checklist, and has error/log monitoring active.

### Milestone 6.1 — Global Error Handling (Frontend + Backend)
- Prerequisites: 5.3
- Files/folders created: `/frontend/lib/core/error/error_boundary.dart`, `/backend/src/common/filters/http-exception.filter.ts`
- Files/folders modified: `/backend/src/main.ts`, `/frontend/lib/app/app.dart`
- Expected output: Unhandled errors show a graceful fallback UI/JSON, not a crash
- Git commit message: `feat: global error handling for frontend and backend`

### Milestone 6.2 — CI/CD Deploy Pipeline (Staging)
- Prerequisites: 6.1
- Files/folders created: `.github/workflows/deploy-staging.yml`, `/backend/Dockerfile`, `/frontend/Dockerfile` (or S3/CloudFront build step)
- Files/folders modified: none
- Expected output: Merge to `main` auto-deploys backend + frontend to staging
- Git commit message: `ci: staging deploy pipeline for backend and frontend`

### Milestone 6.3 — Monitoring & MVP Regression Pass
- Prerequisites: 6.2
- Files/folders created: `/docs/mvp-regression-checklist.md`
- Files/folders modified: `/backend/src/main.ts` (Sentry init)
- Expected output: Sentry capturing errors on staging; full manual regression checklist passes
- Git commit message: `chore: monitoring setup and MVP regression sign-off`

---

# PHASE 7 — Scheduling & Queue-Based Publishing (V1 start)

**Goal:** Publishing moves from synchronous to a reliable, retryable background queue with scheduling.
**Features:** Schedule for future date/time, automatic retries, per-platform failure isolation.
**Frontend tasks:** Scheduler UI (date/time picker), content calendar list view, job status per scheduled post.
**Backend tasks:** Redis + BullMQ setup, one queue per platform, retry/backoff policy, cron trigger for due jobs.
**Database tasks:** Extend `PublishJob` with `scheduled_at`, `attempt_count`, `last_error`.
**APIs to implement:** `POST /publish/schedule`, `GET /publish/jobs?status=`, `DELETE /publish/jobs/:id`
**Third-party integrations:** Redis (managed, e.g. ElastiCache).
**UI components:** Date/time picker, calendar/list toggle, job status timeline.
**Testing requirements:** Queue integration tests (job succeeds, job fails and retries, job exhausts retries); frontend test for scheduling form validation.
**Dependencies:** Phase 6 complete (MVP live).
**Estimated complexity:** Medium-High.
**Definition of Done:** A post scheduled for a future time publishes automatically; a simulated platform outage retries without affecting other platforms' jobs.

### Milestone 7.1 — Redis + BullMQ Infrastructure
- Prerequisites: 6.3
- Files/folders created: `/backend/src/queue/queue.module.ts`, `/backend/docker-compose.yml` (redis service)
- Files/folders modified: `.env.example`
- Expected output: A test job can be enqueued and processed locally
- Git commit message: `feat(backend): Redis and BullMQ queue infrastructure`

### Milestone 7.2 — Per-Platform Publish Queues + Retry Policy
- Prerequisites: 7.1, 4.2
- Files/folders created: `/backend/src/publishing/processors/*.processor.ts`
- Files/folders modified: `/backend/src/publishing/publishing.service.ts`
- Expected output: Publish jobs run through isolated per-platform queues with exponential backoff retries
- Git commit message: `feat(backend): isolated per-platform publish queues with retry policy`

### Milestone 7.3 — Scheduling Endpoint + Cron Trigger
- Prerequisites: 7.2
- Files/folders created: `/backend/src/publishing/schedule.cron.ts`
- Files/folders modified: `schema.prisma`
- Expected output: `POST /publish/schedule` queues a future job that fires automatically at the right time
- Git commit message: `feat(backend): scheduled publishing with cron trigger`

### Milestone 7.4 — Frontend Scheduler & Calendar View
- Prerequisites: 7.3
- Files/folders created: `/frontend/lib/features/scheduler/*`
- Files/folders modified: `/frontend/lib/features/publish/publish_modal.dart`
- Expected output: User can pick a future date/time and see it on a calendar/list view with live status
- Git commit message: `feat(frontend): content scheduler and calendar view`

---

# PHASE 8 — Remaining Platform Adapters (Facebook, Threads, LinkedIn)

**Goal:** All five target platforms are supported end-to-end.
**Features:** Connect, variant generation, and publish for Facebook, Threads, LinkedIn.
**Frontend tasks:** Extend connected accounts screen and publish modal for 3 new platforms.
**Backend tasks:** Three new adapters implementing the existing `adapter.interface.ts` contract; capability specs per platform.
**Database tasks:** None new (schema already generic).
**APIs to implement:** None new — adapters plug into existing endpoints.
**Third-party integrations:** Meta Graph API (Facebook Pages), Threads API, LinkedIn API.
**UI components:** Platform icons/branding, platform-specific caption limit warnings.
**Testing requirements:** Integration tests per adapter (mocked); one live sandbox smoke test per platform.
**Dependencies:** Phase 7 complete (adapters plug into the queue system).
**Estimated complexity:** Medium per adapter (High cumulative due to LinkedIn/Threads API approval friction — flag early).
**Definition of Done:** A single design can be published to all 5 platforms from one publish flow.

### Milestone 8.1 — Facebook Adapter
- Prerequisites: 7.2
- Files/folders created: `/backend/src/social-accounts/adapters/facebook.adapter.ts`
- Files/folders modified: `/backend/src/publishing/processors/*`
- Expected output: Facebook connect + publish works against sandbox
- Git commit message: `feat(backend): Facebook platform adapter`

### Milestone 8.2 — Threads Adapter
- Prerequisites: 7.2
- Files/folders created: `/backend/src/social-accounts/adapters/threads.adapter.ts`
- Files/folders modified: `/backend/src/publishing/processors/*`
- Expected output: Threads connect + publish works against sandbox
- Git commit message: `feat(backend): Threads platform adapter`

### Milestone 8.3 — LinkedIn Adapter
- Prerequisites: 7.2
- Files/folders created: `/backend/src/social-accounts/adapters/linkedin.adapter.ts`
- Files/folders modified: `/backend/src/publishing/processors/*`
- Expected output: LinkedIn connect + publish works against sandbox
- Git commit message: `feat(backend): LinkedIn platform adapter`

### Milestone 8.4 — Frontend: Full 5-Platform Support
- Prerequisites: 8.1, 8.2, 8.3
- Files/folders created: none
- Files/folders modified: `/frontend/lib/features/social_accounts/*`, `/frontend/lib/features/publish/*`
- Expected output: All 5 platforms selectable and functional in the publish/schedule flow
- Git commit message: `feat(frontend): full 5-platform publishing support`

---

# PHASE 9 — Video Support, Templates & Brand Kit

**Goal:** Editor supports video and reusable brand assets.
**Features:** Video upload/trim in editor, template library, brand kit (colors/fonts/logo) applied across designs.
**Frontend tasks:** Video layer support in canvas, template picker screen, brand kit settings screen.
**Backend tasks:** Video processing pipeline (via Cloudinary), `Template` and `BrandKit` modules.
**Database tasks:** `Template`, `BrandKit` tables.
**APIs to implement:** `GET/POST /templates`, `GET/PATCH /brand-kits/:org_id`
**Third-party integrations:** Cloudinary video transformation.
**UI components:** Video trim control, template gallery, brand kit editor (color/font pickers).
**Testing requirements:** Backend tests for template CRUD; frontend test for brand kit application across a design.
**Dependencies:** Phase 8 complete.
**Estimated complexity:** High (video handling is nontrivial in web canvas contexts).
**Definition of Done:** A user can start from a template, apply their brand kit, add a trimmed video, and publish it.

### Milestone 9.1 — Video Layer in Canvas Engine
- Prerequisites: 3.5
- Files/folders created: `/frontend/lib/features/editor/canvas/video_layer.dart`
- Files/folders modified: `/frontend/lib/features/editor/canvas/*`
- Expected output: Video can be added, positioned, and trimmed on canvas
- Git commit message: `feat(frontend): video layer support in canvas engine`

### Milestone 9.2 — Backend Video Processing Pipeline
- Prerequisites: 3.2
- Files/folders created: `/backend/src/media/video-processing.service.ts`
- Files/folders modified: `/backend/src/content/variant-generator.service.ts`
- Expected output: Uploaded video is transcoded/trimmed per platform spec automatically
- Git commit message: `feat(backend): video processing pipeline for platform variants`

### Milestone 9.3 — Brand Kit Module
- Prerequisites: 1.2
- Files/folders created: `/backend/src/brand-kits/*`, `/frontend/lib/features/brand_kit/*`
- Files/folders modified: `schema.prisma`
- Expected output: Org-level brand kit (colors/fonts/logo) persists and is selectable inside the editor
- Git commit message: `feat: brand kit module (backend and frontend)`

### Milestone 9.4 — Template Library
- Prerequisites: 9.3
- Files/folders created: `/backend/src/templates/*`, `/frontend/lib/features/templates/*`
- Files/folders modified: `/frontend/lib/features/editor/editor_screen.dart`
- Expected output: User can browse templates and start a new design pre-populated from one
- Git commit message: `feat: template library (backend and frontend)`

---

# PHASE 10 — Unified Analytics Dashboard

**Goal:** Aggregate performance metrics across all connected platforms in one view.
**Features:** Metric ingestion, normalized metric schema, dashboard with cross-platform comparison.
**Frontend tasks:** Analytics dashboard screen (charts via `fl_chart` or similar), per-post detail view, platform comparison view.
**Backend tasks:** Metric-ingestion workers (scheduled pull per platform), normalization mapping layer, GraphQL endpoint for flexible dashboard queries.
**Database tasks:** `PostMetric` table, ingestion job tracking table.
**APIs to implement:** GraphQL `analyticsOverview`, `postMetrics(variantId)`; REST fallback `GET /analytics/overview`.
**Third-party integrations:** Each platform's insights/analytics API (Instagram Insights, X Analytics, LinkedIn Analytics, etc.).
**UI components:** Line/bar charts, comparison table, date-range picker, top-posts list.
**Testing requirements:** Backend tests for metric normalization mapping (per platform → canonical schema); frontend snapshot tests for chart rendering with mocked data.
**Dependencies:** Phase 8 complete (needs all adapters).
**Estimated complexity:** High.
**Definition of Done:** Dashboard shows real aggregated metrics from at least 2 live-connected accounts, updated on a scheduled pull.

### Milestone 10.1 — Metric Normalization Schema + Ingestion Worker (2 platforms)
- Prerequisites: 8.4
- Files/folders created: `/backend/src/analytics/ingestion/*`
- Files/folders modified: `schema.prisma`
- Expected output: Scheduled job pulls Instagram + X metrics into normalized `PostMetric` rows
- Git commit message: `feat(backend): metric normalization and ingestion worker`

### Milestone 10.2 — Ingestion Workers for Remaining Platforms
- Prerequisites: 10.1
- Files/folders created: none
- Files/folders modified: `/backend/src/analytics/ingestion/*`
- Expected output: All 5 platforms feeding normalized metrics
- Git commit message: `feat(backend): complete metric ingestion for all platforms`

### Milestone 10.3 — GraphQL Analytics Endpoint
- Prerequisites: 10.2
- Files/folders created: `/backend/src/analytics/analytics.resolver.ts`
- Files/folders modified: `app.module.ts`
- Expected output: Dashboard-shaped nested queries return correctly in one round trip
- Git commit message: `feat(backend): GraphQL analytics endpoint`

### Milestone 10.4 — Frontend Analytics Dashboard
- Prerequisites: 10.3
- Files/folders created: `/frontend/lib/features/analytics/*`
- Files/folders modified: `/frontend/lib/core/router/app_router.dart`
- Expected output: Dashboard renders real cross-platform charts and comparison table
- Git commit message: `feat(frontend): unified analytics dashboard`

---

# PHASE 11 — Team Roles & RBAC (V1 close)

**Goal:** Multiple users can collaborate within an org with distinct permission levels.
**Features:** Invite teammates, role assignment (owner/admin/editor/viewer), permission-gated UI and API.
**Frontend tasks:** Team management screen, invite flow, role-gated UI elements.
**Backend tasks:** Extend RBAC guard usage across all mutating endpoints, invite/accept flow, email invite sending.
**Database tasks:** `Invite` table, role enum finalized on `User`.
**APIs to implement:** `POST /organizations/:id/invite`, `POST /invites/:token/accept`, `PATCH /organizations/:id/members/:userId/role`
**Third-party integrations:** Transactional email (e.g., SES/SendGrid) for invites.
**UI components:** Team member list, role selector, invite modal.
**Testing requirements:** Backend tests confirming each role's permission boundaries; frontend tests for role-gated UI hiding/showing correctly.
**Dependencies:** Phase 1 (RBAC scaffold), Phase 10 complete.
**Estimated complexity:** Medium.
**Definition of Done:** An owner can invite a teammate as "editor," and that teammate cannot access billing/team settings but can create/publish content.

### Milestone 11.1 — Invite Flow (Backend + Email)
- Prerequisites: 1.2
- Files/folders created: `/backend/src/organizations/invites/*`
- Files/folders modified: `schema.prisma`
- Expected output: Invite email sent, acceptance creates a scoped user in the org
- Git commit message: `feat(backend): team invite flow with transactional email`

### Milestone 11.2 — RBAC Enforcement Sweep Across Endpoints
- Prerequisites: 11.1
- Files/folders created: none
- Files/folders modified: all mutating controllers across content/publishing/social-accounts modules
- Expected output: Every mutating endpoint enforces role checks correctly (verified by test matrix)
- Git commit message: `feat(backend): enforce RBAC across all mutating endpoints`

### Milestone 11.3 — Frontend Team Management Screen
- Prerequisites: 11.2
- Files/folders created: `/frontend/lib/features/team/*`
- Files/folders modified: `/frontend/lib/core/router/app_router.dart`
- Expected output: Team list, invite modal, and role-gated UI fully functional
- Git commit message: `feat(frontend): team management and role-gated UI`

---

# PHASE 12 — Full AI Suite (V2 start)

**Goal:** Expand AI beyond captions into the full assistive feature set.
**Features:** Hashtag suggestions, tone conversion, viral score, best-posting-time, content calendar suggestions.
**Frontend tasks:** AI suggestion panels for each feature, viral score badge, best-time recommendation in scheduler.
**Backend tasks:** Extend `AIGateway` with new prompt templates per feature; best-time model using historical `PostMetric` data.
**Database tasks:** None new (reuses `AIUsageLog`, `PostMetric`).
**APIs to implement:** `POST /ai/hashtags`, `POST /ai/tone`, `POST /ai/viral-score`, `GET /ai/best-time`
**Third-party integrations:** Anthropic API (existing gateway, new prompts).
**UI components:** Hashtag chip picker, tone selector dropdown, viral score gauge, best-time suggestion chip.
**Testing requirements:** Mocked-response tests per new AI endpoint; quota enforcement extended to new endpoints.
**Dependencies:** Phase 11 complete, Phase 10 (for best-time, needs metric history).
**Estimated complexity:** Medium.
**Definition of Done:** All 5 new AI features are usable inside the editor/publish/scheduler flow with quota enforcement intact.

### Milestone 12.1 — Hashtag & Tone Conversion Endpoints
- Prerequisites: 5.2
- Files/folders created: `/backend/src/ai/prompts/hashtags.prompt.ts`, `/backend/src/ai/prompts/tone.prompt.ts`
- Files/folders modified: `/backend/src/ai/ai.controller.ts`
- Expected output: Both endpoints return usable, quota-checked results
- Git commit message: `feat(backend): hashtag and tone-conversion AI endpoints`

### Milestone 12.2 — Viral Score & Best-Time Endpoints
- Prerequisites: 10.4, 12.1
- Files/folders created: `/backend/src/ai/viral-score.service.ts`, `/backend/src/ai/best-time.service.ts`
- Files/folders modified: `/backend/src/ai/ai.controller.ts`
- Expected output: Viral score returns a 0–100 estimate; best-time returns a ranked list using historical metrics
- Git commit message: `feat(backend): viral score and best-time AI endpoints`

### Milestone 12.3 — Frontend AI Suite Integration
- Prerequisites: 12.2
- Files/folders created: `/frontend/lib/features/ai_suite/*`
- Files/folders modified: `/frontend/lib/features/publish/*`, `/frontend/lib/features/scheduler/*`
- Expected output: All 5 AI features surfaced and usable in their respective flows
- Git commit message: `feat(frontend): full AI suite integration`

---

# PHASE 13 — Collaboration & Approval Workflows

**Goal:** Teams can comment on and approve content before it publishes.
**Features:** Comment threads on designs, approval status, approve/reject gating publish.
**Frontend tasks:** Comment sidebar in editor, approval status badge, approve/reject buttons (role-gated).
**Backend tasks:** `Comment` module, approval state machine on `ContentAsset`, publish blocked until approved (configurable per org).
**Database tasks:** `Comment` table, `approval_status` field on `ContentAsset`.
**APIs to implement:** `POST /content/assets/:id/comments`, `PATCH /content/assets/:id/approval`
**Third-party integrations:** None new.
**UI components:** Comment thread, approval badge, approve/reject action bar.
**Testing requirements:** Backend tests for approval state transitions and publish-blocking logic; frontend tests for comment thread rendering.
**Dependencies:** Phase 11 complete.
**Estimated complexity:** Medium.
**Definition of Done:** A design requiring approval cannot be published until an admin/owner approves it, with comment history preserved.

### Milestone 13.1 — Comment Module
- Prerequisites: 3.1, 11.2
- Files/folders created: `/backend/src/content/comments/*`
- Files/folders modified: `schema.prisma`
- Expected output: Comments can be added/listed per content asset
- Git commit message: `feat(backend): content comment module`

### Milestone 13.2 — Approval State Machine + Publish Gate
- Prerequisites: 13.1, 4.2
- Files/folders created: `/backend/src/content/approval.service.ts`
- Files/folders modified: `/backend/src/publishing/publishing.service.ts`, `schema.prisma`
- Expected output: Publish attempt on an unapproved asset (in orgs requiring approval) is rejected with a clear error
- Git commit message: `feat(backend): approval workflow with publish gating`

### Milestone 13.3 — Frontend Comments & Approval UI
- Prerequisites: 13.2
- Files/folders created: `/frontend/lib/features/collaboration/*`
- Files/folders modified: `/frontend/lib/features/editor/editor_screen.dart`
- Expected output: Comment sidebar and approve/reject flow fully functional
- Git commit message: `feat(frontend): comments and approval workflow UI`

---

# PHASE 14 — Template Marketplace (V2 close)

**Goal:** Users can publish and browse community/public templates.
**Features:** Publish a design as a public template, browse/search marketplace, clone into own workspace.
**Frontend tasks:** "Publish as template" action, marketplace browse/search screen, template detail preview.
**Backend tasks:** Extend `Template` model with `is_public`/author/category, search endpoint, clone-on-use logic.
**Database tasks:** Extend `Template` table (already scaffolded in Phase 9) with marketplace fields.
**APIs to implement:** `GET /templates/marketplace`, `POST /templates/:id/publish`, `POST /templates/:id/clone`
**Third-party integrations:** None new.
**UI components:** Marketplace grid, search/filter bar, template detail modal.
**Testing requirements:** Backend tests for clone-on-use (ensures no shared-state bugs between org copies); frontend test for marketplace search/filter.
**Dependencies:** Phase 9.4, Phase 13 complete.
**Estimated complexity:** Medium.
**Definition of Done:** A user can publish a design as a public template and another org can discover, preview, and clone it into their own workspace.

### Milestone 14.1 — Marketplace Backend (Publish/Search/Clone)
- Prerequisites: 9.4
- Files/folders created: `/backend/src/templates/marketplace.controller.ts`
- Files/folders modified: `schema.prisma`
- Expected output: Publish/search/clone endpoints functional and tested
- Git commit message: `feat(backend): template marketplace publish, search, and clone`

### Milestone 14.2 — Frontend Marketplace Browse & Clone
- Prerequisites: 14.1
- Files/folders created: `/frontend/lib/features/marketplace/*`
- Files/folders modified: `/frontend/lib/features/templates/*`
- Expected output: Marketplace browsing and one-click clone into workspace works end-to-end
- Git commit message: `feat(frontend): template marketplace UI`

---

# PHASE 15 — Enterprise Readiness

**Goal:** Platform meets enterprise procurement requirements.
**Features:** SSO/SAML login, expanded audit logs, white-labeling, dedicated rate-limit pools.
**Frontend tasks:** SSO login entry point, white-label theming config screen (custom logo/colors for org's own branding).
**Backend tasks:** SAML strategy integration, audit log expansion across all mutating actions, per-org rate-limit pool configuration.
**Database tasks:** `AuditLog` table (expand from Phase 1 stub if present), `SsoConfig` table.
**APIs to implement:** `POST /auth/sso/callback`, `GET /audit-logs`, `PATCH /organizations/:id/white-label`
**Third-party integrations:** SAML IdP (e.g., Okta/Azure AD), rate-limit infra (Redis-backed, per-org keys).
**UI components:** SSO login button, audit log table with filters, white-label settings form.
**Testing requirements:** Backend tests for SAML assertion parsing (mocked IdP); audit log completeness test across a full user journey; rate-limit isolation test between orgs.
**Dependencies:** Phase 11 (RBAC), Phase 13 complete.
**Estimated complexity:** High (SSO/SAML integration is typically the longest single item due to IdP-specific quirks).
**Definition of Done:** An enterprise org can log in via SSO, see a complete audit trail of team actions, and apply their own branding to the app shell.

### Milestone 15.1 — SAML SSO Integration
- Prerequisites: 1.1
- Files/folders created: `/backend/src/auth/sso/*`
- Files/folders modified: `/backend/src/auth/auth.module.ts`
- Expected output: Login via a test IdP (e.g., Okta dev tenant) issues a valid SocialHub session
- Git commit message: `feat(backend): SAML SSO integration`

### Milestone 15.2 — Full Audit Log Expansion
- Prerequisites: 11.2
- Files/folders created: `/backend/src/common/interceptors/audit-log.interceptor.ts`
- Files/folders modified: `schema.prisma`, all mutating controllers
- Expected output: Every mutating action across the app is captured in `AuditLog` with actor/target/timestamp
- Git commit message: `feat(backend): comprehensive audit logging`

### Milestone 15.3 — Per-Org Rate-Limit Pools
- Prerequisites: 15.1
- Files/folders created: `/backend/src/common/guards/org-rate-limit.guard.ts`
- Files/folders modified: `app.module.ts`
- Expected output: One org hitting rate limits does not affect another org's throughput
- Git commit message: `feat(backend): per-organization rate-limit pools`

### Milestone 15.4 — White-Labeling
- Prerequisites: 15.2
- Files/folders created: `/backend/src/organizations/white-label.controller.ts`, `/frontend/lib/features/settings/white_label_screen.dart`
- Files/folders modified: `/frontend/lib/core/theme/*`
- Expected output: Org-level logo/color overrides apply across the app shell for that org's users
- Git commit message: `feat: white-labeling for enterprise organizations`

---

# Dependency Graph (Milestone-Level)

```
0.1 → 0.2, 0.3
0.3 → 0.4
0.4 → 1.1
1.1 → 1.2, 1.4, 5.1, 15.1
1.2 → 2.1(indirect via 1.2 role model), 2.2*, 3.1, 9.3, 11.1
   (* 2.2/2.3 require 2.1 directly, and 1.2 for org scoping)
0.2 → 1.3, 3.3
1.3 → 1.4
2.1 → 2.2, 2.3
2.2 → 2.4
2.3 → 2.4
1.4 → 2.4
3.1 → 3.2, 13.1
3.2 → 3.5, 9.2
3.3 → 3.4
3.4 → 3.5
2.4 → 4.1
3.5 → 4.1, 9.1
4.1 → 4.2
4.2 → 4.3, 7.2, 13.2
4.3 → 5.3
5.1 → 5.2
5.2 → 5.3, 12.1
5.3 → 6.1
6.1 → 6.2
6.2 → 6.3
6.3 → 7.1
7.1 → 7.2
7.2 → 7.3, 8.1, 8.2, 8.3
7.3 → 7.4
8.1, 8.2, 8.3 → 8.4
8.4 → 9.1(already satisfied via 3.5)*, 10.1
   (* 9.x track only needs 3.5/1.2/3.2, not 8.4 — parallelizable with Phase 7/8)
9.3 → 9.4
10.1 → 10.2
10.2 → 10.3
10.3 → 10.4
10.4 → 11.3(via 11.2 chain), 12.2
11.1 → 11.2
11.2 → 11.3
12.1 → 12.2
12.2 → 12.3
13.1 → 13.2
13.2 → 13.3
9.4 → 14.1
13.3 → 14.1
14.1 → 14.2
15.1 → 15.2
15.2 → 15.3
15.2 → 15.4
```

**Parallelization notes:**
- Phase 9 (video/templates/brand kit) only depends on Phase 1–3 infrastructure and can run **in parallel** with Phases 7–8 if you have two workstreams.
- Phase 12 (AI suite) needs Phase 10 (analytics) only for the *best-time* endpoint (12.2) — hashtags/tone (12.1) can start as soon as Phase 5 is done.
- Phase 15 (Enterprise) SSO (15.1) only needs Phase 1 and can be built early if enterprise sales requires it sooner than the roadmap order suggests.
