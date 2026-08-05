# SocialHub — Complete Production Folder Structure

This reflects the fully-built project at the end of the roadmap (MVP → V1 → V2 → Enterprise), built up incrementally by the milestones in the implementation blueprint. Every folder below has an explanation; no implementation code is shown.

```
socialhub/
├── frontend/
├── backend/
├── packages/
├── infrastructure/
├── docker/
├── .github/
├── docs/
├── scripts/
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env.example
├── .gitignore
├── .editorconfig
├── CODEOWNERS
├── LICENSE
└── README.md
```

---

## 1. Frontend (Flutter Web)

```
frontend/
├── lib/
│   ├── app/
│   │   ├── app.dart                     # Root widget, top-level providers wiring
│   │   └── bootstrap.dart               # App startup sequence (env, error handlers, DI)
│   │
│   ├── core/
│   │   ├── theme/
│   │   │   ├── tokens/                  # Color, spacing, typography design tokens
│   │   │   ├── light_theme.dart
│   │   │   └── dark_theme.dart
│   │   ├── router/
│   │   │   ├── app_router.dart          # go_router route table
│   │   │   └── route_guards.dart        # Auth/role-gated route protection
│   │   ├── network/
│   │   │   ├── api_client.dart          # Base HTTP client config
│   │   │   ├── auth_interceptor.dart    # Token attach + silent refresh
│   │   │   └── graphql_client.dart      # For analytics module queries
│   │   ├── error/
│   │   │   ├── error_boundary.dart      # Global fallback UI on crash
│   │   │   └── failure.dart             # Typed error/result models
│   │   ├── storage/
│   │   │   └── local_store.dart         # IndexedDB/Hive wrapper (offline autosave)
│   │   ├── di/
│   │   │   └── providers.dart           # Riverpod provider composition root
│   │   └── constants/
│   │       └── platform_specs.dart      # Client-side mirror of platform capability limits
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/                    # Repositories, DTOs, API calls
│   │   │   ├── domain/                  # Entities, use-cases
│   │   │   └── presentation/            # Screens, widgets, controllers
│   │   ├── social_accounts/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── editor/
│   │   │   ├── canvas/                  # CustomPainter engine, layer rendering
│   │   │   │   ├── image_layer.dart
│   │   │   │   ├── text_layer.dart
│   │   │   │   └── video_layer.dart
│   │   │   ├── panels/                  # Layer panel, property panel, toolbar
│   │   │   ├── state/                   # History controller (undo/redo), autosave logic
│   │   │   ├── data/  domain/  presentation/
│   │   ├── templates/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── marketplace/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── brand_kit/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── publish/
│   │   │   ├── widgets/
│   │   │   │   └── caption_panel.dart
│   │   │   ├── data/  domain/  presentation/
│   │   ├── scheduler/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── ai_suite/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── analytics/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── team/
│   │   │   ├── data/  domain/  presentation/
│   │   ├── collaboration/
│   │   │   ├── data/  domain/  presentation/   # Comments + approval workflow UI
│   │   └── settings/
│   │       ├── white_label_screen.dart
│   │       ├── data/  domain/  presentation/
│   │
│   └── shared_widgets/
│       ├── buttons/  forms/  loaders/  empty_states/
│                                          # Cross-feature reusable UI, promoted here
│                                          # once used by 2+ features
│
├── web/
│   ├── index.html
│   ├── manifest.json                    # PWA manifest (installability)
│   └── icons/                           # PWA icon set (all required sizes)
│
├── test/
│   ├── unit/                            # Mirrors lib/ structure — logic-only tests
│   ├── widget/                          # Component-level rendering/interaction tests
│   └── integration/                     # e2e flows (login → design → publish)
│
├── pubspec.yaml
└── analysis_options.yaml                # Lint rules
```

**Structure rationale:** `features/` is feature-first, not layer-first — each feature owns its own `data/domain/presentation`, so a milestone touching "publishing" never requires editing five scattered top-level folders. `shared_widgets/` is intentionally populated *after* duplication is observed, not pre-guessed, to avoid premature abstraction.

---

## 2. Backend (NestJS)

