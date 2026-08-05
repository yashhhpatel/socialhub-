# SocialHub — Complete REST API Design

No implementation — endpoint contracts only. GraphQL (analytics dashboard queries) is out of scope here per the architecture doc; this covers every REST endpoint.

---

## 0. Global Conventions (apply to every endpoint below, not repeated each time)

**Base URL:** `https://api.socialhub.app/v1`

**Authentication header** (unless marked Public):
```
Authorization: Bearer <access_token>
```

**Standard error envelope** (all error responses share this shape):
```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Human-readable summary",
  "details": [
    { "field": "email", "issue": "must be a valid email address" }
  ],
  "requestId": "req_9f8a2b3c"
}
```

**Standard pagination** (list endpoints):
```
GET /resource?page=1&limit=20&sort=-createdAt
```
```json
{
  "data": [ /* items */ ],
  "meta": { "page": 1, "limit": 20, "total": 143, "totalPages": 8 }
}
```

**Common error responses** (listed per-endpoint only when they add specific meaning; otherwise assume these apply everywhere):
| Code | Meaning |
|---|---|
| 400 | Validation failure |
| 401 | Missing/invalid/expired access token |
| 403 | Authenticated but not permitted (role/ownership check failed) |
| 404 | Resource not found or not visible to this org |
| 409 | Conflict (duplicate/unique constraint) |
| 422 | Semantically invalid (e.g., publishing an unapproved asset) |
| 429 | Rate limit or quota exceeded |
| 500 | Unexpected server error |

**Permissions shorthand:** roles are `owner > admin > editor > viewer`, per the RBAC model. "Editor+" means editor, admin, or owner.

**Swagger documentation structure** (applies globally): every controller uses `@ApiTags('<module>')`; every route uses `@ApiOperation`, `@ApiResponse` per status code, `@ApiBearerAuth()` unless public, and `@ApiBody`/`@ApiParam`/`@ApiQuery` with DTO classes decorated via `class-validator` + `@ApiProperty()` so Swagger's generated schema and the actual `class-validator` rules never drift apart. Swagger UI is grouped by tag matching the module names below (`Auth`, `Organizations`, `SocialAccounts`, `Content`, `Publishing`, `AI`, `Analytics`, `Templates`, `BrandKits`, `AuditLogs`, `Health`).

---

## 1. Health

### `GET /health`
- **Auth:** Public
- **Request:** none
- **Response (200):**
```json
{ "status": "ok", "uptime": 12345, "version": "1.4.2" }
```
- **Validation:** none
- **Errors:** 500 if DB connection check fails
- **Permissions:** none
- **Swagger:** `@ApiTags('Health')`, no `@ApiBearerAuth()`

---

## 2. Auth

### `POST /auth/register`
- **Auth:** Public
- **Request:**
```json
{ "email": "jane@acme.com", "password": "MinLength8!", "orgName": "Acme Inc." }
```
- **Response (201):**
```json
{
  "user": { "id": "usr_01", "email": "jane@acme.com", "role": "owner", "orgId": "org_01" },
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```
- **Validation:** `email` valid format + unique; `password` min 8 chars, 1 number, 1 symbol; `orgName` 2–100 chars
- **Error responses:** 409 if email already registered
- **Permissions:** none (creates the first user/org)
- **Swagger:** `RegisterDto` request body, `AuthResponseDto` response, tagged `Auth`

### `POST /auth/login`
- **Auth:** Public
- **Request:**
```json
{ "email": "jane@acme.com", "password": "MinLength8!" }
```
- **Response (200):** same shape as register response
- **Validation:** both fields required
- **Error responses:** 401 invalid credentials (generic message — never reveal whether email exists)
- **Permissions:** none
- **Swagger:** `LoginDto` → `AuthResponseDto`

