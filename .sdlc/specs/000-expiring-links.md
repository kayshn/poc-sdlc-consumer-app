# Spec: Expiring links
Intent: .sdlc/intent/000-expiring-links.md. Skills applied: write-spec, secure-api-review. Status: approved (auto)

## Summary
`POST /links` accepts an optional lifetime in seconds. Once it has elapsed, `GET /{code}` answers exactly as it does for a code that never existed (404). Expiry is evaluated lazily when a link is read, so there is no scheduler or cleanup. Expired links stay in `store.links`, so their codes are never reissued, and remain visible, marked as expired, to their owner. Requests without a lifetime behave as they do today.

## Requirements
1. `POST /links` accepts an optional `ttl_seconds` field: a strict integer, `1 <= ttl_seconds <= MAX_TTL_SECONDS`. `MAX_TTL_SECONDS` is 31,536,000 (365 days).
2. Omitting `ttl_seconds` (or sending `null`) creates a link that never expires. The response and all later behaviour for it are identical to today, except for the additive fields in R9.
3. `ttl_seconds` of 0, a negative number, a value above the maximum, a float, a string or a boolean is rejected with 422. No link is stored and no audit entry is written.
4. `CreateLink` keeps `extra="forbid"`: unknown fields still produce 422.
5. A link with a lifetime stores `expires_at = created_at + ttl_seconds` (UTC). A link is expired when `now >= expires_at`.
6. `GET /{code}` for an expired link returns 404 with status, body (`{"detail": "no such link"}`) and headers identical to a code that never existed. No `Location` header is set.
7. `GET /{code}` for a link that has not expired redirects with 307 exactly as today, and the target is still validated against `ALLOWED_SCHEMES`.
8. Expired links are not removed from `store.links`, so a code, once issued, is never reissued while the process lives. No background task is added.
9. `LinkOut` gains `expires_at: datetime | None` and `expired: bool`. Both are returned only to the authenticated owner (create and list responses); `owner` is still never serialised.
10. `GET /links` lists the caller's own links, including expired ones, with `expired=true` on those past expiry. It never lists another user's links.
11. `DELETE /links/{code}` works for the owner on an expired link (204, audited as `link.delete` with the code). It returns 404 for a non-owner whether or not the link has expired.
12. `POST /links` still audits `link.create` with the code only. The lifetime is not recorded in the audit and the target never appears in any log line, error message or audit entry.
13. Expiry decisions use a single helper that takes `now` as an argument, so tests can check the boundary (`now == expires_at` is expired) without sleeping.
14. Tests cover R1–R11, including:
    - an expired link and an unknown code return byte-identical 404 responses;
    - another user's link is 404 on delete, both before and after expiry;
    - a request with no lifetime is unchanged.

## Design
**Data.** `Link` gains `expires_at: datetime | None = None`. A default keeps existing constructors valid. No new storage.

**Request.** `CreateLink` gains `ttl_seconds: StrictInt | None = Field(default=None, ge=1, le=MAX_TTL_SECONDS)`. `StrictInt` makes pydantic reject bools, floats and strings rather than coercing them.

**Response.** `LinkOut` gains `expires_at` and `expired`. `expired` is computed at serialisation time from `expires_at` and the current time, for example through a `computed_field` on `LinkOut`. Because the routes return the `Link` dataclass through `response_model`, the implementer must make `expired` derivable from the dataclass, for example with a `Link.is_expired(now)` method or property. The plan should pick the mechanism.

**Routes.** No new routes, so the `GET /{code}` catch-all ordering concern does not apply.
- `create_link`: compute `expires_at` when `ttl_seconds` is set.
- `follow`: treat `link is None or link.is_expired(now)` as the same single branch. It raises the same `HTTPException(404, "no such link")`, so nothing distinguishes the two cases by body, status or headers. This also avoids a deliberate timing difference.
- `list_links`: no filter change beyond the ownership filter.
- `delete_link`: unchanged. An expired link is still deletable by its owner.

