# SocialHub — Gap Analysis & Production-Readiness Backlog

> Snapshot as of 2026-08-19. Assessment of what exists vs. what a production-ready
> SaaS (Buffer / Hootsuite / Canva class) needs. The existing planning docs are
> strong for *building the product*; the gaps are (a) running it as a business —
> billing, account lifecycle, compliance — and (b) drift between the docs and the
> code that has since been built. Nothing here changes code; it's the map we build
> against.

---

## 1. Current state (honest)

**Strong:** the 15-phase Implementation Blueprint (milestone-sized, dependency-graphed),
the Database Design, and the REST/Flutter/Git architecture docs. These are high quality.

**Built and working today:** auth (register/login/refresh, in-memory→localStorage
persistence), action-level auth (browse freely, protected actions → login), the editor,
content/templates/brand-kit/media-library/marketplace/analytics/team/organizations/
white-label surfaces, all 5 social adapters (code-complete), AI suite on **OpenAI
gpt-4o-mini** with a dev-fallback, the light-purple design system, a global footer,
CI (`ci.yml`) + staging deploy (`deploy-staging.yml`).

**Not built / not planned:** everything in §2.

---

## 2. Gaps, by priority

### P0 — blocks monetization or go-live
| Gap | Why it matters |
|---|---|
| **Billing / subscriptions** | `plan_tier` (free/starter/pro/enterprise) is pervasive and the architecture names a "Billing Module", but there are **no** billing tables, endpoints, Stripe integration, plan-gating, metering, dunning, or invoices. Cannot charge anyone. Not even a roadmap phase. |
| **Meta / platform App Review + compliance** | No data-deletion callback, deauthorize callback, substantive privacy policy, or app-review runbook. This is the hard gate to leaving Meta dev mode and publishing for real users. |
| **Account lifecycle & security** | Only register/login/refresh/logout. Missing: email verification, forgot/reset password, change password/email, **MFA/2FA**, account deletion, data export (GDPR/CCPA). |

### P1 — core product completeness
| Gap | Notes |
|---|---|
| **Notifications** | Bell icon exists; no model, endpoints, or email/push (publish success/failure, token expiry, invite, approval, quota warnings). |
| **Media Library backend** | A Media Library page exists but no `Media` model/endpoints; uploads piggyback on content assets. Needs real reusable assets (folders/tags/search). |
| **Webhooks** | API says "listen for a status webhook" but defines none — neither inbound platform webhooks nor outbound customer webhooks. |
| **Social-token lifecycle jobs** | `expires_at`/`expired`/`revoked` exist, but no job to proactively refresh or prompt reconnection — the most common real publishing failure. |
| **Plan-based limits** | AI quota exists; nothing gates social accounts, scheduled posts, seats, or storage per plan. |
| **Canvas document format** | The design file is "schemaless JSONB" — undocumented and unversioned. A design tool must spec + migrate its file format or old designs break. |

### P2 — competitor table-stakes (Buffer/Hootsuite/Canva)
Link shortening + UTM builder · first-comment posting · saved hashtag groups ·
bulk scheduling / CSV import · exportable analytics reports (PDF/CSV) · global search ·
calendar drag-to-reschedule · onboarding/first-run flow · **agency / multi-workspace**
mode · accessibility (WCAG) · i18n/l10n · mobile apps.

### Weak / incomplete documentation
- **Security:** no threat model; silent on MFA, brute-force/lockout, CSP/security headers,
  secrets rotation, SAST/DAST/dependency scanning, PII encryption & retention, pen-test cadence, SOC2/GDPR posture.
- **Testing:** per-phase requirements exist, but no overall strategy — no coverage targets,
  the "load test" is unspecified, no automated frontend E2E, no a11y/security/chaos testing.
- **Observability/SRE:** Sentry/CloudWatch named; no SLO/SLI, alerting, tracing, dashboards,
  log-retention/PII-scrubbing, cost monitoring. Runbooks are referenced but don't exist.
- **Analytics ingestion:** no canonical metric-mapping table, ingestion rate-limit handling, backfill, or attribution rules.
- **AI:** no documented caching, prompt-injection safety (present in code), provider-abstraction/fallback (we swapped to OpenAI), or eval plan.

---

## 3. Doc ↔ reality drift (fix these — cheap, high-clarity)

1. **Folder Structure & docs/README describe a repo that doesn't exist** — `packages/`,
   `infrastructure/terraform/`, `docker/`, `scripts/`, `CODEOWNERS`, `LICENSE`,
   `.editorconfig`, root `docker-compose.yml`, PR/issue templates, and
   `docs/{blueprint,git-workflow,api,runbooks,onboarding}/` are **all absent**. The doc
   claims "nothing is speculative scaffolding" — contradicted.
2. **Git Workflow references pipelines that don't exist** — `deploy-production.yml`,
   `migration-check.yml`, `contract-drift-check.yml`. Only `ci.yml` + `deploy-staging.yml` exist.
3. **Governance is aspirational** — documented trunk-based-via-`staging`, 2-approval,
   CODEOWNERS, branch protection. Reality: single dev, direct-to-`main` hybrid, no `staging`
   in the flow, no protection, no CODEOWNERS.
4. **ADR mismatch** — Folder Structure cites `0001-modular-monolith-at-mvp.md`; actual is
   `0001-supported-social-platforms.md`.
5. **Auth model conflict** — Flutter doc (§4) + MVP checklist say "unauthenticated → /login"
   (page-level); we switched to **action-level auth**.
6. **AI provider conflict** — docs say Anthropic/Claude; code uses **OpenAI** + dev-fallback.
7. **Storage/theme conflict** — doc says theme persisted + `local_store` = IndexedDB/Hive;
   actual theme is in-memory, storage is `core/storage/key_value_store` (localStorage).
8. **Billing architected but unspecified** — diagram + `plan_tier` vs. no tables/API/phase.
9. **Invalid Prisma in DB doc** — `role UserRole @default(member: editor)` (flagged but still wrong).

---

## 4. Proposed additional roadmap phases (16–20)

The existing roadmap ends at "Enterprise Readiness" with no GA/launch gate. Suggested additions:

- **Phase 16 — Go-live & platform compliance:** deauthorize + data-deletion callbacks,
  real privacy/terms content, Meta App Review runbook + business verification, social-token
  refresh jobs. *(chosen next focus)*
- **Phase 17 — Account lifecycle & security:** email verification, password reset, MFA,
  account deletion + data export, brute-force/lockout, security headers.
- **Phase 18 — Billing & monetization:** Stripe subscriptions, plan-gating + limits, usage
  metering → invoices, dunning, customer portal.
- **Phase 19 — Notifications & media library:** notification model + in-app/email delivery;
  real media library backend.
- **Phase 20 — Production hardening / GA:** test strategy (E2E automation, load, a11y, security
  scans), observability maturity (SLOs, alerting, tracing, runbooks), IaC + production deploy
  pipeline, canvas-format versioning, doc reconciliation.

---

## 5. Recommended sequence

0. **Prove the core loop live** — connect Facebook + Instagram and publish one real post each.
1. **This doc** (done) + fix the §3 doc drift (low-risk, direct to `main`).
2. **Phase 16 — Go-live / Meta compliance** (chosen) — unblocks real publishing.
3. Then Phase 17 (security) → Phase 18 (billing), depending on whether the goal is
   "launch to users" or "monetize."
