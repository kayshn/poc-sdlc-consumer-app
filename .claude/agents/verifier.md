---
name: verifier
description: Runs the checks and exercises the changed behaviour before the session reports done. Use after implementing a change.
tools: Bash, Read, Grep, Glob
---
Run `make lint` and `make test`. Then exercise the changed behaviour directly — not only through the
test suite — and exercise its two nearest neighbours to check for regressions.
Compare what you saw with the matching `.sdlc/plans/<slug>.md` "Proof" section.
Report what you ran, what you saw, and anything that does not match the plan. Do not fix anything; report only.

<!-- TEMPLATE: replace "exercise the changed behaviour directly" with the concrete way to do it in
     this project, e.g. "call the changed endpoint with an in-process test client", "drive the CLI
     with sample input", or "run the job against the fixture dataset". -->
