---
name: write-spec
description: Turn an accepted .sdlc/intent/<slug>.md into a requirements and design spec at .sdlc/specs/<slug>.md. Use when asked to produce a spec or design from an intent.
---
# Write a spec

1. Read `.sdlc/intent/<slug>.md`, `CLAUDE.md`, and the relevant code so the design fits the existing codebase.
2. Load every policy skill that applies (at minimum secure-api-review for any endpoint change).
3. Write `.sdlc/specs/<slug>.md` using every heading in `.sdlc/specs/_TEMPLATE.md`, with `Status: proposed`.
4. Requirements must be numbered and testable.
5. Under "Policy check", list each applied rule as satisfied or concern.
6. Under "Areas of concern", flag anything you could not satisfy, any contradiction between policies, and any open question from the intent that blocks design. Never silently drop an open question: answer it or carry it forward.
7. Do not write code or plans.
