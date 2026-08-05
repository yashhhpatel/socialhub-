# SocialHub — Flutter Web Application Architecture

Architecture only — no implementation code. This expands on the `frontend/` tree from the folder structure doc into the actual patterns each part follows.

---

## 1. Feature-Based Folder Structure

Already laid out in the folder structure doc; the architectural rule behind it:

```
lib/
├── app/           # composition root — wires everything below together
├── core/          # cross-cutting concerns, no feature knowledge
└── features/      # one folder per feature, each internally layered
    └── <feature>/
        ├── data/          # repositories, DTOs, API/cache calls
        ├── domain/        # entities, use-cases, pure business rules
        └── presentation/  # screens, widgets, controllers/providers
```

**Governing rule:** a feature's `domain/` layer never imports from `data/` or `presentation/` — dependencies point inward (presentation → domain ← data), so business rules stay testable without a running network or widget tree. A feature may depend on `core/`, never on another feature's internals directly — cross-feature communication goes through `core/` (shared contracts) or through navigation/events, not direct imports, so features stay independently buildable and one feature's refactor can't silently break another.

---

## 2. State Management

**Riverpod**, chosen over BLoC/Provider/GetX for three reasons specific to this app: no `BuildContext` coupling (needed since autosave and publish-status logic run outside the widget tree), compile-time provider safety, and easy testability of the editor's history/undo-redo logic in isolation.

**Provider taxonomy used consistently across features:**
- **`Provider`** — read-only dependencies (repositories, services) — composed in `core/di`.
- **`StateNotifierProvider`** — feature state with explicit transitions (auth session, editor canvas state, publish job status) — chosen over plain `StateProvider` wherever transitions have rules (e.g., "can't go from `draft` to `published` directly").
- **`FutureProvider`/`AsyncNotifierProvider`** — server-derived data (asset lists, analytics queries) — gives loading/error/data states for free, matching the error-handling model in §9.
- **`family` modifiers** — parameterized providers (e.g., one comment-thread provider per `assetId`, not a single provider trying to hold every asset's comments at once).

**Scoping discipline:** most state is feature-scoped and disposed when the feature's route is left (e.g., editor canvas state doesn't linger in memory once you navigate away). Only genuinely app-wide state — auth session, theme, connectivity status — lives at the root `ProviderScope` in `core/di`.

---

## 3. Dependency Injection

Composition happens in `core/di/providers.dart`, which is the **only** place that knows how every repository/service is wired to its concrete implementation.

- **Interfaces in `domain/`, implementations in `data/`.** Presentation-layer code depends on the domain interface, never the concrete class — this is what makes a repository swappable for a fake in widget tests without touching any UI code.
- **Environment-based composition:** the DI root reads a build-time environment flag to decide whether `SocialAccountsRepository` is backed by the real `ApiClient` or a fixture-backed fake — used for local development against a seeded backend and for isolated widget-test runs.
- **No service locators.** Everything flows through Riverpod's provider graph, so a provider's dependencies are declared, not looked up dynamically — this keeps "what does the publish flow actually depend on" answerable by reading one file, not by tracing runtime calls.

---

## 4. Routing

`go_router`, chosen for its first-class support for URL-based deep linking (required for a PWA — a shared link to a specific asset or dashboard view must work as a real URL, not just in-app navigation state) and declarative route guards.

- **Route table lives in `core/router/app_router.dart`**, feature screens only expose themselves as route *destinations* — a feature doesn't know its own URL path, the router assigns it, keeping routing a cross-cutting concern rather than something scattered across features.
- **Guards** (`core/router/route_guards.dart`) handle: unauthenticated redirect to `/login`, role-gated redirect (e.g., a `viewer` hitting `/settings/team` bounces to a "not permitted" screen, not a raw 403), and unsaved-editor-changes confirmation before navigating away.
- **Nested routing** for the app shell: an outer shell route owns the persistent nav rail/bottom nav (per the responsive design in §6), with feature routes rendering inside it — avoids rebuilding the whole shell on every navigation.
- **Deep-linkable state:** where it matters for shareability (analytics date range, dashboard filters), state lives in query parameters, not just in-memory provider state, so a copied URL reproduces the same view.

---

## 5. Theme

Design tokens (colors, spacing, typography) live in `core/theme/tokens/`, consumed by `light_theme.dart`/`dark_theme.dart` — screens and widgets **never** hardcode a color or font size; they reference a token, so a brand refresh or the Enterprise white-labeling feature (Phase 15) only touches the token layer.

