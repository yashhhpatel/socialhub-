# Meta App Review Runbook (Phase 16)

How to take the SocialHub Meta app (Facebook, Instagram, Threads) from
development mode to a live, review-approved app that can publish for any user.

This is a **manual, human-driven** process in the
[Meta Developer Dashboard](https://developers.facebook.com/apps/) — the code in
this repo (OAuth flows, deauthorize and data-deletion callbacks, encrypted token
storage, Privacy Policy and Terms) exists to satisfy the requirements below, but
the submission itself must be done by a person with admin access to the app and
the associated Business portfolio.

---

## 0. Prerequisites

| Item | Where | Notes |
| --- | --- | --- |
| Business app "SocialHub Publisher" | Meta dashboard | App ID `1543082973766535` (Facebook) |
| Instagram app | Meta dashboard | Instagram app ID `1571389868028549` |
| Business portfolio | business.facebook.com | Required for Pages permissions |
| Public HTTPS URL | ngrok (dev) / real domain (prod) | Callbacks + redirect URIs must be HTTPS |
| Privacy Policy URL | `/#/privacy` | Content in `frontend/.../info_page_screen.dart` |
| Terms of Service URL | `/#/terms` | Same file |
| Data Deletion callback | `POST /social-accounts/:platform/data-deletion` | Implemented Phase 16 |
| Deauthorize callback | `POST /social-accounts/:platform/deauthorize` | Implemented Phase 16 |

> **Dev vs prod URLs:** In development the callbacks and redirect URIs point at
> the current ngrok domain (e.g.
> `https://clarinet-decathlon-liquefy.ngrok-free.dev`). For production, replace
> every ngrok URL below with the real deployed domain. ngrok free domains are
> persistent per account but change if you recreate the tunnel — re-register the
> URLs in the dashboard if the domain changes.

---

## 1. Register the callback URLs

Each Meta app that requests permissions **must** have a deauthorize callback and
a data-deletion callback registered, or App Review is rejected.

### Facebook app
1. Dashboard → **App settings → Basic**.
2. Scroll to the product / **Facebook Login** settings.
3. Set:
   - **Deauthorize Callback URL:**
     `https://<domain>/social-accounts/facebook/deauthorize`
   - **Data Deletion Request URL:**
     `https://<domain>/social-accounts/facebook/data-deletion`
4. Under **Facebook Login → Settings → Valid OAuth Redirect URIs**, confirm:
   `https://<domain>/social-accounts/facebook/callback`
   (In dev, Facebook also allows `http://localhost:3000/...` automatically.)

### Instagram app
1. Dashboard → **Instagram → API setup with Instagram login** (or **Basic
   Display**, whichever product is in use — this app uses *Instagram API with
   Instagram Login*).
2. Set:
   - **Deauthorize Callback URL:**
     `https://<domain>/social-accounts/instagram/deauthorize`
   - **Data Deletion Request URL:**
     `https://<domain>/social-accounts/instagram/data-deletion`
3. **Valid OAuth Redirect URIs:**
   `https://<domain>/social-accounts/instagram/callback`
   (Instagram rejects `http://localhost` — HTTPS is mandatory even in dev.)

### Threads app (when enabled)
- Same three URLs with `/threads/` in place of `/facebook/`.

> **How to test a callback:** Meta's dashboard has a "Send a test request" button
> next to the Data Deletion URL. It posts a signed `signed_request` body; a
> correct response is HTTP 200 with JSON `{ "url": "...", "confirmation_code":
> "..." }`. The deauthorize callback returns `{ "success": true }`. Both verify
> the HMAC-SHA256 signature against the app secret before doing anything — a
> forged request gets a 400.

---

## 2. Add and configure the Privacy Policy & Terms URLs

Dashboard → **App settings → Basic**:
- **Privacy Policy URL:** `https://<frontend-domain>/#/privacy`
- **Terms of Service URL:** `https://<frontend-domain>/#/terms`
- **User Data Deletion:** choose **Data Deletion Callback URL** (registered in
  step 1), not the "instructions" option — we support programmatic deletion.

The Privacy Policy must explicitly state what platform data is collected and how
a user deletes it. Ours does (see the "Data from connected platforms" and
"Removing your data" sections) — keep them in sync with any permission changes.

---

## 3. Business Verification

Pages/Instagram publishing permissions require the Business portfolio to be
verified.

1. business.facebook.com → **Business settings → Security Center**.
2. Start **Business Verification**: legal business name, address, phone, and a
   verification document / domain.
3. Verify the domain (add the Meta domain-verification `<meta>` tag or DNS TXT
   record to the frontend domain).

This can take a few business days — start it early; App Review can't complete
without it.

---

## 4. Permissions to request, and their justifications

For each permission, App Review wants: (a) why the app needs it, and (b) a
screencast showing a real user granting it and the resulting feature working.

| Permission | Platform | Why SocialHub needs it |
| --- | --- | --- |
| `public_profile` | Facebook | Identify the connecting user (granted by default). |
| `pages_show_list` | Facebook | List the Pages the user administers so they can pick which Page to publish as. |
| `pages_read_engagement` | Facebook | Read Page metadata/engagement to show the connected Page and its analytics. |
| `pages_manage_posts` | Facebook | Create the scheduled posts on the user's Page — the core publishing feature. |
| `instagram_business_basic` | Instagram | Read the connected Instagram professional account's profile/media to confirm the connection and show it. |
| `instagram_business_content_publish` | Instagram | Publish the images/captions the user schedules to their Instagram professional account. |
| `threads_basic` | Threads | Read the connected Threads profile. |
| `threads_content_publish` | Threads | Publish scheduled posts to Threads. |

Keep the justification text focused on the **user-visible feature** each
permission powers — reviewers reject vague "we need it for the app to work"
answers.

---

## 5. Screencast checklist (per permission)

Record one continuous screencast per permission that shows:
1. A fresh user logging in to SocialHub.
2. Going to **Settings → Connected accounts** and clicking **Connect** for the
   platform.
3. The Meta consent screen appearing, showing the exact permission being
   reviewed, and the user granting it.
4. Returning to SocialHub with the account now shown as **Connected**.
5. The feature the permission enables actually working — e.g. composing a post
   in **Content**, scheduling it, and it appearing as published on the real
   Page/profile.
6. (For `*_content_publish`) the resulting post visible on the actual platform.

Use a **real** test account you control; reviewers replicate the flow, so it
must work end-to-end against production (or the review-mode) credentials, not the
dev stub.

---

## 6. Submit for review

1. Dashboard → **App Review → Permissions and Features**.
2. Request each permission from the table above; attach its justification and
   screencast.
3. Provide **test user credentials** (a SocialHub account with a connected test
   Page/IG account) in the reviewer notes, plus step-by-step instructions
   mirroring the screencast.
4. Confirm the app's **Privacy Policy**, **Terms**, **data-deletion**, and
   **deauthorize** URLs are all live and reachable (reviewers check them).
5. Switch the app **Mode** to **Live** once approved.

---

## 7. Remaining manual steps checklist

Things only a human with dashboard/Business access can do — the code is ready:

- [ ] Register deauthorize + data-deletion callback URLs (step 1) for Facebook,
      Instagram, (Threads).
- [ ] Set Privacy Policy + Terms + Data Deletion Callback in App settings (step 2).
- [ ] Complete Business Verification + domain verification (step 3).
- [ ] Record screencasts for each permission (step 5).
- [ ] Submit permissions for App Review with justifications + test creds (step 6).
- [ ] After approval, flip the app to Live mode and swap ngrok URLs for the
      production domain in every place listed above.

---

## Reference: how the callbacks authenticate

Meta signs each callback body as `signed_request` =
`<base64url HMAC-SHA256 signature>.<base64url JSON payload>`, keyed on the app
secret. `backend/src/common/crypto/meta-signed-request.util.ts`
(`parseMetaSignedRequest`) recomputes the HMAC with a constant-time compare and
rejects anything whose signature, algorithm (`HMAC-SHA256`), or `user_id` doesn't
check out. The controller resolves the per-platform secret
(`FACEBOOK_APP_SECRET` / `INSTAGRAM_CLIENT_SECRET` / `THREADS_CLIENT_SECRET`),
verifies the request, then:
- **deauthorize** → deletes every `SocialAccount` for that platform whose
  `externalUserId` **or** `externalAccountId` matches the payload `user_id`.
- **data-deletion** → same purge, records a `DataDeletionRequest` row with a
  random confirmation code, and returns `{ url, confirmation_code }` where `url`
  is the public status page `GET /social-accounts/data-deletion/status?code=...`.
