# poc-sdlc-consumer-app

A URL shortener used to demonstrate the AI-native SDLC loop. Short codes map to absolute `http(s)`
targets. Callers identify themselves with an `X-User-Id` header; storage is in-memory.

@.sdlc/standards/engineering-guardrails.md

## Commands
- Install: `make install`
- Test: `make test` (healthy output ends with a line like `10 passed in 0.42s`)
- Lint: `make lint` (healthy output ends with `N files already formatted`)
- Auto-fix formatting: `make format`
- Run: `make run`
- SDLC flow declaration check: `make flow-check`
- SDLC template conformance: `make template-check`

Every target runs through `.venv/`, created by `make install`. Never call `pytest` or `ruff` from
the system Python.

## SDLC artefacts (one slug per change)
- Slugs are `NNN-<short-name>` (e.g. `001-first-feature`); get the next number from `.sdlc/scripts/next_intent_number.sh`.
- `.sdlc/intent/<slug>.md` → `.sdlc/specs/<slug>.md` → `.sdlc/plans/<slug>.md` → PR → `.sdlc/lessons/` after incidents.
- Templates live in `.sdlc/intent/_TEMPLATE.md`, `.sdlc/specs/_TEMPLATE.md`, `.sdlc/plans/_TEMPLATE.md`.
- `.sdlc/flow.yaml` declares the loop's stages and gates; keep it in step when a workflow or gate changes.
- Before implementing, read the spec and plan for the change. If implementation departs from plan.md, update plan.md in the same commit.
- Files listed in `.sdlc/invariant.txt` belong to the template, not to this project. Do not edit
  them; `make template-check` fails if you do. Propose the change upstream instead.

## Conventions
- Python 3.13, FastAPI, pytest, ruff. One module: `src/app/main.py`. Tests in `tests/`.
- Every route takes `user: str = Depends(require_user)`. The only anonymous routes are
  `GET /health` and `GET /{code}`.
- Request bodies are a `BaseModel` with `model_config = ConfigDict(extra="forbid")`.
- Every state-changing route calls `store.record(user, "<entity>.<action>", code)`.
- Users only ever see their own links: filter on `link.owner == user`, and return **404, not 403**,
  for someone else's — a 403 confirms the code exists.
- A target URL is user content. It must never appear in a log line, an error message or an audit
  entry. Audit the code instead.
- Return `LinkOut`, never the `Link` dataclass, so `owner` is never serialised.
- Redirect targets are validated with `urlparse` against `ALLOWED_SCHEMES` before they can reach a
  `Location` header.
- Codes come from `secrets.token_urlsafe`. Never a counter, never derived from the target.
- Storage is in-memory (`store`); keep it that way unless a spec says otherwise.

## Verifying your work
Run `make lint` and `make test` before reporting any task complete, and paste the output.
If a test fails, fix the code, not the test. When `SDLC_FIX_MODE=1`, edits to `tests/` are blocked by a hook.
Name every check you could not run and why. A check you did not run is not a check that passed.

## Things the agent gets wrong
- Do not edit `.sdlc/intent/*.md` or approved `.sdlc/specs/*.md` during a build; raise a question in the PR instead.
- Do not add dependencies without saying why in the PR description. Pin the version in
  `requirements.txt` or `requirements-dev.txt`.
- In CI you cannot write to `.github/workflows/`. When a spec needs a workflow change, give the exact change in the PR description for a maintainer to apply, list it under Risks in `.sdlc/plans/<slug>.md`, and do not report the requirement as met.
- `GET /{code}` is a catch-all. A new top-level route must be declared *before* it in `main.py`, or
  it will never be reached. Add a test that proves the new route resolves.
- Returning 403 for another user's link is a bug here, not a nicety.
