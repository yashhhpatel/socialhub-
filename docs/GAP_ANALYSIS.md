# SocialHub — Gap Analysis & Production-Readiness Status

> Snapshot as of **2026-08-22**, reconciled against the actual codebase
> (`backend/src`, `frontend/lib`, `backend/prisma/schema.prisma`), not the older
> planning docs. Supersedes the 2026-08-19 snapshot, whose entire P0 list
> (billing, Meta compliance, account lifecycle/security) and most of its P1 list
> (notifications, media library) have since shipped.

---

## 1. Current state

**Built, wired, and tested today.** The 15-phase Implementation Blueprint (Phases
0–15) is implemented, and the four follow-on phases proposed in the previous
snapshot (16–19) have all shipped. The backend is a NestJS modular monolith with
23 registered modules; the frontend is a Flutter Web app with 24 routed screens.
Test coverage is substantial: **59 backend spec files** and **37 frontend
unit/widget test files**. Both production builds pass (`nest build`,
`flutter build web`); `tsc` and `flutter analyze` are clean.

**Verification note:** live posting, live Stripe charging, and Google sign-in are
*code-complete but require real third-party credentials* to operate — that is an
operational/config step (optional-at-boot by design), not a code gap.

---

## 2. Completed (removed from the gap list)

| Area | Status | Evidence |
|---|---|---|
| Auth: register / login / refresh / logout, action-level auth, session persistence | ✅ | `backend/src/auth/*`, `frontend/lib/features/auth/*`, `core/network/auth_interceptor.dart` |
| Signup drops "Organization name" → auto-workspace from email | ✅ | `auth.service.ts`, `auth/default-org-name.ts` |
| "Continue with Google" (server-side authorization-code flow) | ✅ | `auth/google-auth.{service,controller}.ts`, `/auth/google/*` |
| Email verification, password reset, change password | ✅ | `auth/account.service.ts`, `/auth/verify-email`, `/auth/password-reset*` |
| MFA (TOTP + recovery codes) | ✅ | `auth/mfa.service.ts`, `/auth/mfa/*` |
| Account deletion + data export (GDPR/CCPA) | ✅ | `users/account-data.service.ts`, `DELETE /users/me`, `GET /users/me/export` |
| Brute-force throttling + security headers | ✅ | `auth/auth-throttle.service.ts`, `common/middleware/security-headers.middleware.ts` |
| Social OAuth — all 5 platforms (IG, FB, Threads, X, LinkedIn) | ✅ | `social-accounts/adapters/*` (+ per-adapter specs) |
| Meta compliance: deauthorize + data-deletion callbacks | ✅ | `social-accounts.controller.ts` `:platform/deauthorize`, `:platform/data-deletion`, `DataDeletionRequest` model |
| Content assets, editor, variants, Cloudinary upload | ✅ | `content/*`, `frontend/lib/features/editor/*`, `media/cloudinary.service.ts` |
| Publishing: manual + scheduled, BullMQ queues, retry, 30s cron | ✅ | `publishing/*`, `publishing/schedule.cron.ts` |
| Analytics dashboard + hourly ingestion cron (REST + GraphQL) | ✅ | `analytics/*`, `analytics/ingestion/ingestion.cron.ts` |
| Full AI suite (caption/hashtags/tone/viral-score/best-time) on OpenAI + dev fallback | ✅ | `ai/*` |
| Team roles & RBAC (invites, members, role changes, guard) | ✅ | `organizations/{invites,members}/*`, `common/guards/roles.guard.ts`, `rbac-enforcement.spec.ts` |
| Collaboration & approval workflows | ✅ | `content/comments/*`, `content/approval.*` |
| Template marketplace (publish/clone/browse) | ✅ | `templates/marketplace.controller.ts` |
| Brand kit | ✅ | `brand-kits/*` |
| Enterprise: SAML SSO, white-label, audit log, per-org rate limiting | ✅ | `auth/sso/*`, `organizations/white-label/*`, `audit/*`, `common/guards/org-rate-limit.guard.ts` |
| **Billing** — Stripe subscriptions, checkout, portal, webhook, plan-gating, invoices | ✅ | `billing/*`, `Subscription`/`Invoice` models |
| **Notifications** — model + in-app delivery, emitted on real events | ✅ | `notifications/*`, `Notification` model |
| **Media library backend** — persistent org-scoped assets | ✅ | `media/media.{service,controller}.ts`, `MediaAsset` model |
| CI + staging deploy | ✅ | `.github/workflows/{ci,deploy-staging}.yml` |

---

## 3. Remaining gaps (by severity)

### 🔴 Critical (blocks build / breaks a core feature)
- **None.** The app builds and runs; core flows are wired. (Live Google/Stripe/OAuth
  need real credentials — operational, not code.)

### 🟠 High (feature half-done or a real reliability risk)
1. **Dashboard shows mock data** — the post-login landing page renders hardcoded
   metrics; `dashboardSummaryProvider` returns a static object
   (`frontend/lib/features/dashboard/data/dashboard_mock_data.dart:17`). No dashboard
   endpoint/repository exists. Needs a real endpoint + loading/error states.
