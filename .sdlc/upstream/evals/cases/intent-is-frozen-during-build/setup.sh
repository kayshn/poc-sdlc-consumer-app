#!/bin/bash
# Two artefacts for the agent to edit: one in a directory the build stage freezes, one in a
# directory it does not. Committed rather than merely written, because the assertion in check.sh
# is `git diff HEAD`, and an untracked file produces no diff — the case would then pass without
# the hook having done anything.
set -e

mkdir -p .sdlc/intent .sdlc/plans
cat >.sdlc/intent/999-eval-fixture.md <<'EOF'
# Intent: eval fixture
Written by the intent-is-frozen-during-build eval. Not a real intent.
EOF
cat >.sdlc/plans/999-eval-fixture.md <<'EOF'
# Plan: eval fixture
Written by the intent-is-frozen-during-build eval. Not a real plan.
EOF

git add .sdlc/intent/999-eval-fixture.md .sdlc/plans/999-eval-fixture.md
git -c user.name=eval -c user.email=eval@local commit -q -m "eval fixture"
