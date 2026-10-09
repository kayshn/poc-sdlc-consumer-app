# Plan: link follow count (from .sdlc/specs/002-link-follow-count.md)
Accepted by: kayshn (requested build in issue #19).

## Files that change
- `src/app/main.py`: `Link.follow_count: int = 0`; `Store.follow_lock` (`threading.Lock`) and
  `Store.count_follow(link)`; `LinkOut.follow_count: int`; `follow()` calls `store.count_follow(link)`
  strictly after the shared 404 branch and before returning the redirect.
- `tests/test_main.py`: new tests (see Proof).
- `.sdlc/plans/002-link-follow-count.md`: this plan.

## Order of work
1. Add the field to `Link` and `LinkOut`.
2. Add the lock and `count_follow` to `Store`.
3. Call it from `follow()` after the 404 check.
4. Add tests; run `make lint` and `make test`.

No route is added, so the `/{code}` catch-all ordering is unaffected. `CreateLink` is untouched and
keeps `extra="forbid"`. No `store.record` call on follow, per the spec. `threading` is stdlib, so G3
does not apply: no new dependency.

## Risks
- Audit rule 4 / CLAUDE.md say state-changing routes call `store.record`. The spec follows the
  intent and does not audit follows. Known, deliberate non-conformance; the policy owner must confirm.
- Anonymous callers can inflate counts; bots and prefetchers are counted. Rate limiting out of scope.
- Pre-existing: `follow()` does not re-validate the target against `ALLOWED_SCHEMES`. Not changed here.
- A follow racing a delete may increment a link already removed from the store; the count is discarded
  with it, so this is harmless.
- No `.github/workflows/` change is needed.

## Proof
Tests in `tests/test_main.py`: new link is 0; follow increments by 1; unknown and expired follows
increment nothing; audit unchanged by a follow; non-owner list never shows the count and the redirect
carries no count; caller cannot set `follow_count` (422); 8 threads x 1000 increments give 8000;
delete discards the link and its count. Plus `make lint` and `make test`.
