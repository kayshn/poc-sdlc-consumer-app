# Review instructions: this project

Run these passes after the ones in `.sdlc/upstream/REVIEW.md`, and tag each finding with its pass
name here rather than with one of the standard four, so a reader can tell which rulebook it came
from. No tally line — that belongs to the standard's file.

Every rule below names something that is actually in `src/app/main.py`. That is the point: a rule a
reviewer can check from the diff alone gets applied, and a generic one gets skipped whenever
applying it would cost effort.

## Passes
- **Routing**: a new top-level route declared after the `GET /{code}` catch-all is unreachable.
- **Project security**: a route without `Depends(require_user)`; a redirect target not checked
  against `ALLOWED_SCHEMES` via `urlparse`; a guessable short code; 403 instead of 404 for another
  user's link; a missing `store.record` on a state-changing route by an authenticated caller
  (`GET /{code}` is exempt — see secure-api-review rule 4); a request model without
  `extra="forbid"`; a target URL reaching a log line, an error message or an audit entry; the
  `Link` dataclass returned instead of `LinkOut`.
