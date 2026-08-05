# SocialHub — Git Workflow & Repository Governance

This document defines how code moves from a developer's first commit to a production deployment, and how the repository stays navigable as the team and codebase grow.

---

## 1. Monorepo Structure

A single repository holds both apps plus shared planning docs, matching Phase 0 of the implementation blueprint.

```
socialhub/
├── frontend/                    # Flutter Web app
│   ├── lib/
│   │   ├── app/                 # App shell, root widget
│   │   ├── core/                # theme, router, network, error, DI
│   │   └── features/            # feature-first modules (auth, editor, publish, ...)
│   ├── web/                     # PWA manifest, service worker, index.html
│   └── test/
├── backend/                     # NestJS app
│   ├── src/
│   │   ├── common/               # guards, filters, interceptors, crypto
│   │   ├── config/
│   │   ├── auth/  organizations/  users/
│   │   ├── social-accounts/adapters/
│   │   ├── content/  publishing/  ai/  analytics/  templates/  brand-kits/
│   │   └── main.ts
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/
│   └── test/
├── docs/                        # architecture, blueprint, ADRs, runbooks
├── .github/
│   └── workflows/                # CI/CD pipeline definitions
├── docker-compose.yml
└── README.md
```

**Why monorepo, not polyrepo:** frontend and backend evolve together at this stage (shared API contracts, shared release cadence). A monorepo keeps a single PR able to change both sides atomically and keeps CI/versioning centralized. Revisit this only if the two apps' release cadences diverge significantly post-Enterprise phase.

---

## 2. Branching Strategy

**Trunk-based development with short-lived feature branches**, not long-lived GitFlow-style `develop`/`release` branches — the blueprint's 1–3 hour milestones are intentionally small, which is exactly what trunk-based flow is built for.

```
main                → always deployable; protected; deploys to production on tag
   └── staging       → integration branch; auto-deploys to staging on every merge
        └── feature/*, fix/*, chore/* → short-lived, branched from staging
```

- `main` — production source of truth. Only receives merges from `staging` via a release PR, or hotfix branches in emergencies.
- `staging` — where milestone branches land first. Continuous deploy target for the staging environment used in Phase 6's regression checklist.
- Feature branches live **days, not weeks** — a branch mapping to one milestone (1–3 hrs of work) should be opened, reviewed, and merged same-day wherever possible.

**No `develop` branch.** With milestones this granular, an extra long-lived branch just adds merge overhead without benefit.

---

## 3. Branch Naming Convention

```
<type>/<phase>.<milestone>-<short-description>
```

Examples (mapped directly to blueprint milestones):
- `feat/1.1-auth-module`
- `feat/2.2-instagram-oauth-adapter`
- `fix/4.2-publish-retry-bug`
- `chore/0.1-repo-scaffold`
- `docs/15.1-sso-runbook`

**Types:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `ci`, `hotfix`

Embedding the phase.milestone number ties every branch straight back to the blueprint — anyone can find what a branch was for without opening it.

---

## 4. Commit Message Convention

**Conventional Commits**, matching the style already used in the blueprint's suggested commit messages.

```
<type>(<scope>): <short summary>

[optional body — why, not just what]

[optional footer — breaking changes, issue refs]
```

