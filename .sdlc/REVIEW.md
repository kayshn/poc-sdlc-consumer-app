# Review instructions

<!-- TEMPLATE: replace the Security bullet with this project's real rules. The more specific it is,
     the more useful the review. Keep the three passes, the severities and the tally line. -->

## Passes
Run three passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, subtle regressions.
- **Security**: authentication and authorisation gaps, injection, one user reading or changing another user's data, sensitive or user-supplied content in logs and error messages, missing audit events. Apply the secure-api-review skill.
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
