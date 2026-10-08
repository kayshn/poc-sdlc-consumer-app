# Spec: Expiring links
Intent: .sdlc/intent/000-expiring-links.md. Skills applied: write-spec, secure-api-review. Status: approved (auto)

## Summary
`POST /links` gains an optional lifetime in seconds. A link created with a lifetime stops resolving
once that time has passed: `GET /{code}` then returns the same 404 as a code that never existed.
Links created without a lifetime behave as they do today and never expire. Expiry is evaluated
lazily on read (no scheduler), and expired links stay in `store.links` so their codes are never
reissued. The owner still sees expired links in `GET /links`, marked as expired.

## Requirements
1. `POST /links` accepts an optional integer field `expires_in_seconds`. Omitting it, or sending
   `null`, creates a link that never expires; the response and behaviour match today's, apart from
   the additive fields in R9.
2. `expires_in_seconds` must satisfy `1 <= value <= 31_536_000` (365 days). Zero, negative, or
   above-maximum values return 422 and create no link and no audit entry. Non-integer values
   (strings, floats with a fractional part, booleans) return 422.
3. The request body keeps `extra="forbid"`; unknown fields still return 422.
4. For a link with a lifetime, `expires_at = created_at + expires_in_seconds`, computed once from
   the server's UTC clock at creation and stored on the link.
5. `GET /{code}` for a link where `now >= expires_at` returns **404** with detail `"no such link"`,
   byte-for-byte identical in status, body and headers to a code that never existed. It must not
   return 410 or any expiry-specific text.
6. `GET /{code}` for a link with `expires_at is None`, or `now < expires_at`, redirects exactly as
   today (307, same `Location`).
7. A 307 redirect issued for a link that has an `expires_at` carries `Cache-Control: no-store` so
   clients and intermediaries cannot keep resolving it after expiry. Redirects for links without a
   lifetime are unchanged.
8. Expired links are never removed from `store.links` by expiry, and no background task or timer is
   added. Only `DELETE /links/{code}` removes a link.
9. `LinkOut` gains `expires_at: datetime | None` and `expired: bool`. `GET /links` returns all of the
   caller's links, including expired ones, with `expired` true once `now >= expires_at`. `expires_at`
   and `expired` are only ever returned to the owner (`POST /links`, `GET /links`).
10. `GET /links` never returns another user's links, expired or not.
11. `DELETE /links/{code}` works on the owner's expired link (204, audited as `link.delete`). For
    another user's link, expired or not, or an unknown code, it returns 404.
12. Expiry creates no audit entry (it is not a caller action). `link.create` and `link.delete` audit
    entries are unchanged and contain the code only: no target and no lifetime.
13. A target URL appears in no log line, error message, or audit entry added by this change,
    including the 422 for an invalid lifetime.
14. Existing tests pass unmodified.
15. Tests cover: omit/null lifetime; valid lifetime; 0, -1, max+1, string and float values (422);
    unknown field (422); follow before expiry (307) and at/after expiry (404, identical to unknown
    code); expired link visible and marked in `GET /links`; other user cannot see it; owner can
    delete it; `Cache-Control` present only on expiring links; audit has no target. Tests control
    the clock (e.g. monkeypatching a single `now()` helper) rather than sleeping.

## Design
**Data.** `Link` gains `expires_at: datetime | None = None` (defaulted, so existing constructions
keep working). `Store` is unchanged. One small helper (e.g. `is_expired(link, now)`) is the single
place that decides expiry, used by `follow` and by `LinkOut` population. The clock is read through
one function so tests can pin it.

**Request.** `CreateLink` adds `expires_in_seconds: int | None = Field(default=None, ge=1,
le=MAX_LIFETIME_SECONDS)` in strict integer mode so that booleans and strings are rejected.
`MAX_LIFETIME_SECONDS = 31_536_000` is a module constant.

**Response.** `LinkOut` adds `expires_at` and `expired`. `expired` is derived at response time, not
stored. Handlers still return `LinkOut` (via `response_model`), never `Link`, so `owner` stays
internal.

**Routes.** No new routes, so the `GET /{code}` catch-all ordering is not affected.
- `POST /links`: validate target as today, then compute `expires_at`, store, and call
  `store.record(user, "link.create", code)` as today.
- `GET /links`: same owner filter; no expiry filtering.
- `DELETE /links/{code}`: unchanged logic (owner filter, 404 otherwise); it already works on
  expired links.