### `POST /auth/refresh`
- **Auth:** Refresh token in body (not the access-token header)
- **Request:**
```json
{ "refreshToken": "eyJ..." }
```
- **Response (200):**
```json
{ "accessToken": "eyJ...", "refreshToken": "eyJ..." }
```
- **Validation:** token format check
- **Error responses:** 401 if expired/revoked/reused (reuse triggers full session revocation for that user)
- **Permissions:** none beyond valid token
- **Swagger:** `RefreshDto` → `TokenPairDto`

### `POST /auth/logout`
- **Auth:** Bearer required
- **Request:** `{ "refreshToken": "eyJ..." }`
- **Response (204):** no content
- **Validation:** token format
- **Error responses:** 401 if access token invalid
- **Permissions:** self only
- **Swagger:** `LogoutDto`, `@ApiResponse({status: 204})`

### `POST /auth/sso/callback`
- **Auth:** Public (SAML assertion is the credential)
- **Request:** SAML response body (form-encoded `SAMLResponse` per SAML spec, not JSON)
- **Response (200):** same shape as login response
- **Validation:** SAML assertion signature verified against `sso_config.idp_metadata_url`
- **Error responses:** 401 invalid/unsigned assertion; 404 if org has no `sso_config`
- **Permissions:** none beyond valid assertion
- **Swagger:** documented as `consumes: application/x-www-form-urlencoded`, distinct from the JSON convention elsewhere

### `GET /users/me`
- **Auth:** Bearer required
- **Request:** none
- **Response (200):**
```json
{ "id": "usr_01", "email": "jane@acme.com", "role": "owner", "orgId": "org_01", "createdAt": "2026-01-10T00:00:00Z" }
```
- **Validation:** none
- **Error responses:** 401 only
- **Permissions:** self
- **Swagger:** `UserProfileDto`

---

## 3. Organizations

### `POST /organizations/:id/invite`
- **Auth:** Bearer required
- **Request:**
```json
{ "email": "bob@acme.com", "role": "editor" }
```
- **Response (201):**
```json
{ "id": "inv_01", "email": "bob@acme.com", "role": "editor", "status": "pending", "expiresAt": "2026-07-15T00:00:00Z" }
```
- **Validation:** `email` valid; `role` must be one of `admin|editor|viewer` (cannot invite as `owner`)
- **Error responses:** 409 if already a member or already invited and pending; 403 if inviter isn't admin+
- **Permissions:** admin+
- **Swagger:** `InviteDto` → `InviteResponseDto`, `@ApiParam('id')`

### `POST /invites/:token/accept`
- **Auth:** Bearer required (the invited person must have/create an account first via `/auth/register`, then accept)
- **Request:** none (token in path)
- **Response (200):**
```json
{ "orgId": "org_01", "role": "editor" }
```
- **Validation:** token exists, not expired, not already accepted
- **Error responses:** 410 if expired; 409 if already accepted
- **Permissions:** the authenticated user's email must match the invite's email
- **Swagger:** `@ApiParam('token')`

### `PATCH /organizations/:id/members/:userId/role`
- **Auth:** Bearer required
- **Request:**
```json
{ "role": "admin" }
```
- **Response (200):**
```json
{ "userId": "usr_02", "role": "admin" }
```
- **Validation:** `role` one of `admin|editor|viewer`; cannot set/unset `owner` via this endpoint
- **Error responses:** 403 if actor isn't owner; 422 if attempting to demote the last remaining owner
- **Permissions:** owner only
- **Swagger:** `UpdateRoleDto`

### `PATCH /organizations/:id/white-label`
- **Auth:** Bearer required
- **Request:**
```json
{ "logoUrl": "https://cdn.../logo.png", "primaryColor": "#1A73E8" }
```
- **Response (200):** echoes updated config
- **Validation:** `logoUrl` valid URL; `primaryColor` valid hex
- **Error responses:** 403 if org `planTier` isn't `enterprise`
- **Permissions:** owner only, Enterprise plan only
- **Swagger:** `WhiteLabelDto`

---

## 4. Social Accounts