- **type:** `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `ci`, `perf`
- **scope:** the module or app touched — `auth`, `editor`, `publishing`, `frontend`, `backend`, `db`
- **summary:** imperative mood, no trailing period, under ~72 chars

Examples:
```
feat(backend): auth module with JWT + refresh token rotation
fix(publishing): correct retry backoff for rate-limited platforms
chore(db): squash MVP migrations into a single baseline
```

**Breaking changes** get a `BREAKING CHANGE:` footer, which release tooling uses to bump the major version automatically.

Squash-merge is used for feature branches (see §6), so the **PR title** becomes the final commit message on `staging`/`main` — PR titles must therefore also follow this convention.

---

## 5. Pull Request Workflow

1. Branch from `staging` using the naming convention in §3.
2. Complete the milestone's scope exactly as defined in the blueprint (no scope creep — if you discover extra work, note it as a new milestone rather than expanding the PR).
3. Open a PR into `staging` using the repo's PR template, which requires:
   - Linked milestone number (e.g., "Implements Milestone 3.2")
   - Summary of what changed and why
   - Screenshots/GIFs for any UI change
   - Checklist: tests added, docs updated if API changed, migration included if schema changed
4. CI must pass (lint, typecheck, unit tests, build) before review is requested — a red pipeline is not sent for review.
5. At least **one approval** required to merge (two for anything touching `auth`, `publishing`, or `schema.prisma` — see §9).
6. **Squash merge** into `staging` — keeps history one commit per milestone, readable and bisectable.
7. Delete the branch on merge.

---

## 6. Code Review Workflow

**What reviewers check, roughly in this order:**
1. Does it satisfy the milestone's stated "Expected output" and "Definition of Done" from the blueprint — nothing more, nothing less?
2. Correctness and edge cases (especially around the failure-isolation and retry behavior called out in the architecture doc for publishing).
3. Security: token handling, input validation, RBAC checks present on new endpoints.
4. Test coverage matches the phase's "Testing requirements."
5. Style/consistency — last, and mostly caught by linters, not humans.

**Turnaround expectation:** given 1–3 hour milestones, reviews should happen same-day to avoid bottlenecking the next dependent milestone (see the blueprint's dependency graph — many milestones block others).

**Review etiquette:**
- Blocking comments must state *why* it's blocking, not just "change this."
- Author resolves conversations after addressing them; reviewer re-approves, doesn't just trust a "done" comment.
- Disagreements that don't resolve in two rounds move to a short synchronous call rather than dragging in the PR thread.

---

## 7. Release Workflow

1. `staging` is continuously deployed and continuously tested — it should be release-ready at all times, not batched up.
2. When a phase (or a meaningful cluster of milestones) is ready to ship, open a **release PR**: `staging` → `main`.
3. Release PR description auto-lists all included commits (squash-merge titles make this a clean changelog draft).
4. On merge to `main`, CI tags the release (see §8) and triggers the production deploy pipeline.
5. Tag triggers a GitHub Release with auto-generated notes grouped by commit type (Features / Fixes / Chores).

**Hotfix path:** branch `hotfix/x.y-description` directly from `main`, fix, PR reviewed with the same two-approval rule as sensitive paths, merge to `main` (triggers deploy), then immediately back-merge `main` → `staging` so the fix isn't lost on the next release.

---

## 8. Versioning Strategy

**Semantic Versioning (`MAJOR.MINOR.PATCH`)** applied to the whole monorepo as one version (frontend and backend deploy together at this stage, so one version number avoids drift confusion).

- **MAJOR** — breaking API contract changes, schema changes requiring coordinated migration (rare; flagged via `BREAKING CHANGE:` footer)
- **MINOR** — new phase/feature shipped (e.g., Phase 7 scheduling ships as a MINOR bump)
- **PATCH** — bug fixes, hotfixes, non-breaking chores

Version is derived automatically from Conventional Commit history at release time (no manual version bumping) and tagged as `vX.Y.Z` on `main`.

**Alignment with the roadmap:** MVP ships as `v0.x.x` (pre-1.0, expect breaking changes as the foundation settles). `v1.0.0` is cut when Phase 11 (end of V1 scope) is complete and stable.

---

## 9. Folder Ownership

A `CODEOWNERS` file enforces mandatory review from the right specialist, mapped to the original team roles:

| Path | Owner(s) | Notes |
|---|---|---|
| `/frontend/lib/features/editor/**` | Senior UI/UX Designer, Flutter Web Architect | Canvas engine is the highest-complexity frontend area |
| `/backend/src/auth/**`, `/backend/src/common/crypto/**` | Security Engineer | Always requires 2 approvals |
| `/backend/src/social-accounts/adapters/**` | Social Media API Expert | Platform-specific quirks live here |
| `/backend/src/publishing/**` | Backend Architect | Always requires 2 approvals (failure isolation is load-bearing) |
| `/backend/prisma/schema.prisma` | Database Architect | Always requires 2 approvals; migration review mandatory |
| `/.github/workflows/**`, `Dockerfile*` | DevOps/Cloud Architect | |
| `/backend/src/ai/**` | AI Engineer | |
| `/docs/**` | Product Manager | |

CODEOWNERS doesn't block *contribution* from anyone — it blocks *merge* until the relevant owner has approved, which is what makes the two-approval rule in §5 enforceable rather than aspirational.

---

## 10. CI/CD Strategy

Three pipelines, all defined in `.github/workflows/`:

**`ci.yml`** — runs on every PR into `staging` or `main`:
- Lint + typecheck (both apps)
- Unit + integration tests (both apps)
- Build check (Flutter web build, NestJS build)
- Prisma migration dry-run/diff check when `schema.prisma` changes

**`deploy-staging.yml`** — runs on every merge to `staging`:
- Build and push backend image
- Build and deploy frontend (static hosting/CDN)
- Run Prisma migrations against staging DB
- Smoke test against staging health endpoint

**`deploy-production.yml`** — runs on tag push to `main` (i.e., on release):
- Same build/deploy steps as staging, targeting production infra
- Migration step requires the migration to have already run successfully on staging (gate, not re-run blind)
- Post-deploy smoke test; automatic rollback to previous image on smoke-test failure

**Branch protection rules** enforce that `ci.yml` must pass and required approvals (per §5/§9) must be met before merge — this is configured at the repo level, not left to convention.

---

## 11. Environment Management

| Environment | Purpose | Deploy trigger | Data |
|---|---|---|---|
| **Local** | Individual dev machines | Manual (`docker-compose up`) | Local Postgres, seeded fixtures, sandbox/dev API keys for all platforms |
| **Staging** | Integration testing, blueprint regression passes | Auto on merge to `staging` | Anonymized/seed data; sandbox social platform accounts (never real user data) |
| **Production** | Live users | Auto on tag push to `main` | Real data; production API credentials, secrets in KMS/Secrets Manager, never in `.env` files committed anywhere |

**Secrets policy:** every environment has its own credential set (own OAuth app registrations for Instagram/X/Facebook/Threads/LinkedIn per environment, per the platform-constraints section of the architecture doc). Production secrets are never available to any CI job that runs on a PR from a fork or an unreviewed branch — only the tag-triggered production pipeline has access.

**Config drift prevention:** `.env.example` is kept in sync with actual required variables as a CI check — a PR that adds a new env var without updating `.env.example` fails CI.

---

## 12. Development Workflow — First Commit to Production

Concretely, this is what building **one blueprint milestone** looks like end to end:

1. Pull latest `staging`, branch as `feat/<phase>.<milestone>-<desc>`.
2. Confirm the milestone's **Prerequisites** (from the blueprint) are actually merged into `staging` — don't start on a blocked milestone.
3. Implement exactly the milestone's listed files/folders (created + modified) — nothing outside that scope.
4. Write the tests specified in that phase's "Testing requirements."
5. Run lint/test/build locally before pushing (fast feedback beats waiting on CI).
6. Push, open PR into `staging` with the milestone reference and template filled in.
7. CI runs automatically; author requests review once green.
8. Reviewer(s) approve per §6/§9 rules; author squash-merges.
9. Merge triggers auto-deploy to **staging**; milestone's "Expected output" is verified live on staging, not just locally.
10. Branch deleted; next dependent milestone (per the blueprint's dependency graph) is now unblocked.
11. Once a phase's milestones are all merged and the phase's "Definition of Done" is verified on staging, a release PR (`staging` → `main`) is opened.
12. Release PR approved, merged, tagged — triggers production deploy pipeline, post-deploy smoke test, and (per §8) a version bump reflecting what shipped.
13. If production smoke tests fail, automatic rollback fires; a `hotfix/*` branch is opened against `main` to address it, following the hotfix path in §7.

This loop repeats milestone by milestone, phase by phase, following the blueprint's dependency graph — which is also why the graph matters operationally, not just as documentation: it tells you which branches can run in parallel and which must wait.