```
backend/
├── src/
│   ├── main.ts                          # App bootstrap, global pipes/filters
│   ├── app.module.ts                    # Root module composition
│   │
│   ├── config/
│   │   ├── config.module.ts
│   │   └── env.validation.ts            # Fails fast on missing/invalid env vars
│   │
│   ├── common/
│   │   ├── guards/
│   │   │   ├── roles.guard.ts           # RBAC enforcement
│   │   │   ├── jwt-auth.guard.ts
│   │   │   └── org-rate-limit.guard.ts
│   │   ├── filters/
│   │   │   └── http-exception.filter.ts # Global error normalization
│   │   ├── interceptors/
│   │   │   └── audit-log.interceptor.ts # Captures every mutating action
│   │   ├── decorators/
│   │   │   └── roles.decorator.ts
│   │   └── crypto/
│   │       └── token-encryption.service.ts  # OAuth token at-rest encryption
│   │
│   ├── auth/
│   │   ├── auth.module.ts  auth.controller.ts  auth.service.ts
│   │   └── sso/                         # SAML strategy (Enterprise phase)
│   │
│   ├── users/
│   ├── organizations/
│   │   └── invites/                     # Team invite flow
│   │
│   ├── social-accounts/
│   │   ├── adapters/
│   │   │   ├── adapter.interface.ts     # Shared contract: capabilities/connect/refresh/publish
│   │   │   ├── instagram.adapter.ts
│   │   │   ├── facebook.adapter.ts
│   │   │   ├── threads.adapter.ts
│   │   │   ├── x.adapter.ts
│   │   │   └── linkedin.adapter.ts
│   │   └── social-accounts.service.ts
│   │
│   ├── content/
│   │   ├── comments/                    # Collaboration module
│   │   ├── variant-generator.service.ts # Platform-specific resize/crop/trim
│   │   ├── approval.service.ts
│   │   └── content.controller.ts
│   │
│   ├── media/
│   │   ├── cloudinary.service.ts
│   │   └── video-processing.service.ts
│   │
│   ├── templates/
│   │   └── marketplace.controller.ts
│   │
│   ├── brand-kits/
│   │
│   ├── publishing/
│   │   ├── processors/                  # One BullMQ processor per platform (failure isolation)
│   │   │   ├── instagram.processor.ts
│   │   │   ├── facebook.processor.ts
│   │   │   ├── threads.processor.ts
│   │   │   ├── x.processor.ts
│   │   │   └── linkedin.processor.ts
│   │   ├── schedule.cron.ts
│   │   └── publishing.service.ts
│   │
│   ├── queue/
│   │   └── queue.module.ts              # Redis/BullMQ infrastructure
│   │
│   ├── ai/
│   │   ├── prompts/
│   │   │   ├── caption.prompt.ts
│   │   │   ├── hashtags.prompt.ts
│   │   │   └── tone.prompt.ts
│   │   ├── ai-gateway.service.ts        # Provider-agnostic AI call wrapper
│   │   ├── quota.guard.ts
│   │   ├── viral-score.service.ts
│   │   └── best-time.service.ts
│   │
│   └── analytics/
│       ├── ingestion/                   # Scheduled per-platform metric pull workers
│       └── analytics.resolver.ts        # GraphQL resolver for dashboard queries
│
├── prisma/
│   ├── schema.prisma
│   ├── migrations/                      # One folder per migration, timestamped
│   └── seed.ts                          # Local/staging fixture data
│
├── test/
│   ├── unit/                            # Mirrors src/ structure
│   ├── integration/                     # Module-level tests against a test DB
│   └── e2e/                             # Full HTTP-level flow tests
│
├── Dockerfile
├── nest-cli.json
├── tsconfig.json
└── package.json
```

**Structure rationale:** modules map 1:1 to the phases in the blueprint (`social-accounts/adapters` = Phase 2/8, `publishing/processors` = Phase 7, `ai/` = Phase 5/12). This means "which folder does milestone X.Y touch" is answerable just by re-reading the blueprint's phase name.

---

## 3. Shared Packages

```
packages/
├── api-contracts/
│   ├── openapi.yaml                     # Source-of-truth REST contract, generated from NestJS
│   └── graphql-schema.graphql           # Source-of-truth GraphQL schema (analytics)
│
└── platform-specs/
    └── platform-capabilities.json       # Canonical media/caption/rate-limit specs per platform —
                                          # consumed by both backend adapters (enforcement) and
                                          # frontend (client-side validation/preview), so the two
                                          # never drift out of sync on "what's allowed on X"
```