### `GET /social-accounts`
- **Auth:** Bearer required
- **Request:** none (org inferred from token)
- **Response (200):**
```json
{
  "data": [
    { "id": "sa_01", "platform": "instagram", "status": "connected", "externalAccountId": "1789...", "expiresAt": "2026-08-01T00:00:00Z" }
  ]
}
```
- **Validation:** none
- **Error responses:** none beyond standard
- **Permissions:** viewer+ (read-only)
- **Swagger:** `SocialAccountDto[]`

### `POST /social-accounts/:platform/connect`
- **Auth:** Bearer required
- **Request:** none — initiates OAuth redirect; actual token exchange happens on the platform's callback URL, not this body
- **Response (200):**
```json
{ "redirectUrl": "https://api.instagram.com/oauth/authorize?..." }
```
- **Validation:** `:platform` must be one of the 5 supported enum values
- **Error responses:** 400 if platform unsupported; 409 if already connected
- **Permissions:** admin+
- **Swagger:** `@ApiParam('platform', enum: PlatformEnum)`

### `DELETE /social-accounts/:id`
- **Auth:** Bearer required
- **Request:** none
- **Response (204):** no content
- **Validation:** id must belong to caller's org
- **Error responses:** 404 if not found in org; 409 if account has jobs currently `processing` (must wait or force-cancel first)
- **Permissions:** admin+
- **Swagger:** `@ApiResponse({status: 204})`

---

## 5. Content

### `POST /content/assets`
- **Auth:** Bearer required
- **Request:**
```json
{ "type": "image", "canvasJson": { "width": 1080, "height": 1080, "layers": [] }, "templateId": null }
```
- **Response (201):**
```json
{ "id": "ast_01", "type": "image", "approvalStatus": "draft", "createdAt": "2026-07-08T10:00:00Z" }
```
- **Validation:** `type` one of `image|video`; `canvasJson` must match canvas schema (width/height/layers array); `templateId` if present must exist and be visible to org
- **Error responses:** 404 if `templateId` not found
- **Permissions:** editor+
- **Swagger:** `CreateContentAssetDto`

### `PATCH /content/assets/:id`
- **Auth:** Bearer required
- **Request:** partial — typically just `{ "canvasJson": { ... } }` on autosave
- **Response (200):** updated asset
- **Validation:** same canvas schema check; id must belong to caller's org
- **Error responses:** 404; 409 if asset is `pending_approval`/`approved` and org requires approval-lock on edits (configurable)
- **Permissions:** editor+ and (creator or admin+)
- **Swagger:** `UpdateContentAssetDto`

### `GET /content/assets/:id`
- **Auth:** Bearer required
- **Response (200):** full asset including nested `variants` summary
- **Error responses:** 404
- **Permissions:** viewer+
- **Swagger:** `ContentAssetDetailDto`

### `GET /content/assets`
- **Auth:** Bearer required
- **Request:** query params `?page=&limit=&type=&approvalStatus=`
- **Response (200):** paginated list, standard envelope
- **Validation:** query enum values checked
- **Permissions:** viewer+
- **Swagger:** `@ApiQuery` for each filter param

### `POST /content/assets/:id/variants`
- **Auth:** Bearer required
- **Request:**
```json
{ "platforms": ["instagram", "x"] }
```
- **Response (202):**
```json
{ "variants": [ { "id": "var_01", "platform": "instagram", "status": "pending" }, { "id": "var_02", "platform": "x", "status": "pending" } ] }
```
  *(202 Accepted — generation is async; poll `GET /content/assets/:id` or listen for a status webhook)*
- **Validation:** `platforms` non-empty array of supported enum values; asset must have at least one layer
- **Error responses:** 422 if asset's media doesn't meet the minimum spec for the requested platform (e.g., video too short)
- **Permissions:** editor+
- **Swagger:** `GenerateVariantsDto`, documented 202 response explicitly (uncommon status code, needs a note)

