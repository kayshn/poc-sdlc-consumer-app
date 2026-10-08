# TODO

Deferred work on the template itself. Not part of the standard a consumer receives.

## Script the GitHub settings (`setup_github.sh`)

Two gates — the `production` environment's required reviewers, and *allow Actions to create and
approve pull requests* — exist in no file in the repo. A team that misses them gets a pipeline that
looks green and deploys to production with no human gate: a safety failure disguised as success, and
invisible to `make template-check`. [ONBOARDING.md](ONBOARDING.md) step 4 states them as prose, which
is the same mistake `.sdlc/flow.yaml` exists to avoid.

Proposed: `.sdlc/scripts/setup_github.sh`, in the invariant layer.

```bash
./.sdlc/scripts/setup_github.sh --verify                  # read-only; safe for CI and the scorecard
./.sdlc/scripts/setup_github.sh --apply --approvals 0
```

| Step | Scriptable | Endpoint |
|---|---|---|
| Install the Claude GitHub App | no — interactive consent, no API | — |
| `CLAUDE_CODE_OAUTH_TOKEN` | value is human-sourced | `gh secret set` from stdin, never logged |
| `SDLC_BOT_TOKEN` | fine-grained PATs cannot be minted by API | `gh secret set` from stdin, never logged |
| Actions may create and approve PRs | yes | `PUT /repos/{o}/{r}/actions/permissions/workflow` |
| Allow auto-merge | yes | `gh repo edit --enable-auto-merge` |
| `production` environment + reviewers | yes | `PUT /repos/{o}/{r}/environments/production` |
| Protect `main` | yes | `POST /repos/{o}/{r}/rulesets`, checks `ci / test` and `evals / suite` |

Design constraints:

- **`--verify` is the durable half.** A one-way apply gets run once and then drifts; the read-only
  check is what belongs in `check_template.sh` and the scorecard.
- **Only ever tighten.** A re-run must never remove a team's stricter rule. Assert and report, never
  sync down.
- **`--approvals` must be a parameter.** Hard-coding one required approval deadlocks any repo with a
  single maintainer, because GitHub forbids approving your own PR.
- **Report, do not pretend.** The three steps it cannot finish must be detected and named.
- **A local script, not a `bootstrap.yml` workflow.** A workflow would need an admin-scoped PAT
  stored as a repo secret in order to configure secrets — chicken-and-egg — and would leave every
  consumer holding a credential that can rewrite its own branch protection. Running locally against
  the adopter's own `gh` auth means no admin credential is stored anywhere.

## Also deferred

- **Conformance scorecard.** Scheduled job across repos with topic `ai-sdlc`, publishing template
  version, gates present and eval pass rate. `check_template.sh --verify` output is the input.
- **`copier` for layer 2.** `sdlc_update.sh` only carries the invariant layer. If the seeded files
  (`CLAUDE.md`, the `_TEMPLATE.md` artefacts, the thin callers) ever need to receive upstream
  improvements after creation, `copier update` three-way-merges via `.copier-answers.yml`.
  Cookiecutter has no update story.
- **Yank `v1.0.0`.** Its first install aborts silently; fixed in `v1.0.1`. The release notes say so,
  but nothing stops `sdlc_update.sh v1.0.0`.
- **`make install` provisioning is unproven beyond Python.** The claim that the Makefile is the only
  seam needs a second consumer on a different stack to hold up.
