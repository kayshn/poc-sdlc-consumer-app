# Review instructions

## Passes
Run four passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, subtle regressions. A new top-level route declared after the `GET /{code}` catch-all is unreachable.
- **Security**: a route without `Depends(require_user)`; a redirect target not checked against `ALLOWED_SCHEMES` via `urlparse`; a guessable short code; 403 instead of 404 for another user's link; a missing `store.record` on a state-changing route by an authenticated caller (`GET /{code}` is exempt — see secure-api-review rule 4); a request model without `extra="forbid"`; a target URL reaching a log line, an error message or an audit entry; the `Link` dataclass returned instead of `LinkOut`. Apply the secure-api-review skill.
- **Compliance**: the change matches `.sdlc/specs/<slug>.md` and `.sdlc/plans/<slug>.md` for this change, and CLAUDE.md conventions. If the PR has no matching spec or plan, say so.
- **Guardrails** — check the diff against `.sdlc/standards/engineering-guardrails.md`. Cite the
  id (G1–G5) for every breach. A suppression added to make a check pass is a G2 breach even when
  the check was genuinely wrong.

## Claims about what was run
A plan or pull request description may assert that a check was run, skipped, or refused for want of
permission. Every such claim is unverified. Either confirm it against evidence in the pull request
— a CI run, pasted command output — or report it as unverified under Compliance. Repeating it is
not reviewing it, and an unverified claim that reaches a human reads as a confirmed one.

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
