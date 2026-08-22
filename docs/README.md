# SocialHub Documentation

Project planning and reference documentation. **Start here:**

- **[`GAP_ANALYSIS.md`](GAP_ANALYSIS.md)** — reconciled, per-feature implementation
  status and the current gap list (the source of truth; updated 2026-08-22).

## Design & reference
- [`SocialHub_Architecture_Plan.md`](SocialHub_Architecture_Plan.md) — overall architecture & phased roadmap.
- [`SocialHub_Implementation_Blueprint.md`](SocialHub_Implementation_Blueprint.md) — phase/milestone plan (history; status banner at top).
- [`SocialHub_Database_Design.md`](SocialHub_Database_Design.md) — data model (see §10 for the delta since initial design; `backend/prisma/schema.prisma` is authoritative).
- [`SocialHub_REST_API_Design.md`](SocialHub_REST_API_Design.md) — REST contracts (see §12 for endpoints added since; the controllers are authoritative).
- [`SocialHub_Flutter_Web_Architecture.md`](SocialHub_Flutter_Web_Architecture.md) — frontend architecture.
- [`SocialHub_Folder_Structure.md`](SocialHub_Folder_Structure.md) — intended repo layout (partly aspirational — see GAP_ANALYSIS §5).
- [`SocialHub_Git_Workflow.md`](SocialHub_Git_Workflow.md) — branching/release conventions (partly aspirational — see GAP_ANALYSIS §5).
- [`META_APP_REVIEW.md`](META_APP_REVIEW.md) — Meta App Review runbook.
- [`mvp-regression-checklist.md`](mvp-regression-checklist.md) — manual regression checklist.
- [`architecture/adr/`](architecture/adr/) — Architecture Decision Records
  (currently: `0001-supported-social-platforms.md`).

> Note: this repo keeps documentation as flat files here (plus `architecture/adr/`).
> Earlier drafts of this index referenced `blueprint/`, `git-workflow/`, `api/`,
> `runbooks/`, and `onboarding/` subfolders that were never created.
