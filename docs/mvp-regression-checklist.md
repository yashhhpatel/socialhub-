# SocialHub — MVP Regression Checklist

> **Note (2026-08-22):** the app now uses **action-level** auth — pages are browsable
> while logged out and only mutating actions redirect to `/login`. Any "logged-out user
> is redirected to /login" step below should be read as "logged-out user can browse; the
> *action* prompts login." The MVP path itself is unchanged.

Milestone 6.3. Run this before promoting a build to staging or production.
It exercises the full MVP path end to end — **register → connect an account
→ design → publish → view the result** — plus the cross-cutting concerns
added in Phase 6. Each item is a manual check; tick it only after observing
the stated result, not after assuming it.

Legend: ☐ not run · ✅ pass · ❌ fail (file an issue, link it)

---

## 0. Preconditions

- ☐ Backend `/health` returns `200 {"status":"ok"}`.
- ☐ Database migrations are current (`prisma migrate status` → "up to date").
- ☐ Frontend loads at its URL with no console errors on first paint.
- ☐ Required env is present for the environment under test: `DATABASE_URL`,
  `JWT_ACCESS_SECRET`, `TOKEN_ENCRYPTION_KEY`. Optional integrations
  (`ANTHROPIC_API_KEY`, Cloudinary, OAuth, `SENTRY_DSN`) present only if that
  surface is being tested.

## 1. Auth & organization (Phase 1)

- ☐ Register a new user → lands authenticated; an organization is created
  with the user as `owner`.
- ☐ Register with an already-used email → `409`, message "An account with
  this email already exists."
- ☐ Register with a weak/invalid payload → `400` with a **list** of
  field-level messages (not a single generic one).
- ☐ Log out, then log in with the same credentials → succeeds.
- ☐ Log in with a wrong password → `401` "Invalid email or password."
  (identical response whether or not the email exists).
- ☐ Leave the tab idle past the access-token lifetime, then act → the
  session refreshes silently; no forced re-login.
- ☐ Visit a protected route while logged out → redirected to `/login`.

## 2. Connected accounts (Phase 2)

- ☐ Connected Accounts screen lists the correct state per platform.
- ☐ Start the X (Twitter) connect flow → OAuth redirect works, returns to
  the app, account shows as `connected`.
- ☐ Instagram connect — **known blocked** at Meta app-config level; confirm
  it fails gracefully with a clear message, not a crash.
- ☐ Disconnect an account → it leaves the connected list; any publish
  history for it is preserved (not deleted).
- ☐ Reload → connection state persists.

## 3. Editor (Phase 3)

- ☐ Create a new design → editor opens on a blank canvas.
- ☐ Add a text layer, an image layer, and a shape.
- ☐ Move, resize, and rotate a layer; edit its colour/opacity.
- ☐ Undo (Ctrl+Z) and redo (Ctrl+Y) step correctly through changes.
- ☐ Edits autosave (no explicit save needed); reload the page → the design
  persists exactly.
- ☐ Image upload returns a hosted URL and the image renders on the canvas
  (requires Cloudinary configured).

## 4. Variants & publish (Phase 4)

- ☐ Generate platform variants for a design → each target platform gets a
  correctly-sized rendition; regenerating updates rather than duplicates.
- ☐ Open the publish modal → only valid (ready variant + connected account,
  same platform) pairs are offered.
- ☐ Publish to a connected sandbox/test account → a live post appears;
  status shows success with the platform post id.
- ☐ Force a failure (e.g. oversized caption) → status shows the platform's
  own error text; no double-post on retry.

## 5. AI caption (Phase 5)

- ☐ In the publish modal, generate a caption → text appears and is editable.
- ☐ Regenerate, and generate with a specific tone → new text each time.
- ☐ Edit the generated caption, then publish → the **edited** text is what
  posts.
- ☐ Clear the caption and publish → posts with no caption (does not silently
  reuse the variant's older caption).
- ☐ With no `ANTHROPIC_API_KEY` → the generate button returns a clear `503`,
  not a crash.
- ☐ Exhaust the org's AI quota → `429` with a reset time; the panel shows
  *when* generation resumes rather than offering a pointless retry.

## 6. Error handling & monitoring (Phase 6)

- ☐ Hit an endpoint with a bad payload → response is the standard envelope
  (`statusCode`, `error`, `message`, `requestId`, `path`, `timestamp`).
- ☐ Trigger a server-side fault → response is a generic `500` with a
  `requestId` and **no stack trace or internal detail** in the body; the
  full error is in the server logs against that `requestId`.
- ☐ Force a widget build error in the frontend → the friendly "Something
  went wrong" fallback renders instead of a red/grey crash screen.
- ☐ With `SENTRY_DSN` set → the server-side fault above appears as a Sentry
  event tagged with the matching `requestId`; `4xx`s do **not** create
  events.
- ☐ With `SENTRY_DSN` unset → app runs normally, nothing reported, no error
  about the missing DSN.

## 7. Deploy pipeline (Phase 6.2)

- ☐ A PR to `main` build-validates both Docker images (deploy workflow
  green) without publishing.
- ☐ A merge to `main` publishes `socialhub-backend:staging` and
  `socialhub-frontend:staging` to GHCR.
- ☐ If `STAGING_DEPLOY_WEBHOOK` is configured → the staging host pulls and
  runs the new images; the deployed site reflects the merge.

---

## Sign-off

| Field | Value |
|---|---|
| Build / commit | |
| Environment | |
| Run by | |
| Date | |
| Result | ☐ all pass · ☐ pass with known issues · ☐ blocked |
| Known issues (linked) | |