**Why this exists:** the biggest risk in a Flutter-Web-+-NestJS split is the two sides silently disagreeing about API shape or platform limits. These packages aren't runtime code — they're the single generated/hand-maintained source of truth both sides validate against in CI (a contract-drift check fails the build if `openapi.yaml` doesn't match the live NestJS-generated spec).

---

## 4. Infrastructure (Infrastructure-as-Code)

```
infrastructure/
├── terraform/
│   ├── environments/
│   │   ├── staging/
│   │   │   └── main.tf                  # Staging-specific resource sizing/config
│   │   └── production/
│   │       └── main.tf                  # Production-specific resource sizing/config
│   ├── modules/
│   │   ├── ecs-service/                 # Reusable Fargate service module (backend)
│   │   ├── rds-postgres/
│   │   ├── elasticache-redis/
│   │   ├── s3-cloudfront/               # Frontend static hosting + CDN
│   │   └── secrets-manager/
│   └── backend.tf                       # Remote state config
│
└── runbooks/
    ├── incident-response.md
    ├── rollback-procedure.md
    └── scaling-checklist.md
```

**Purpose:** infrastructure is versioned and reviewed exactly like application code — a change to production resource sizing goes through the same PR/review process as a feature, and `staging`/`production` are structurally identical modules with different variables, not hand-maintained consoles that drift apart over time.

---

## 5. Docker

```
docker/
├── backend/
│   └── Dockerfile                       # Multi-stage: build → slim runtime image
├── frontend/
│   └── Dockerfile                       # Multi-stage: flutter build web → nginx static serve
│                                         # (only used if not deploying frontend straight to S3/CDN)
└── nginx/
    └── nginx.conf                       # Reverse proxy config for local/self-hosted parity
```

*(Note: `backend/Dockerfile` and `frontend/Dockerfile` may alternatively live at each app's root, as shown in §1/§2 — this `docker/` folder is the alternative centralized location if the team prefers all container definitions grouped together. Pick one convention at Milestone 0.1 and keep it consistent; don't do both.)*

- **`docker-compose.yml`** (repo root) — local dev: Postgres, Redis, backend, frontend, all networked together with one command.
- **`docker-compose.prod.yml`** (repo root) — production-shaped compose file, useful for self-hosted/on-prem enterprise deployments distinct from the AWS ECS path.

---

## 6. CI/CD

```
.github/
├── workflows/
│   ├── ci.yml                           # Lint, typecheck, test, build — every PR
│   ├── deploy-staging.yml               # Auto-deploy on merge to `staging`
│   ├── deploy-production.yml            # Deploy on tag push to `main`
│   ├── migration-check.yml              # Prisma migration dry-run/diff on schema changes
│   └── contract-drift-check.yml         # Fails if openapi.yaml/graphql-schema.graphql are stale
│
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   └── feature_request.md
│
└── PULL_REQUEST_TEMPLATE.md             # Milestone reference, checklist, screenshots
```

---

## 7. Documentation

```
docs/
├── architecture/
│   ├── SocialHub_Architecture_Plan.md   # The original architecture & planning doc
│   └── adr/                             # Architecture Decision Records — one file per
│       │                                 # significant decision (e.g., "why modular monolith
│       │                                 # over microservices at MVP"), numbered sequentially
│       └── 0001-modular-monolith-at-mvp.md
│
├── blueprint/
│   └── SocialHub_Implementation_Blueprint.md   # Phases/milestones source of truth
│
├── git-workflow/
│   └── SocialHub_Git_Workflow.md
│
├── api/
│   └── (generated) REST + GraphQL reference, published from packages/api-contracts
│
├── runbooks/
│   └── (symlink or copy of infrastructure/runbooks for discoverability)
│
├── mvp-regression-checklist.md          # Manual QA checklist from Phase 6
│
└── onboarding/
    └── new-developer-setup.md           # Clone → docker-compose up → first PR, in one page
```

---

## 8. Scripts

```
scripts/
├── setup/
│   └── bootstrap-local-env.sh           # One-command local environment setup
├── db/
│   ├── seed.sh                          # Wraps prisma/seed.ts
│   └── reset.sh                         # Drop/recreate local DB for a clean slate
├── ci/
│   └── check-env-sync.sh                # Fails CI if .env.example is out of sync with actual usage
└── release/
    └── generate-changelog.sh            # Builds release notes from Conventional Commit history
```

**Purpose:** anything a developer or CI job would otherwise run as a memorized multi-step manual process gets captured here instead — the goal is that "how do I reset my local DB" is answerable by reading a filename, not asking in Slack.

---

## 9. Tests (Cross-Cutting)

Most tests live *inside* `frontend/test/` and `backend/test/` as shown in §1/§2, colocated with the code they verify. This top-level folder is only for tests that span both apps:

```
(no dedicated top-level tests/ folder — see note below)
```

**Deliberate choice:** there is **no** top-level `/tests` folder. Per-app colocated tests (§1, §2) keep a milestone's test changes inside the same PR-scoped folder set as its implementation, which matches the blueprint's "Files/folders created/modified" milestone format. The one cross-cutting exception — full end-to-end flows that exercise both frontend and backend together (e.g., register → connect account → design → publish, referenced in Phase 6) — lives in `backend/test/e2e/` driven against a running frontend build in CI, rather than a separate top-level suite, to avoid a third, easily-forgotten test location.

---

## 10. Root-Level Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | One-command local dev environment (Postgres, Redis, both apps) |
| `docker-compose.prod.yml` | Production-shaped compose reference for self-hosted/enterprise deployments |
| `.env.example` | Documents every required environment variable across both apps; checked in CI for drift |
| `.gitignore` | Excludes build artifacts, `.env`, `node_modules`, `.dart_tool`, etc. |
| `.editorconfig` | Consistent indentation/line-ending rules across editors |
| `CODEOWNERS` | Maps folders to required reviewers (per the Git workflow doc, §9) |
| `LICENSE` | Project license |
| `README.md` | Project overview, quickstart, links to `docs/onboarding/new-developer-setup.md` |

---

## Summary: How This Maps Back to the Blueprint

Every top-level folder exists because a specific phase needed it:
- `frontend/lib/features/editor/canvas` → Phase 3
- `backend/src/publishing/processors` → Phase 7
- `packages/platform-specs` → Phases 2 & 8 (keeps adapters and editor previews in sync)
- `infrastructure/terraform/environments/production` → Phase 6/15
- `backend/src/auth/sso` → Phase 15

Nothing in this tree is speculative scaffolding — each folder traces to a milestone that creates it, which is also why the Git workflow's "files/folders created" field in every milestone will always point at a location already accounted for here.
