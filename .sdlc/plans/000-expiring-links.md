# Plan: Expiring links (from .sdlc/specs/000-expiring-links.md)
Accepted by: kayshn.

## Files that change
- `src/app/main.py`: `MAX_TTL_SECONDS`; `Link.expires_at`, `Link.is_expired(now)`, `Link.expired` property; `CreateLink.ttl_seconds`; `LinkOut.expires_at` and `expired`; `create_link` and `follow`.
- `tests/test_main.py`: tests for R1-R11, R13, R14.
- No change to `.github/workflows/`, `.sdlc/invariant.txt` or dependencies.

## Order of work
1. Add the plan (this file).
2. Add `Link.expires_at` and `Link.is_expired(now)`, the single expiry helper (R13).
3. Choose the mechanism for `expired` (the spec left it to the plan): a read-only `Link.expired` property that calls `is_expired(datetime.now(UTC))`. `LinkOut` declares `expired: bool`, and FastAPI's `response_model` reads it from the dataclass at serialisation time. This avoids `computed_field` and keeps `Link` out of responses.
4. Add `ttl_seconds` (`StrictInt | None`, `ge=1`, `le=MAX_TTL_SECONDS`) to `CreateLink`; compute `expires_at` in `create_link`.
5. In `follow`, fold the expiry check into the existing `link is None` branch (same 404 and body).
6. Tests.

## Risks
- Additive `LinkOut` fields (spec concern 2); product owner decision pending.
- `MAX_TTL_SECONDS` of 365 days has no policy source.
- Retained expired links grow memory (spec concern 3).
- `StrictInt` must reject bool, float and str; covered by tests.
- `delete_link` and `list_links` are deliberately unchanged.

## Proof
- `make lint` and `make test`.
- Tests: a no-ttl link is unchanged; a ttl link redirects before expiry; the `is_expired` boundary (`now == expires_at` is expired) without sleeping; an expired follow is byte-identical to an unknown code; the owner's list marks `expired`; non-owner delete is 404 before and after expiry; the owner can delete an expired link (204, audited); invalid ttl values give 422 with no link and no audit entry; the audit holds no ttl or target.