### `POST /content/assets/:id/comments`
- **Auth:** Bearer required
- **Request:**
```json
{ "body": "Can we make the CTA button bigger?" }
```
- **Response (201):**
```json
{ "id": "cmt_01", "assetId": "ast_01", "userId": "usr_02", "body": "Can we make the CTA button bigger?", "createdAt": "2026-07-08T10:05:00Z" }
```
- **Validation:** `body` 1–2000 chars, non-empty after trim
- **Error responses:** 404 if asset not found
- **Permissions:** viewer+ (viewers can comment, not edit)
- **Swagger:** `CreateCommentDto`

### `PATCH /content/assets/:id/approval`
- **Auth:** Bearer required
- **Request:**
```json
{ "status": "approved", "note": "Looks good" }
```
- **Response (200):** updated asset with new `approvalStatus`
- **Validation:** `status` one of `pending_approval|approved|rejected`; cannot self-approve own asset if org policy requires separation of duties (configurable)
- **Error responses:** 403 if actor is editor (approval requires admin+); 422 if transition isn't valid from current state (e.g., can't approve a `draft` directly — must be `pending_approval` first)
- **Permissions:** admin+
- **Swagger:** `UpdateApprovalDto`

---

## 6. Publishing

### `POST /publish/now`
- **Auth:** Bearer required
- **Request:**
```json
{ "variantId": "var_01", "socialAccountId": "sa_01" }
```
- **Response (202):**
```json
{ "jobId": "job_01", "status": "queued" }
```
- **Validation:** variant must be `status: ready`; social account must be `status: connected` and match the variant's platform
- **Error responses:** 422 if asset not approved (org requires approval) or variant not ready; 429 if platform rate limit already exhausted for this account
- **Permissions:** editor+
- **Swagger:** `PublishNowDto`

### `POST /publish/schedule`
- **Auth:** Bearer required
- **Request:**
```json
{ "variantId": "var_01", "socialAccountId": "sa_01", "scheduledAt": "2026-07-10T14:00:00Z" }
```
- **Response (201):**
```json
{ "jobId": "job_02", "status": "scheduled", "scheduledAt": "2026-07-10T14:00:00Z" }
```
- **Validation:** `scheduledAt` must be in the future; same variant/account checks as `/publish/now`
- **Error responses:** same as above, plus 400 if `scheduledAt` is in the past
- **Permissions:** editor+
- **Swagger:** `SchedulePublishDto`

### `GET /publish/jobs/:id`
- **Auth:** Bearer required
- **Response (200):**
```json
{ "id": "job_01", "status": "published", "attemptCount": 1, "scheduledAt": null, "lastError": null }
```
- **Error responses:** 404
- **Permissions:** viewer+
- **Swagger:** `PublishJobDto`

### `GET /publish/jobs`
- **Auth:** Bearer required
- **Request:** query `?status=&page=&limit=`
- **Response (200):** paginated list
- **Permissions:** viewer+
- **Swagger:** `@ApiQuery('status', enum: PublishJobStatus)`

### `DELETE /publish/jobs/:id`
- **Auth:** Bearer required
- **Response (200):**
```json
{ "id": "job_02", "status": "cancelled" }
```
- **Validation:** only jobs in `queued` or `scheduled` status can be cancelled
- **Error responses:** 409 if job already `processing` or terminal (`published|failed|cancelled`)
- **Permissions:** editor+
- **Swagger:** documented as cancel semantics, not a hard delete — table row is retained

---

## 7. AI

### `POST /ai/caption`
- **Auth:** Bearer required
- **Request:**
```json
{ "assetId": "ast_01", "tone": "casual" }
```
- **Response (200):**
```json
{ "caption": "Sunday reset, minimal effort maximum vibe ✨" }
```
- **Validation:** `assetId` exists in org; `tone` optional, one of a fixed enum if provided
- **Error responses:** 429 quota exceeded, includes `resetAt` in body; 422 if asset has no visual content yet to caption
- **Permissions:** editor+
- **Swagger:** `GenerateCaptionDto`, `@ApiResponse({status: 429, description: 'Quota exceeded, see resetAt'})`

