# Review instructions

<!-- TEMPLATE: replace the Security bullet with this project's real rules. The more specific it is,
     the more useful the review. Keep the four passes, the severities, the tally line and the
     "Claims about what was run" rule. -->

## Passes
Run four passes and tag each finding with its pass:
- **Bugs**: logic errors, broken edge cases, subtle regressions.
- **Security**: authentication and authorisation gaps, injection, one user reading or changing another user's data, sensitive or user-supplied content in logs and error messages, missing audit events. Apply the secure-api-review skill.
- **Compliance**: the change matches `.sdlc/specs/<slug>.md` and `.sdlc/plans/<slug>.md` for this change, and CLAUDE.md conventions. If the PR has no matching spec or plan, say so.
- **Guardrails** — check the diff against `.sdlc/upstream/standards/engineering-guardrails.md`. Cite the
  id (G1–G6) for every breach. A suppression added to make a check pass is a G2 breach even when
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

## Adding a pass of your own
Put it in `.sdlc/REVIEW.local.md`, not here. The reviewer runs that file's passes after these ones,
and a release can improve the four above without reverting your work or stopping to ask. Tag its
findings with its own pass name so a reader can tell which rulebook a finding came from, and let it
end without a tally — the tally line belongs to this file.
