# Intent: Investigate ci_test_failure_rate 2-sigma breach
Author: monitor (ci_test_failure_rate detector). Status: draft. Source: monitor ci_test_failure_rate

## Problem
The detector reported a 2-sigma breach on `ci_test_failure_rate` (tier `2sigma`, action `diagnose`):

    {"metric":"ci_test_failure_rate","tier":"2sigma","action":"diagnose","latest":0.052,"mean":0.0383,"sd":0.0057,"z":2.40}

Evidence gathered read-only on 2026-10-09:

- **Size of the breach.** 0.052 is 1.4 points above the baseline mean (0.0383), z = 2.40. The 2-sigma line is about 0.0497. This is one point just over the line, not a sustained shift.
- **History is noisy.** `.sdlc/monitoring/metrics.json` holds 40 samples, ranging 0.0307 to 0.0495. Earlier samples of 0.0495, 0.049 and 0.0472 sat just under the same line. The latest value 0.052 is not yet in that file, which ends at 0.0417. The last recorded sample is therefore normal.
- **Application code is unchanged.** The only commits touching `src/` or `tests/` are from 2026-10-08: `ba5a334` (initial stack), `eeef30f` (expiring links, 000-expiring-links) and `5af6e2c` (fix: test `ttl_seconds` against None, not truthiness). Nothing in `src/` or `tests/` has changed since.
- **Recent commits are all SDLC template and CI changes, dated 2026-10-09.**
  - `e53610a` (template v2.0.0) rewrote `.github/workflows/claude.yml`, `intent-to-spec.yml`, `monitor.yml` and `spec-to-build.yml`. It also changed `ci.yml`, `deploy.yml`, `agent-evals.yml` and `check_flow.sh` / `check_template.sh`.
  - `a438dd9` and `c47120f` (v1.7.0) changed `agent-evals.yml`, `intent-to-spec.yml`, `ci.yml` and `open_pr.sh`.
  - `d9acf9d` (v1.6.2) changed `ci.yml`, `check_template.sh` and `invariant.txt`.
  - Three template upgrades landed within one day, immediately before the breach. They are the only changes to CI configuration in the window.
- **Prior incidents.** `.sdlc/lessons/` contains only its README, so there is no earlier incident of this class to compare against.
- **Not available to this diagnosis.** CI run logs and per-test failure data. It cannot be shown which tests failed, whether failures cluster in one test or job, or whether they are real failures or CI infrastructure failures such as flaky setup or the new workflow wiring.

Assessment: the breach is weak evidence on its own (a single sample, in a series that has come close to this level before). If it is a real regression, the CI changes from the three template upgrades are the leading suspect, since the application code is unchanged. That is a hypothesis, not a confirmed cause.

## Proposed outcome
Find out whether the rate has really shifted and, if so, why. The failure rate should return to its usual band (about 0.03 to 0.045), and any real cause should be caught in CI next time.

## Affected users and systems
- Contributors and agents relying on `make test` / CI as a gate.
- `.github/workflows/ci.yml` and the other workflows changed by template v1.6.2, v1.7.0 and v2.0.0.
- `.sdlc/monitoring/` (the metric series and band configuration).

## Constraints
- The `.sdlc/invariant.txt` files belong to the template and must not be edited here. Any template-side fix goes upstream.
- Agents in CI cannot write to `.github/workflows/`. A workflow fix must be given as an exact change in the PR description for a maintainer to apply.
- Do not edit existing tests to make the rate look better. Fix the code, not the test.

## Out of scope
- Rolling back the template upgrades. That is a 3-sigma action under `bands.json`.
- Changing the band or baseline configuration, unless the diagnosis shows the detector itself is wrong.
- Any change to the URL-shortener behaviour.

## Open questions
- Which tests or jobs failed in the runs behind the 0.052 sample? Are the failures real test failures or CI infrastructure failures?
- Do the next few samples stay above about 0.0497, or does this return to normal? (Western Electric rules usually want more than one point.)
- Is the metric's sample window affected by the CI workflow changes, for example runs counted differently since template v2.0.0?
- Why is the latest sample (0.052) missing from `metrics.json`? Is the series updated after the detector runs?
- Should a lesson be written under `.sdlc/lessons/` once the cause is found, with an eval under `.sdlc/evals/`?
