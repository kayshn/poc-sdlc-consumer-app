# Review instructions

## Passes
Run three passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, subtle regressions. A new top-level route declared after the `GET /{code}` catch-all is unreachable.
- **Security**: a route without `Depends(require_user)`; a redirect target not checked against `ALLOWED_SCHEMES` via `urlparse`; a guessable short code; 403 instead of 404 for another user's link; a missing `store.record` on a state-changing route; a request model without `extra="forbid"`; a target URL reaching a log line, an error message or an audit entry; the `Link` dataclass returned instead of `LinkOut`. Apply the secure-api-review skill.
- **Compliance**: the change matches `.sdlc/specs/<slug>.md` and `.sdlc/plans/<slug>.md` for this change, and CLAUDE.md conventions. If the PR has no matching spec or plan, say so.

## Severity
- **Important**: would break behaviour, leak data, or breach a policy.
- **Nit**: style, naming, minor readability.

## Cap the nits
Report at most five nits; summarise the rest as a count.

## Do not report
Anything `make lint` already enforces, and anything under a dependency or build-output directory.

## Output
Finish with one top-level comment that ends in a machine-readable tally line:
`REVIEW-TALLY important=<n> nit=<n>`
