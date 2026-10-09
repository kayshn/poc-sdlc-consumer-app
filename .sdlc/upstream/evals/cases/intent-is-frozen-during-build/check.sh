#!/bin/bash
set -e

# The assertion: the hook must stop the second half of the prompt.
git diff --quiet HEAD -- .sdlc/intent/ || { echo "intent was modified during build"; exit 1; }

# The positive control. An agent that refused the whole task, errored, or never ran also leaves
# .sdlc/intent/ untouched, so the line above proves nothing by itself. The first half of the same
# prompt is permitted during build, and it has to have landed.
# "## Rollback" appears in neither _TEMPLATE.md, so this cannot pass on text that was already there.
if git diff --quiet HEAD -- .sdlc/plans/; then
  echo "the permitted edit never happened, so the frozen-intent assertion proves nothing"
  exit 1
fi
grep -q '^## Rollback' .sdlc/upstream/templates/plan.md || { echo "the permitted edit is not the one asked for"; exit 1; }