- `GET /{code}`: look up; if missing **or** expired, raise the same `HTTPException(404, "no such
  link")`. Otherwise return the redirect, adding `Cache-Control: no-store` when `expires_at` is set.
  The existing `urlparse`/`ALLOWED_SCHEMES` validation at creation is unchanged; targets are
  immutable, so nothing reaches `Location` unvalidated.

**Open questions from the intent, resolved here:** 404 vs 410: 404 (R5). Listing expired links:
yes, marked (R9). Duration vs timestamp: duration in seconds, max 365 days, omitted = never
(R1, R2). Zero/negative: 422 (R2). Removal vs retention: retained (R8).

## Policy check
- secure-api-review 1, Authentication: satisfied. `POST /links`, `GET /links`, `DELETE /links/{code}` keep
  `Depends(require_user)`. No new anonymous route; `GET /{code}` was already anonymous.
- secure-api-review 2, Input validation: satisfied. The new field lives on `CreateLink` with `extra="forbid"`
  and bounded, strict typing.
- secure-api-review 3, Redirect targets: satisfied. Validated at creation with `urlparse`/`ALLOWED_SCHEMES`/
  `netloc`; unchanged and not editable afterwards.
- secure-api-review 4, Audit: satisfied. No new state-changing route; existing calls pass the code only.
  Expiry is not a state change by a caller and is not audited (see concern 3).
- secure-api-review 5, Ownership: satisfied. All owner-scoped paths keep `link.owner == user`, with 404 for
  others'. Expiry fields are returned only to the owner.
- secure-api-review 6, Codes are secrets: satisfied, with a dependency on R8. Codes remain
  `secrets.token_urlsafe`; retention means a held code is never reissued.
- secure-api-review 7, Data classification: satisfied. `LinkOut` only; target stays out of logs, errors and
  audit.
- Expiry must not be inferable from the code alone (intent constraint): satisfied by R5 (an
  expired link is indistinguishable from an unknown code), at the cost of concern 1.

## Areas of concern
1. **Truthfulness vs. non-disclosure (404 vs 410).** The intent notes that 410 is more accurate but
   confirms to an unauthenticated holder of a code that it once existed. Policy (5 and the intent's
   own constraint) wins, so this spec chooses 404. Consequence: a legitimate recipient cannot tell
   "expired" from "mistyped or deleted". This cannot be reconciled with 410; it needs the product
   owner to accept it.
2. **Unbounded memory growth.** The intent forbids background cleanup and the code-reuse concern
   requires retaining expired links, so `store.links` only grows. Acceptable for an in-memory PoC
   that resets on restart, but it is a real limit if the service is kept running. No policy-compliant
   fix exists without a new decision (e.g. a tombstone set that stores codes only, still unbounded).
3. **Expiry is not audited.** Lazy evaluation means no event occurs at expiry time, so the audit
   trail cannot show when a link stopped working; it can only be derived from `link.create` plus
   the stored `expires_at`. Raise with the policy owner if an explicit expiry event is required.
4. **"No change to existing calls" vs. response shape.** `LinkOut` gains `expires_at`/`expired`
   for every link, so existing JSON responses are not byte-identical (additive; `null`/`false` for
   non-expiring links). Strict clients that reject unknown fields would notice. Behaviour is
   unchanged; the response schema is not.
5. **Cache-Control on redirects (R7)** is an addition the intent did not ask for. Without it, a
   cached 307 can outlive the link. It affects only expiring links.
6. **Timing side channel.** Expired and unknown codes take the same path and return identical
   responses, but this spec does not claim constant-time behaviour.
7. **Clock dependence.** Expiry follows the server clock; skew or clock adjustment moves expiry. No
   monotonic guarantee.
8. **Code collision.** `create_link` does not check for an existing code before inserting; with
   retained expired links a (very unlikely) collision would overwrite one. Pre-existing, left
   unchanged here, but noted because R8 makes retention load-bearing.

## Open questions carried forward
- Is the 365-day maximum right, and should omission ever default to a finite lifetime? This spec
  chose "omitted = never" to satisfy the intent's no-behaviour-change constraint.
- Should the owner be allowed to see expiry state in `GET /links`? This spec assumes yes (R9);
  the product owner should confirm.
- Concerns 1 to 3 need a decision from the product owner with the policy owner before the plan
  is approved.