**Questions answered from the intent:**
| Open question | Decision |
|---|---|
| 404 or 410 | 404. A 410 would tell an anonymous caller the code once existed. This matches the "404, not 403" convention. |
| List expired links? | Yes, to the owner only, marked `expired=true` with `expires_at`. |
| Duration or timestamp; maximum; default | Duration in seconds (`ttl_seconds`). It avoids client clock skew and parsing of absolute times. Maximum 365 days. No default, so omitting it means never. |
| Zero or negative | 422. Creating an already-expired link has no valid use. |
| Remove expired links? | Retain. A held code is never silently reassigned. |

## High-level design
No architectural change.

Two fields on an existing record in the existing in-process store: no deployable unit, datastore,
external service or trust boundary moves. (Backfilled when G6 was adopted; the spec predates it.)

## Policy check
- secure-api-review 1, Authentication: satisfied. `POST /links`, `GET /links` and `DELETE` keep `Depends(require_user)`. No anonymous route is added. `GET /{code}` stays anonymous as today.
- secure-api-review 2, Input validation: satisfied. The new field is on a `BaseModel` with `extra="forbid"` and strict, bounded typing.
- secure-api-review 3, Redirect targets: satisfied. The existing `urlparse` check at create is unchanged. Expiry only adds a path that does not redirect.
- secure-api-review 4, Audit: satisfied. No new state-changing route. Create and delete still record the code only.
- secure-api-review 5, Ownership: satisfied. List and delete filter on owner. Expiry state is exposed only to the owner. Non-owners get 404.
- secure-api-review 6, Codes are secrets: satisfied. Code generation is unchanged. Retention prevents reissue.
- secure-api-review 7, Data classification: satisfied. The target is never logged or audited. `LinkOut` is still returned, never `Link`. The new fields are not sensitive for the owner.
- CLAUDE.md "storage in-memory, no cleanup": satisfied, with the memory concern below.
- CLAUDE.md "must not change existing behaviour": concern. See Areas of concern 2.

## Areas of concern
1. **Truthfulness vs non-disclosure (404 vs 410).** The intent notes 410 is more accurate, but the project's policy is not to confirm a code's existence to unauthorised callers. These cannot both hold. The spec chooses 404 and gives up the more accurate status. The product owner should confirm that.
2. **Additive response fields.** The intent says existing calls must behave exactly as now, but R9 adds `expires_at` and `expired` to every `LinkOut`, including for links with no lifetime. This is backwards-compatible for tolerant JSON clients, and a strict client that rejects unknown fields would break. The alternative is to expose these fields only for links with a lifetime, which makes the response shape inconsistent. The product owner should decide.
3. **Retention vs unbounded memory.** Retaining expired links (to keep codes from being reissued, and to list them) means `store.links` never shrinks without an explicit `DELETE`. The intent also forbids background cleanup. With in-memory storage the growth is bounded by the process lifetime, which is acceptable for a PoC, but it would need a retention policy before production use.
4. **Expiry is not enforced on the owner's own view.** An owner can distinguish expired links, which is intended. Nothing else is inferable by an unauthenticated caller, provided the 404 stays byte-identical (R6, R14). A future change to the 404 body or headers for one case would break this guarantee, so the test in R14 is the control.
5. **Delete frees a code.** After an owner deletes an expired link the code is removable from the store and could in theory be regenerated. With 64-bit random codes the probability is negligible, so it is accepted and noted rather than mitigated.
6. **Clock source.** Expiry relies on the server's wall clock (`datetime.now(UTC)`). A clock step could expire links early or revive them. This is accepted for the PoC.

No workflow or `.github/workflows/` change is needed. No `.sdlc/invariant.txt` file is touched. No new dependency is needed.

## Open questions carried forward
- The `MAX_TTL_SECONDS` value (365 days) is a proposal with no policy source. The product owner should confirm or change it.
- The mechanism for computing `expired` in `LinkOut` (R9) is left to the plan.
- Whether `expired` should be dropped from `LinkOut` in favour of clients comparing `expires_at` is left to the product owner (see concern 2).
