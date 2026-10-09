---
name: write-spec
description: Turn an accepted .sdlc/intent/<slug>.md into a requirements and design spec at .sdlc/specs/<slug>.md. Use when asked to produce a spec or design from an intent.
---
# Write a spec

1. Read `.sdlc/intent/<slug>.md`, `CLAUDE.md`, and the relevant code so the design fits the existing codebase.
2. Load every policy skill that applies (at minimum secure-api-review for any endpoint change).
3. Write `.sdlc/specs/<slug>.md` using every heading in `.sdlc/upstream/templates/spec.md`, with `Status: proposed`.
4. Requirements must be numbered and testable.
5. Under "Policy check", list each applied rule as satisfied or concern.
6. Under "High-level design", apply G6: if the change adds, removes or re-points a deployable unit, a datastore, an external service or a trust boundary, amend the diagram named by `stages.design.diagram` in `.sdlc/flow.yaml`, paste the amended view here as a mermaid block and say in one line what moved. If it does not, write exactly `No architectural change.` and one line of why. One of the two must be there.
7. Under "Areas of concern", flag anything you could not satisfy, any contradiction between policies, and any open question from the intent that blocks design. Never silently drop an open question: answer it or carry it forward.
8. Do not write code or plans.
