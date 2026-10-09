# Plan: Diagnose the ci_test_failure_rate 2-sigma breach (from .sdlc/specs/001-monitor-ci-test-failure-rate-20261009-1111.md)
Accepted by: kayshn (build requested on issue #13; the spec was auto-approved and not yet reviewed by a person).

## Files that change
- `.sdlc/plans/001-monitor-ci-test-failure-rate-20261009-1111.md`: this plan, the only file in this PR.
- No change to `src/`, `tests/`, `.github/workflows/`, `.sdlc/monitoring/` or any file in `.sdlc/invariant.txt`.
- No lesson and no eval case yet (R10): no real cause has been found. Add both only if a later diagnosis finds one.

The spec is a diagnosis, not a feature. Most requirements wait on data this build cannot reach (later samples, CI run logs), so the PR delivers the plan and the findings below. It does not close the intent's underlying question.

## Order of work
1. **R1, confirm the breach.** Run `scripts/detect.sh --bands .sdlc/monitoring/bands.json --metrics .sdlc/monitoring/metrics.json --inject 0.052` and record the output. Not done in this build: the CI sandbox refused to run the script. A maintainer should run it and paste the result in the PR. The expected result is the one in the intent (z = 2.40, tier `2sigma`).
2. **R9 / R4, read the repo-visible evidence (done).**
   - `.github/workflows/monitor.yml:14-16` has a `workflow_dispatch` input `inject`, described as "Synthetic latest value to simulate a breach (e.g. 0.052 for 2σ, 0.2 for 3σ)". The reported latest value is exactly `0.052`.
   - `scripts/detect.sh` only appends `--inject` to the series in memory and never writes `metrics.json`. This would explain why 0.052 is absent from the committed series, whose last sample is 0.0417 and is in band.
   - Hypothesis, not confirmed: this breach was a synthetic injection, for example a drill of the monitor, and not a real measurement. It is confirmed or refuted by one check: open the Monitor run that produced the report in the Actions tab and see whether `inject` was set to `0.052`. The scheduled run (`cron: 0 */6 * * *`) passes `inject` empty.
   - The code that appends real samples lives in the external `_monitor.yml` at template `v2.0.0`. It is not in this repo, so the ordering of "append vs detect" (R9) is not settled here.
   - R4 (did v2.0.0 change what counts as a run or failure?) cannot be answered from this repo either. The metric producer is in the template's `_monitor.yml`, and the workflow diffs were not inspected in this build.
3. **R2, collect further samples.** No remediation until the Western Electric rules in `bands.json` fire on committed or detector-reported data. A single point is not enough.
4. **R3, classify failures.** Only if step 3 shows a real shift. Needs CI run logs, which are not available here.
5. **R5-R7, fix by class.**
   - Application code: a test that fails before the fix and passes after it.
   - `.github/workflows/`: an exact diff in the PR description, listed under Risks below.
   - Template-owned files: raise upstream in `kayshn/poc-sdlc-template`.
6. **R10, record the outcome.** If the injection hypothesis is confirmed, or the rate returns to band, record "noise / synthetic" in the PR and write no lesson. If a real cause is found, write the lesson and the eval case under `.sdlc/evals/cases/`.

## Risks
- **Evidence gap.** Items R2, R3 and R4 are blocked on data outside this repo. Nothing here shows a root cause, and the requirements are not reported as met.
- **Workflow changes.** The agent cannot write to `.github/workflows/`. If the cause is in CI configuration, the fix is a maintainer-applied diff and stays unmet until applied. No such diff exists yet.
- **Template files.** Fixes to invariant files go upstream, so `make template-check` stays green.
- **Rollback.** Rolling back the template upgrades is a 3-sigma action and out of scope. A 2-sigma breach cannot authorise it.
- **Possible synthetic data.** If the report came from a drill, acting on it would be wrong. The check in step 2 should come first.
- **Verification not run.** `scripts/detect.sh`, `make lint` and `make test` were not run in this build because the sandbox refused those commands. The PR changes only a Markdown file.

## Proof
- R1: maintainer-run output of `scripts/detect.sh ... --inject 0.052`, pasted in the PR.
- R9: the Actions run inputs for the breaching Monitor run (was `inject` = `0.052`?).
- R11: `make lint` and `make test` unchanged, since no code changes. `make flow-check` and `make template-check` still hold, since no flow or invariant file changes.
