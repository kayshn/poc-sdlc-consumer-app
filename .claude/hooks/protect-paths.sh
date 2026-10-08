#!/usr/bin/env bash
# PreToolUse(Edit|Write): block edits to approved artefacts, and to tests while fixing a bug.
# Part of the invariant layer: the paths frozen in fix mode are declared in
# .sdlc/protected-paths.txt, so a project can retarget the rule without being able to soften it.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
path=$(field "$payload" tool_input.file_path)
rel="${path#"$CLAUDE_PROJECT_DIR"/}"

if [[ "${SDLC_FIX_MODE:-}" == "1" ]]; then
  while IFS= read -r prefix || [[ -n "$prefix" ]]; do
    [[ -z "$prefix" || "$prefix" == \#* ]] && continue
    if [[ "$rel" == "$prefix"* ]]; then
      echo "Blocked: SDLC_FIX_MODE=1, so $prefix is frozen. Fix the code, not the test." >&2
      exit 2
    fi
  done < <(cat "${CLAUDE_PROJECT_DIR:-.}/.sdlc/protected-paths.txt" 2>/dev/null || echo "tests/")
fi
if [[ "${SDLC_STAGE:-}" == "build" && ( "$rel" == .sdlc/intent/* || "$rel" == .sdlc/specs/* ) ]]; then
  echo "Blocked: intent and approved specs are read-only during build. Raise a question in the PR instead." >&2
  exit 2
fi
exit 0