- **Light/dark mode** is a `ThemeMode` provider at the app root, persisted locally (see §10) so it survives reload — not re-derived from OS preference on every launch, since a user's explicit choice should stick.
- **White-labeling (Enterprise):** org-level color/logo overrides layer on top of the base theme at runtime rather than requiring a rebuild — the theme system is designed from the start to accept a per-org override object, even though only Enterprise orgs populate one.
- **Typography:** Google Fonts loaded through the editor's font-picker feature use the same token scale as the app chrome, so a design created in the editor and the surrounding dashboard UI feel like one coherent product, not two.

---

## 6. Responsive Design

Desktop-first (per the architecture doc), with defined breakpoints rather than ad hoc `MediaQuery` checks scattered through the codebase:

| Breakpoint | Range | Layout behavior |
|---|---|---|
| Desktop | ≥ 1200px | Persistent left nav rail, multi-column dashboard, editor with all panels visible |
| Tablet | 768–1199px | Collapsible nav rail (icon-only by default), editor panels become toggleable overlays |
| Mobile web | < 768px | Bottom nav bar replaces rail, editor toolbar collapses into a bottom sheet, single-column everything |

- **One shared `Breakpoints` utility in `core/theme`** — every responsive decision in the app reads from this, so breakpoint values are changed in exactly one place if they ever need adjusting.
- **Layout, not just sizing, changes at breakpoints** — e.g., the editor's property panel is a persistent side panel on desktop but a bottom sheet on mobile, not just a resized version of the same widget tree. This is decided per-feature in `presentation/`, using shared responsive-layout helpers from `core/`.
- **Editor is the hardest case:** full layer/property/template editing on a small mobile viewport is intentionally simplified (view + light edits + publish, not full multi-layer composition) rather than cramming the desktop editor into a phone screen — this is a deliberate scope decision, not a gap to "fix" later.

---

## 7. Widgets & Reusable Components

- **`shared_widgets/`** (per the folder structure doc) holds components used by 2+ features — populated reactively as duplication is observed during development, not pre-built speculatively.
- **Composition over configuration:** shared components favor small, composable widgets (a `PrimaryButton`, a `LoadingOverlay`, an `EmptyStateView`) over one large widget with a dozen boolean flags — keeps each one legible and testable in isolation.
- **Feature-owned widgets stay in the feature.** The canvas engine's `image_layer`/`text_layer`/`video_layer` widgets are editor-specific and never promoted to `shared_widgets/`, even though they're complex — reuse is about *other features needing the same thing*, not about complexity alone.

---

## 8. Error Handling

- **Typed failures, not raw exceptions, cross the domain boundary.** `core/error/failure.dart` defines a small closed set of failure types (`NetworkFailure`, `ValidationFailure`, `AuthFailure`, `PermissionFailure`, `UnknownFailure`) that repositories map raw exceptions/HTTP errors into — presentation code branches on failure *type*, never on parsing an error string.
- **Global error boundary** (`core/error/error_boundary.dart`) catches anything that escapes a feature's own handling and shows a graceful fallback screen with a "reload" action and an error-reporting hook (Sentry), rather than a blank white screen or a Flutter red-screen-of-death in production.
- **Inline vs. global handling:** expected, recoverable failures (a failed publish, a quota-exceeded AI call) are handled inline within the feature — shown as a status badge or retry button, matching the async states from the `PublishJobStatus`/AI quota model — while truly unexpected failures fall through to the global boundary.
- **Every network-backed provider exposes loading/error/data as a matter of course** (via `AsyncValue` from Riverpod), so "what does the UI show while this is failing" is answered by the same pattern everywhere, not reinvented per screen.

---

## 9. Caching

- **In-memory provider cache is the default.** Riverpod providers naturally cache their last-resolved value for the lifetime of their scope — a re-visited screen doesn't necessarily refetch if the provider is still alive and the data is reasonably fresh.
- **`core/storage/local_store.dart`** wraps IndexedDB (via Hive or similar) for anything that must survive a full page reload: the editor's in-progress autosave buffer (§11), the user's theme preference, and a short-lived cache of the "connected accounts" list so the settings screen isn't blank on a cold PWA launch before the network responds.
- **Cache invalidation is explicit, not time-based guessing.** Mutating actions (publish, save, invite) invalidate the specific providers they affect (e.g., publishing invalidates the relevant `publish_job` list provider) rather than relying on a TTL — this avoids the two classic cache bugs: stale data after a known mutation, and unnecessary refetching of data nothing has touched.
- **Analytics queries are the one deliberately time-cached exception** — dashboard data is acceptable to show slightly stale (matching the read-replica strategy in the database doc), so those providers use a short TTL (e.g., 5 minutes) rather than being invalidated on every possible upstream change.

