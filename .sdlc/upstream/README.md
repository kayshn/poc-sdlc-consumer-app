# This directory is not yours

Everything under `.sdlc/upstream/` arrives from the SDLC template and is replaced wholesale by
`make sdlc-update`. An edit here survives until the next upgrade and then disappears, with no
diff and no warning — which is the quietest way there is to lose a change.

`make template-check` fails if anything here has drifted, so the loss is usually caught. Do not
rely on that: it compares against a manifest sitting in the same working tree, so it detects
accidents, not intent.

Everything outside this directory is yours.

## When you need something different

Each file here that a project might reasonably want to change has a seam — a place to put the
difference that upgrades do not touch. Use it rather than editing the file.

| To change | Edit |
|---|---|
| the review passes | `.sdlc/REVIEW.local.md` (extra passes, run after these) |
| the engineering guardrails | `.sdlc/standards/project-guardrails.md` (`P1`, `P2`, …) |
| what runs after an agent edit | `make format-file FILE=<path>` |
| how behaviour is exercised | `make verify` |
| a workflow's triggers | the caller in `.github/workflows/`, not the body |
| which files the agent may not touch during a fix | `.sdlc/protected-paths.txt` |
| the stages, gates and artefact paths | `.sdlc/flow.yaml` |

If something you need has no seam, that is worth raising upstream: a missing seam is a defect in
the template, and the alternative — a local copy — is frozen at the version it was taken from and
can never receive a fix.