### `POST /ai/hashtags`
- **Auth:** Bearer required
- **Request:** `{ "assetId": "ast_01", "count": 8 }`
- **Response (200):** `{ "hashtags": ["#sundayreset", "#minimalism", ...] }`
- **Validation:** `count` 1–30
- **Error responses:** 429 quota
- **Permissions:** editor+
- **Swagger:** `GenerateHashtagsDto`

### `POST /ai/tone`
- **Auth:** Bearer required
- **Request:** `{ "text": "Check out our new product", "targetTone": "professional" }`
- **Response (200):** `{ "text": "We're pleased to introduce our latest product." }`
- **Validation:** `text` 1–2000 chars; `targetTone` from fixed enum
- **Error responses:** 429 quota
- **Permissions:** editor+
- **Swagger:** `ToneConversionDto`

### `POST /ai/viral-score`
- **Auth:** Bearer required
- **Request:** `{ "variantId": "var_01" }`
- **Response (200):** `{ "score": 72, "factors": ["strong hook", "trending format"] }`
- **Validation:** variant must be `ready`
- **Error responses:** 422 if variant not ready; 429 quota
- **Permissions:** editor+
- **Swagger:** `ViralScoreDto`

### `GET /ai/best-time`
- **Auth:** Bearer required
- **Request:** query `?platform=instagram`
- **Response (200):**
```json
{ "recommendations": [ { "dayOfWeek": "Tuesday", "hour": 18, "confidence": 0.81 } ] }
```
- **Validation:** `platform` required, must be connected for this org (needs historical `post_metric` data)
- **Error responses:** 422 if insufficient historical data (fewer than N published posts) — returns a message explaining why, not an empty array silently
- **Permissions:** viewer+
- **Swagger:** `@ApiQuery('platform', enum: PlatformEnum)`

---

## 8. Analytics (REST fallback — primary interface is GraphQL)

### `GET /analytics/overview`
- **Auth:** Bearer required
- **Request:** query `?from=2026-06-01&to=2026-07-01&platform=` (platform optional, all if omitted)
- **Response (200):**
```json
{
  "totals": { "impressions": 48200, "engagementRate": 0.042, "followerGrowth": 312 },
  "byPlatform": [
    { "platform": "instagram", "impressions": 30000, "engagementRate": 0.051 }
  ]
}
```
- **Validation:** `from`/`to` valid ISO dates, `from` before `to`, max 1-year range
- **Error responses:** 400 if range invalid/too large
- **Permissions:** viewer+
- **Swagger:** `AnalyticsOverviewQueryDto` → `AnalyticsOverviewDto`

### `GET /analytics/posts/:variantId`
- **Auth:** Bearer required
- **Response (200):** time series of `post_metric` rows for that variant
- **Error responses:** 404
- **Permissions:** viewer+
- **Swagger:** `PostMetricSeriesDto`

---

## 9. Templates

### `GET /templates`
- **Auth:** Bearer required
- **Request:** query `?category=&page=&limit=`
- **Response (200):** paginated list of org-owned templates
- **Permissions:** viewer+
- **Swagger:** `@ApiQuery('category')`

### `POST /templates`
- **Auth:** Bearer required
- **Request:** `{ "category": "instagram-story", "canvasJson": { ... } }`
- **Response (201):** created template
- **Validation:** same canvas schema check as content assets
- **Permissions:** editor+
- **Swagger:** `CreateTemplateDto`

### `GET /templates/marketplace`
- **Auth:** Bearer required
- **Request:** query `?category=&search=&page=&limit=`
- **Response (200):** paginated list of `isPublic: true` templates across all orgs
- **Permissions:** viewer+ (read-only browse)
- **Swagger:** `@ApiQuery('search')`

### `POST /templates/:id/publish`
- **Auth:** Bearer required
- **Request:** none
- **Response (200):** `{ "id": "tpl_01", "isPublic": true }`
- **Validation:** template must belong to caller's org
- **Error responses:** 403 if not owned by caller's org
- **Permissions:** admin+
- **Swagger:** documented as a state-toggle action, not a resource creation