2. **No proactive social-token refresh / reconnect job** — adapters implement
   `refresh()` (e.g. `social-accounts/adapters/facebook.adapter.ts:175`) but only two
   crons exist (publish 30s, ingestion hourly). Expiring tokens will cause silent
   publish failures with no reconnection prompt.
3. **Webhooks absent** — no inbound platform status webhooks or outbound customer
   webhooks (only Stripe and Meta callbacks exist).

### 🟡 Medium (completeness / quality)
4. **Backend endpoints with no frontend surface** — either build UI or confirm API-only:
   audit-log viewer (`GET /audit-logs`), per-post analytics
   (`GET /analytics/posts/:variantId`), and MFA state reflection
   (`GET /auth/mfa/status` is never called by the frontend MFA repo, so the settings
   card may not show persisted MFA status).
5. **`test:e2e` is broken** — `backend/package.json` points at `./test/jest-e2e.json`,
   which does not exist; there is **no** `backend/test/` dir. No frontend E2E either.
6. **Zero-coverage frontend screens** — dashboard, content, organizations, info, and
   the Google callback (`google_callback_screen.dart`) have no widget tests.
7. **Canvas document format is unversioned** — schemaless JSON; needs a versioned spec +
   migration path so old designs don't break.

### 🟢 Low (polish / cleanup / roadmap)
8. **Dead code:** `frontend/lib/shared_widgets/coming_soon_placeholder.dart` (never
   instantiated); the unreachable `'Coming soon'` branch in
   `platform_connection_card.dart` (`SocialPlatform.isConnectable` is always `true`);
   the unreferenced `features/settings/` placeholder noted in `social_accounts_screen.dart:19`.
9. **Thin READMEs** — root `README.md` is 32 lines; no backend/frontend READMEs.
10. **P2 product features** — link shortening + UTM, bulk/CSV scheduling, global search,
    calendar drag-to-reschedule, i18n/l10n, WCAG accessibility, mobile apps.
11. **Observability & SRE maturity** — SLOs/SLIs, alerting, tracing, runbooks; IaC +
    production deploy pipeline (only `ci.yml` + `deploy-staging.yml` exist).

### ❓ Needs confirmation (may be intentional)
- GraphQL `/graphql` (analytics resolver) is unused by the REST-only frontend — kept as
  a machine API? (`api_analytics_repository.dart:8` says so.)
- SSO endpoints (`/auth/sso/*`) have no frontend UI (enterprise, backend-only?).
- Social `deauthorize` / `data-deletion` callbacks have no UI (Meta-triggered by design).

---

## 4. Roadmap status

| Phase | Scope | Status |
|---|---|---|
| 0–6 | MVP: foundation, auth, IG/X OAuth, editor, publish, AI caption, deploy | ✅ Complete |
| 7 | Scheduling + BullMQ queues | ✅ Complete |
| 8 | Facebook, Threads, LinkedIn adapters | ✅ Complete |
| 9 | Video, templates, brand kit | ✅ Complete |
| 10 | Unified analytics + ingestion | ✅ Complete |
| 11 | Team roles & RBAC | ✅ Complete |
| 12 | Full AI suite | ✅ Complete |
| 13 | Collaboration & approval | ✅ Complete |
| 14 | Template marketplace | ✅ Complete |
| 15 | Enterprise (SSO, white-label, audit, rate-limit) | ✅ Complete |
| 16 | Go-live / Meta compliance (deauthorize + data-deletion) | ✅ Complete — token-refresh job still open (High #2) |
| 17 | Account lifecycle & security | ✅ Complete |
| 18 | Billing & monetization | ✅ Complete |
| 19 | Notifications & media library | ✅ Complete |
| 20 | **Production hardening / GA** | ⏳ Open — E2E automation, observability maturity, IaC + prod deploy, canvas-format versioning, webhooks, token-refresh job, dashboard wiring, doc reconciliation |

**Recommended next focus (Phase 20):** (a) wire the dashboard to real data, (b) add
the social-token refresh cron + reconnection prompt, (c) fix `test:e2e` and add a
frontend E2E smoke test, (d) implement webhooks.

---

## 5. Known documentation drift (still aspirational vs. code)
These docs describe intended structure/process that the single-developer repo has not
adopted; treat the code as source of truth until they are reconciled:
- **`SocialHub_Folder_Structure.md`** — describes `packages/`, `infrastructure/terraform/`,
  `docker/`, `scripts/`, `CODEOWNERS`, root `docker-compose.yml`, and a
  `docs/{blueprint,api,runbooks,…}/` layout that don't exist.
- **`SocialHub_Git_Workflow.md`** — references `deploy-production.yml`,
  `migration-check.yml`, `contract-drift-check.yml` (only `ci.yml` + `deploy-staging.yml`
  exist) and a 2-approval/CODEOWNERS/`staging` flow; reality is direct-to-`main` hybrid.
- **`SocialHub_Flutter_Web_Architecture.md`** / **`mvp-regression-checklist.md`** — say
  "unauthenticated → /login" (page-level); the app uses **action-level** auth.
- Architecture/plan docs historically named Anthropic/Claude for AI; the code uses
  **OpenAI** gpt-4o-mini with a dev fallback.
