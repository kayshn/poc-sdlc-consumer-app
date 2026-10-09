# Spec: Diagnose the ci_test_failure_rate 2-sigma breach
Intent: .sdlc/intent/001-monitor-ci-test-failure-rate-20261009-1111.md. Skills applied: write-spec, secure-api-review (checked, not applicable: no endpoint change). Status: approved (auto)

## Summary
The monitor reported one sample (0.052, z = 2.40) just above the 2-sigma line (about 0.0497) for `ci_test_failure_rate`. The application code has not changed since 2026-10-08, and the only changes in the window are three SDLC template upgrades that touched CI. This spec does not change URL-shortener behaviour. It defines a diagnosis: decide whether the rate has really shifted, find the cause if so, and make the cause detectable in CI. It also covers the one gap in the monitoring data that is visible from the repo, which is that the latest sample is missing from `metrics.json`.

The intent's evidence is weak: it rests on one point, in a series that has reached 0.0495 before. The spec therefore treats "no real shift" as a valid outcome that closes the intent with a recorded finding and no code change.

## Requirements
1. Diagnosis starts by confirming the breach. The latest sample is compared with the baseline (mean 0.0383, sd 0.0057, 2-sigma line about 0.0497) using `scripts/detect.sh`, and the result is recorded in the PR or lesson.
2. The next samples are collected before any remediation. The shift counts as real only if the Western Electric rules in `bands.json` fire (more than one point beyond the line, or the usual multi-point patterns). A single point does not justify a workflow change.
3. If the shift is real, the diagnosis names the failing tests or jobs from CI run logs and classifies each failure as one of: a real test failure, a CI infrastructure failure (setup, caching, workflow wiring), or a counting change (runs counted differently).
4. The diagnosis checks whether template v2.0.0 changed what is counted as a run or a failure in the metric. This covers any new or renamed jobs and any re-runs counted twice.
5. Any fix to application code is covered by a test that fails before the fix and passes after it. Existing tests are not edited to improve the rate.
6. Any fix to `.github/workflows/` is given as an exact diff in the PR description for a maintainer to apply, and is listed under Risks in `.sdlc/plans/<slug>.md`. The requirement is not reported as met until a maintainer applies it.
7. Any fix to a file listed in `.sdlc/invariant.txt` is raised upstream and not made here. `make template-check` must still pass.
8. `.sdlc/monitoring/bands.json` and the baseline are unchanged unless the diagnosis shows the detector itself is wrong. If it does, the evidence is stated in the PR.
9. The cause of the missing latest sample is determined and documented. This is either a normal ordering where the series is appended after detection, or a defect.
10. If a real cause is found, a lesson is written in `.sdlc/lessons/` with a matching eval case in `.sdlc/evals/cases/`. If the breach is judged noise, the finding is recorded in the PR and no lesson is written.
11. `make lint` and `make test` pass on any resulting change, and no behaviour of `POST /links`, `GET /links`, `DELETE /links/{code}`, `GET /{code}` or `GET /health` changes.

## Design
- **Components touched:** none by default. This is read-only analysis of CI run data, `.sdlc/monitoring/metrics.json`, `scripts/detect.sh`, and the workflow diffs from commits `e53610a`, `a438dd9`, `c47120f` and `d9acf9d`.
- **Decision flow:**
  1. Confirm the breach (R1), then wait for further samples (R2).
  2. If the rate is back in band: record "noise", close, and do not change the configuration.
  3. If the rate is still high, work through failure classification (R3) and check for a counting change (R4).
  4. Depending on the class of cause, the fix goes to application code with a test (R5), to a workflow as a maintainer-applied diff (R6), or upstream for template files (R7).
- **API shape and data:** no endpoint, request body, storage or audit change. The in-memory `store`, `LinkOut`, `require_user`, `ALLOWED_SCHEMES` and the `GET /{code}` catch-all ordering are untouched.
- **Output artefacts:** a plan at `.sdlc/plans/<slug>.md`, and conditionally a lesson and an eval (R10).

## High-level design
No architectural change.

Read-only analysis of CI data that touches no application component at all. (Backfilled when G6 was
adopted; the spec predates it.)

## Policy check
- secure-api-review: not applicable, no endpoint is added or changed. Auth, ownership (404 not 403), `extra="forbid"`, audit and target-URL logging rules are unaffected. If a later fix does touch an endpoint, the spec must be revised and the review re-run.
- CLAUDE.md "do not edit invariant files": satisfied by R7.
- CLAUDE.md "cannot write to `.github/workflows/` in CI": satisfied by R6, but this limits what the agent can deliver. See Areas of concern.
- CLAUDE.md "fix the code, not the test": satisfied by R5.
- Intent and approved specs are not edited: satisfied. This spec only adds a new file.

## Areas of concern
1. **The evidence is insufficient for a root cause.** CI run logs and per-test failure data are not available to this analysis, and the intent itself calls the workflow-change theory a hypothesis. The spec deliberately does not name a cause, and the design must not be read as confirming one.
2. **Policy tension on the likeliest fix.** If the cause is in CI configuration, the fix lives in `.github/workflows/` (the agent cannot write there) or in template-owned files (the agent must not edit them). In either case the agent cannot complete the fix itself. The requirement stays unmet until a maintainer or the template owner acts, and this cannot be resolved inside this repo.
3. **Rollback is out of scope but may be the only fix.** If the three template upgrades are the cause, a rollback is a 3-sigma action under `bands.json` and is excluded by the intent. A 2-sigma breach therefore cannot authorise it. The product owner would need to raise the tier or decide separately.
4. **Possible gap in monitoring.** The latest sample is absent from `metrics.json`, so the series may lag the detector. If it does, detections run on data that the committed series does not show, and the result cannot be reproduced from the repo.
5. **Single-point trigger.** Acting on one point conflicts with the Western Electric rules named in `bands.json`. R2 resolves this by waiting, at the cost of a delayed diagnosis if the shift is real.

## Open questions carried forward
1. Which tests or jobs failed in the runs behind the 0.052 sample, and were they real or infrastructure failures? **Blocks R3.** Needs CI run logs, which this analysis cannot reach.
2. Do the next few samples stay above about 0.0497? **Blocks R2.** It can only be answered by waiting for new data.
3. Did template v2.0.0 change how runs are counted in the metric? Carried to R4. Answerable by reading the workflow diffs and the metric producer, but not yet answered.
4. Why is the 0.052 sample missing from `metrics.json`? Carried to R9. `scripts/detect.sh` and `monitor.yml` should show when the series is appended; this has not been confirmed here.
5. Should a lesson and an eval be written? Answered conditionally by R10: yes if a real cause is found, no if the breach is noise.