### `POST /templates/:id/clone`
- **Auth:** Bearer required
- **Request:** none
- **Response (201):** new `ContentAsset` created from the template, in caller's org
- **Validation:** template must be `isPublic: true` or owned by caller's org
- **Error responses:** 403 if template is private and not owned by caller
- **Permissions:** editor+
- **Swagger:** `@ApiResponse({status: 201, type: ContentAssetDto})`

---

## 10. Brand Kits

### `GET /brand-kits/:orgId`
- **Auth:** Bearer required
- **Response (200):**
```json
{ "orgId": "org_01", "colors": { "primary": "#1A73E8" }, "fonts": { "heading": "Inter" }, "logoUrl": "https://cdn.../logo.png" }
```
- **Validation:** `:orgId` must equal caller's own org
- **Error responses:** 403 if requesting another org's kit; 404 if none exists yet
- **Permissions:** viewer+
- **Swagger:** `BrandKitDto`

### `PATCH /brand-kits/:orgId`
- **Auth:** Bearer required
- **Request:** partial update, e.g. `{ "colors": { "primary": "#0F9D58" } }`
- **Response (200):** updated kit
- **Validation:** hex color format checks; font names against an allowed Google Fonts list
- **Permissions:** admin+
- **Swagger:** `UpdateBrandKitDto`

---

## 11. Audit Logs

### `GET /audit-logs`
- **Auth:** Bearer required
- **Request:** query `?from=&to=&userId=&action=&page=&limit=`
- **Response (200):** paginated list
```json
{ "data": [ { "id": "aud_01", "userId": "usr_02", "action": "content.publish", "resourceType": "publish_job", "resourceId": "job_01", "timestamp": "2026-07-08T10:10:00Z" } ], "meta": { "page": 1, "limit": 20, "total": 512, "totalPages": 26 } }
```
- **Validation:** date range max 1 year; `action` against known action-type enum
- **Error responses:** 403 if org plan doesn't include audit log access (Enterprise feature)
- **Permissions:** admin+
- **Swagger:** `@ApiQuery` per filter, tagged `AuditLogs`

---

## 12. Swagger Documentation Structure (Project-Wide)

```
GET /api/docs           → Swagger UI (disabled in production, enabled in staging/local)
GET /api/docs-json       → Raw OpenAPI JSON (feeds packages/api-contracts/openapi.yaml generation)
```

- **Tag grouping:** one `@ApiTags()` per module, matching sections 2–11 above exactly (`Auth`, `Organizations`, `SocialAccounts`, `Content`, `Publishing`, `AI`, `Analytics`, `Templates`, `BrandKits`, `AuditLogs`, `Health`).
- **DTO-driven schema:** every request/response shape documented here has a corresponding DTO class using `class-validator` decorators (`@IsEmail()`, `@MinLength()`, etc.) and `@ApiProperty()` — Swagger's generated schema is therefore always the *actual* enforced validation, never hand-written documentation that can drift from behavior.
- **Global response documentation:** the standard error envelope (§0) and the common error codes table are registered once via a global `@ApiExtraModels()` + response interceptor, not repeated per-endpoint in code — individual endpoints only document the status codes that mean something *specific* to them (e.g., 422 on `/publish/now` meaning "asset not approved," not just a generic 422).
- **Auth documentation:** `@ApiBearerAuth('access-token')` applied at controller level for all authenticated modules, with a global security scheme named `access-token` registered once in `main.ts`'s Swagger setup — so Swagger UI's "Authorize" button works across every tagged group in one step.
- **Versioning:** all routes prefixed `/v1` via a global route prefix, so `/v2` can be introduced later without breaking existing integrations — reflected as `servers: [{ url: '/v1' }]` in the generated spec.
- **Contract sync check:** as noted in the folder structure doc, `contract-drift-check.yml` in CI fails the build if the live generated `docs-json` output doesn't match the checked-in `packages/api-contracts/openapi.yaml` — Swagger docs are never allowed to silently go stale relative to the actual DTOs.