---

## 10. Networking

- **`core/network/api_client.dart`** is the single HTTP client instance for all REST calls — one place for base URL, timeout policy, and default headers, so no feature independently reinvents its own HTTP setup.
- **`auth_interceptor.dart`** attaches the bearer token to every request and transparently performs a silent refresh-and-retry on a 401 caused by an expired access token — a feature's repository code never has to know tokens exist.
- **`graphql_client.dart`** is a separate, purpose-built client only for the analytics module's GraphQL queries (per the architecture doc's REST + GraphQL split) — kept distinct rather than forcing GraphQL through the REST client's assumptions.
- **Request/response DTOs mirror the backend's Swagger-documented contracts exactly** (per the REST API design doc) — generated or hand-kept in sync with `packages/api-contracts/openapi.yaml`, so a backend contract change surfaces as a compile error on the frontend rather than a silent runtime mismatch.
- **Retry policy:** idempotent GET requests get automatic retry with backoff on transient network failure; mutating requests (POST/PATCH/DELETE) do not auto-retry silently — a failed publish or save surfaces to the user rather than risking a duplicate action from a blind retry.

---

## 11. Offline Strategy

- **PWA shell caching** (service worker, per `web/manifest.json`) ensures the app itself loads even with no network — this is shell availability, not full offline functionality.
- **Editor autosave is local-first.** Canvas edits write to `local_store` immediately and sync to the backend on a debounce (per the blueprint's Phase 3 autosave milestone) — if the network drops mid-edit, work isn't lost; it's queued locally and reconciled once connectivity returns.
- **Reconciliation on reconnect:** on regaining connectivity, the local autosave buffer is diffed against the server's last-known state for that asset. Last-write-wins at the field level is the default policy for MVP; a more granular operational-transform approach is a considered future enhancement if multi-user simultaneous editing (beyond the Phase 13 comment/approval workflow) is ever built — not scoped now.
- **What's explicitly NOT offline-capable:** publishing, AI generation, analytics, and account connection all require a live network by nature (they call external platform APIs) — the offline strategy scopes itself honestly to "don't lose editor work," not "the whole app works offline," which would be a false promise given the product's core dependency on external services.
- **Connectivity awareness:** a root-level connectivity provider drives a persistent (but unobtrusive) offline banner, so the user always knows why an action might be failing rather than seeing a generic error.

---

## 12. Performance Optimization

- **CanvasKit renderer for the editor route, evaluated per-route rather than app-wide** — the editor benefits from CanvasKit's better complex-graphics fidelity/performance; simpler dashboard/marketing routes may use the lighter HTML renderer if bundle-size profiling shows a meaningful win from splitting (a decision made from real measurement during Phase 3/6, not assumed upfront).
- **Route-level code splitting via deferred imports** — the editor's canvas engine (the single heaviest feature) is not loaded until a user actually navigates to it, keeping initial load fast for users who only check analytics or scheduling.
- **Image/video assets served through Cloudinary's transformation URLs** at the exact dimensions needed per context (thumbnail vs. full editor canvas vs. platform preview), never shipping a full-resolution asset to a 200px thumbnail slot.
- **`const` constructors and widget rebuild scoping** enforced via lint rules — Riverpod's `select()` is used on providers with large state objects (e.g., the editor's canvas state) so a widget only rebuilds when the specific slice it reads actually changes, not on every canvas mutation.
- **Autosave debounce** (§11) doubles as a performance measure, not just a UX one — it prevents a network call (and the resulting state churn) on every single keystroke/drag frame during active editing.
- **Analytics chart rendering** virtualizes/paginates large time-series datasets rather than rendering every raw data point — combined with the backend's rollup-aggregation strategy (from the database doc), the frontend never needs to render more points than a chart can meaningfully display anyway.
- **Web Vitals monitored in production** (via the same Sentry/observability pipeline as error tracking) so performance regressions are caught by data, not assumption, as features accumulate through the roadmap.
