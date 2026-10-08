---
name: write-intent
description: Capture an idea, ticket or production finding as .sdlc/intent/<slug>.md. Use when someone describes a problem or feature they want, or when a monitor or incident diagnosis needs to re-enter the SDLC loop.
---
# Write an intent

1. If the originator is a person, brainstorm first: ask about scope, affected users, constraints, what success looks like, and what is out of scope. Stop asking once the idea is concrete.
2. The slug is `NNN-<short-kebab-name>`, where NNN is the next number from `.sdlc/scripts/next_intent_number.sh` (e.g. `002-delete-todo`). It names the whole chain: .sdlc/intent/<slug>.md → .sdlc/specs/<slug>.md → .sdlc/plans/<slug>.md, so artefacts sort in the order they were raised.
3. Write `.sdlc/intent/<slug>.md` using every heading in `.sdlc/intent/_TEMPLATE.md`. Keep the originator's own words for the problem. Set `Status: draft`.
4. For monitor- or incident-sourced intents, set `Source: monitor <metric>` and put the evidence (breach values, run links, log excerpts) under Problem.
5. Do not propose a solution design here; that is the spec stage's job.
