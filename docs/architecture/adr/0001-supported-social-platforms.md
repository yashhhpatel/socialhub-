# ADR 0001: Supported Social Platforms

**Status:** Accepted

## Context

The project's target platform set has been Instagram, Facebook, Threads,
X (Twitter), and LinkedIn from the original architecture plan onward —
this was never in question. A request came in to explicitly confirm
TikTok, YouTube, and Pinterest are **not** supported and to remove any
trace of them from the roadmap, code, and docs.

A full repository search (source code, Prisma schema, and every planning
document) turned up zero references to TikTok, YouTube, or Pinterest
anywhere in the project. There was nothing to remove. This ADR exists to
record that finding as a durable, explicit decision — not just something
that happened to be true by omission — so it persists for future
milestones and future sessions, rather than only living in chat history
that could be lost.

## Decision

SocialHub supports exactly these five platforms, now and for the
foreseeable roadmap:

- Instagram
- Facebook
- Threads
- X (Twitter)
- LinkedIn

TikTok, YouTube, and Pinterest are explicitly out of scope. No code,
schema, interface, test, or documentation should reference them unless a
future decision reverses this ADR.

## Why the architecture stays extensible anyway

Nothing about "only 5 platforms" required closing the door on a 6th one
later — the adapter pattern was already designed to make that an
additive change, not a redesign:

1. **`PlatformAdapter` interface**
   (`backend/src/social-accounts/adapters/adapter.interface.ts`) defines
   the contract every platform implements: `capabilities()`,
   `getAuthorizationUrl()`, `connect()`, `refresh()`. A new platform
   means writing one new class implementing this interface — nothing
   about the interface itself, or any existing adapter, needs to change.
   `InstagramAdapter` and `XAdapter` already prove this: X needed PKCE
   support Instagram doesn't use, added as *optional* parameters on the
   shared interface, and Instagram's adapter needed zero code changes
   when that happened (Milestone 2.3).

2. **`Platform` enum** (`backend/prisma/schema.prisma`) is a plain
   Prisma enum. Adding a value is a single-line schema change plus a
   migration — it doesn't touch `SocialAccount`'s structure, any
   existing adapter, or any other model.

3. **`PlatformName` type**
   (same file as the interface) mirrors the Prisma enum's values
   exactly, by design — the two are kept in lockstep deliberately so a
   new platform is added in exactly two places, not scattered ad hoc
   through the codebase.

4. **One file per adapter**
   (`backend/src/social-accounts/adapters/`) — each platform is fully
   self-contained. Adding TikTok later means adding
   `tiktok.adapter.ts`, registering it in `SocialAccountsModule`
   alongside the existing two, and adding its routes to
   `SocialAccountsController` — the same shape as Milestones 2.2/2.3,
   not a new pattern to invent.

5. **Frontend mirrors this**: `SocialPlatform` enum
   (`frontend/lib/features/social_accounts/domain/entities/social_platform.dart`)
   already carries an `isConnectable` flag specifically so a platform
   can exist in the UI (shown as "coming soon") before it has a real
   backend adapter — this is exactly the mechanism Facebook/Threads/
   LinkedIn use today, and the same mechanism a genuinely new platform
   would use if ever added.

## Consequences

- No code changes were made as a result of this request — there was
  nothing non-conforming to fix.
- Future milestones (Phase 8's Facebook/Threads/LinkedIn adapters, and
  anything beyond) continue to target only the five platforms above.
- If TikTok, YouTube, or Pinterest support is ever reconsidered, that
  decision should supersede this ADR explicitly, rather than being
  inferred from silence.
