# Developer workflow

How one change travels from an idea to production, and which steps a person performs.

A solid outline is a step someone performs. A dashed outline happens on its own.

```mermaid
flowchart TD
    I["Write .sdlc/intent/NNN-name.md<br/>Open a pull request and merge it"]
    S["Spec written, approved and merged"]
    B["Build issue opens,<br/>quoting the spec's areas of concern"]
    G{"Spec accepted?"}
    X["Close the issue.<br/>Nothing is built."]
    C["Comment @claude on the issue"]
    P["Plan, code and tests<br/>pushed to a branch"]
    O["Open the pull request<br/>from the agent's branch"]
    R["CI runs. The AI review posts findings.<br/>It never approves."]
    G2{"Ready to merge?"}
    F["Comment @claude fix this"]
    M["Merge the pull request"]
    D["Deployment waits for release approval"]
    A["Approve the deployment"]
    L(["Live in production"])

    I --> S --> B --> G
    G -- no --> X
    G -- yes --> C --> P --> O --> R --> G2
    G2 -- no --> F --> R
    G2 -- yes --> M --> D --> A --> L

    classDef auto stroke-dasharray: 5 5
    class S,B,P,R,D auto
```

## The five actions

Everything between them is automatic. Nothing reaches production without a person acting.

| # | Action | Where | Who |
|---|---|---|---|
| 1 | Write the intent, open a pull request, merge it | `.sdlc/intent/<slug>.md` | author, then code owner |
| 2 | Comment `@claude` to accept the spec and start the build | the Build issue | product owner |
| 3 | Open the pull request from the agent's branch | the *Create PR* link | author |
| 4 | Merge once CI and the review look right | the pull request | code owner |
| 5 | Approve the release | the `production` environment | release manager |

One slug — `NNN-<short-name>` — ties the chain together:
`.sdlc/intent/<slug>.md` → `.sdlc/specs/<slug>.md` → `.sdlc/plans/<slug>.md` → pull request.

## Four things worth knowing

**Step 2 is the rejection point.** Closing the Build issue instead of commenting is how a spec is
turned down. A design exists by then; no code has been written. There is no other place in the loop
where a change can be stopped before work begins.

**The review stage is a cycle, not a step.** `@claude fix this` sends the change back through CI and
review. The arrow returns for that reason.

**The agent never passes a gate.** It writes artefacts, proposes code and posts findings. It does not
approve a pull request, merge one, or release. The single automatic approval is the spec, and the
pipeline grants it — not the agent — so that the decision moves to the Build issue instead of
disappearing.

**Three stages produce a file, one produces an issue.** Intent, spec and plan are artefacts, so each
arrives as a pull request. The build stage has no file to show yet, so its gate lives on an issue.

## Related

- [ONBOARDING.md](ONBOARDING.md) — adopting the loop in a new repository
- [README.md](README.md) — what each file does and why the loop is shaped this way
- `.sdlc/flow.yaml` — the same stages and gates, in machine-readable form
