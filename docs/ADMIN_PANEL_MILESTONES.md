# SocialHub — Phase 21: Platform Admin Panel

Milestone-by-milestone plan for the **platform super-admin** console — a
cross-tenant operations panel for SocialHub operators (distinct from the
org-scoped `owner/admin/editor/viewer` roles, which only manage a single
workspace). Guarded `/admin/*` on the NestJS backend and a `/admin` shell in the
Flutter app. The existing PostgreSQL database is the single source of truth — no
separate admin DB, no duplicated data, no exposed secrets.

**Conventions**
- 🗄️ schema change (additive; migration SQL shown before it is applied)
- 🔒 security-critical
- ♻️ reuses existing services/tables
- Each milestone: branch → tests → CI-green → merge to `main` → local verify.

**Secrets never selected into any `/admin/*` response:** `user.passwordHash`,
`user.mfaSecretEnc`, `user.googleId` (value), `social_account.accessTokenEnc` /
`refreshTokenEnc`, `user_token.tokenHash`, `refresh_token.tokenHash`,
`mfa_recovery_code` hashes, `sso_config.idpCert`, Stripe keys.

---

## 21.1 — Foundation: platform-admin identity, guard & shell 🗄️🔒
- **Backend:** migration adds `User.isPlatformAdmin Boolean @default(false)`;
  JWT carries the flag; new `PlatformAdminGuard` (distinct from `RolesGuard`)
  requires it and re-verifies against the DB; secure **seed** promotes the first
  admin from env (`PLATFORM_ADMIN_EMAIL` / `PLATFORM_ADMIN_PASSWORD`) — never
  hardcoded; `/admin/*` covered by the existing `AuditLogInterceptor`.
- **Frontend:** `/admin` route + `AdminShell`, gated by the flag; non-admins never
  see it.
- **Tests:** guard allow/deny; JWT claim; seed idempotency.
- **Done:** seeded admin loads `/admin`; everyone else is blocked (server-enforced).

## 21.2 — Overview dashboard (read-only KPIs)
- **Backend:** `GET /admin/overview` — cross-org totals: orgs/users, new signups,
  plan distribution, active vs dormant, publish volume & failure rate, accounts
  needing reconnection. ♻️ `PlanLimitsService`, existing tables.
- **Frontend:** KPI cards + trend; loading/error/retry.
- **Tests:** aggregation math; admin-only.

## 21.3 — Organizations (list, search, detail — read)
- **Backend:** `GET /admin/organizations` (search/paginate) + `/:id` (plan,
  members+roles, subscription, usage vs limits, activity). No secrets.
- **Frontend:** searchable table + detail page.
- **Tests:** pagination/search; secret omission.

## 21.4 — Users (list, search, detail + safe actions) 🔒
- **Backend:** `GET /admin/users` (+ `/:id`); safe mutations: resend verification,
  force password reset, deactivate/reactivate. ♻️ `AccountService`. Never returns
  secrets.
- **Frontend:** user table + detail with confirmed actions.
- **Tests:** secret omission; each action audited; admin-only.

## 21.5 — Social account health & reconnect queue
- **Backend:** `GET /admin/social-accounts` (cross-org, status filter) — the
  `expired`/`revoked`/`error` queue; actions: force-refresh (♻️ `SocialTokenService`),
  mark-needs-reconnect, disconnect. No token ciphertext.
- **Frontend:** status-filtered table + row actions.
- **Tests:** filter; force-refresh; no leakage.

## 21.6 — Billing & revenue (read + Stripe links)
- **Backend:** `GET /admin/billing` — MRR, plan mix, dunning/past-due queue,
  invoices per org (amounts, status, `hostedInvoiceUrl`). ♻️ `subscription`/`invoice`.
  No card data / Stripe keys.
- **Frontend:** revenue summary + at-risk list + invoice drill-in (link out).
- **Tests:** MRR calc; past-due filter; no secrets.

## 21.7 — Content & publishing management
- **Backend:** `GET /admin/publish-jobs` (cross-org, status filter) with
  `lastError`/`attemptCount`; failed-jobs view; retry/cancel actions.
  ♻️ `PublishingService`.
- **Frontend:** publishing board + failed queue + actions.
- **Tests:** filters; retry/cancel; admin-only.

## 21.8 — Cross-org audit log viewer
- **Backend:** `GET /admin/audit-logs` — existing `audit_log` without the org
  filter (actor, method, path, target, statusCode, time), searchable/paginated.
- **Frontend:** filterable audit table.
- **Tests:** cross-org visibility; pagination.

## 21.9 — Compliance & org suspension 🗄️
- **Backend:** `GET /admin/data-deletion-requests` ♻️; migration adds
  `organization.status` (+`suspendedAt`) and suspend/reactivate that blocks the
  tenant. Migration SQL shown first.
- **Frontend:** compliance queue + org suspend toggle.
- **Tests:** suspend blocks tenant; actions audited.

## 21.10 — System & error monitoring
- **Backend:** deep `GET /admin/health` (DB + Redis + queues); `GET /admin/queues`
  BullMQ inspector (publish + token-refresh sweep); recent 4xx/5xx from
  `audit_log.statusCode`; Sentry status/link.
- **Frontend:** system-health panel + queue dashboard + recent-errors list.
- **Tests:** health reflects a down dependency; queue stats shape.

## 21.11 — Admin roles, impersonation & feature flags (advanced/optional)
- **Backend:** optional two-tier admin (read-only analyst vs full operator);
  audited, time-boxed impersonation; feature-flag / plan-override storage;
  broadcast notifications (♻️ `notification`).
- **Frontend:** admin-settings page, impersonation control, flags UI.
- **Tests:** impersonation logged + time-boxed; analyst cannot mutate.

---

## Schema changes (all additive)
- 21.1 — `User.isPlatformAdmin Boolean @default(false)`
- 21.9 — `Organization.status` (+ `suspendedAt`)

## Environment / setup
- `PLATFORM_ADMIN_EMAIL`, `PLATFORM_ADMIN_PASSWORD` — used **only** by the seed to
  create/promote the first platform admin locally. Not committed; provided at
  runtime. Additional admins are granted via the admin panel (21.11) or by
  re-running the seed with a new email.

## Suggested usable v1
21.1 → 21.5 (foundation + overview + orgs + users + account health). 21.6–21.10
harden it; 21.11 is optional polish.
