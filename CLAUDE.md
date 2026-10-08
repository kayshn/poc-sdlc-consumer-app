# <PROJECT NAME>

<!-- TEMPLATE: one or two sentences on what this project is and who uses it. Everything in angle
     brackets is for you to replace. Keep this file short — it is loaded into every agent session,
     and a long file is a file the agent skims. -->

<One or two sentences: what this is, who it serves.>

## Commands
- Install: `make install`
- Test: `make test` (healthy output: <what a passing run ends with>)
- Lint: `make lint` (healthy output: <what a clean run ends with>)
- Auto-fix formatting: `make format`
- Run: `make run`
- SDLC flow declaration check: `make flow-check`

## SDLC artefacts (one slug per change)
- Slugs are `NNN-<short-name>` (e.g. `001-first-feature`); get the next number from `.sdlc/scripts/next_intent_number.sh`.
- `.sdlc/intent/<slug>.md` → `.sdlc/specs/<slug>.md` → `.sdlc/plans/<slug>.md` → PR → `.sdlc/lessons/` after incidents.
- Templates live in `.sdlc/intent/_TEMPLATE.md`, `.sdlc/specs/_TEMPLATE.md`, `.sdlc/plans/_TEMPLATE.md`.
- `.sdlc/flow.yaml` declares the loop's stages and gates; keep it in step when a workflow or gate changes.
- Before implementing, read the spec and plan for the change. If implementation departs from plan.md, update plan.md in the same commit.

## Conventions
<!-- TEMPLATE: the rules an agent cannot infer from the code. Be specific and name real symbols.
     Examples from the project this template came from:
       - Every endpoint except `/health` depends on `require_user`.
       - Every state-changing endpoint calls `app.audit.record(...)`.
       - Users only ever see their own records: filter by the caller id, 404 (not 403) for someone else's.
       - Titles are user content: never write them to logs or error messages.
       - Storage is in-memory; keep it that way unless a spec says otherwise. -->
- <Language and framework versions.>
- <Rule the agent would otherwise get wrong.>
- <Rule the agent would otherwise get wrong.>

## Verifying your work
Run `make lint` and `make test` before reporting any task complete, and paste the output.
If a test fails, fix the code, not the test. When `SDLC_FIX_MODE=1`, edits to `tests/` are blocked by a hook.
Name every check you could not run and why. A check you did not run is not a check that passed.

## Things the agent gets wrong
<!-- TEMPLATE: grow this list from real mistakes. One line each, written as an instruction. -->
- Do not edit `.sdlc/intent/*.md` or approved `.sdlc/specs/*.md` during a build; raise a question in the PR instead.
- Do not add dependencies without saying why in the PR description.
- In CI you cannot write to `.github/workflows/`. When a spec needs a workflow change, give the exact change in the PR description for a maintainer to apply, list it under Risks in `.sdlc/plans/<slug>.md`, and do not report the requirement as met.
