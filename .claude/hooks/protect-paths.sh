#!/usr/bin/env bash
# PreToolUse(Edit|Write): block edits to approved artefacts, and to tests while fixing a bug.
# Part of the invariant layer: the paths frozen in fix mode are declared in
# .sdlc/protected-paths.txt, so a project can retarget the rule without being able to soften it.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
path=$(field "$payload" tool_input.file_path)
[ -n "$path" ] || exit 0

# The tool reports an absolute or a project-relative path, and CLAUDE_PROJECT_DIR is not reliably
# the directory the file sits under — in a git worktree it is the repository. Stripping it as a
# prefix therefore fails open, so match the protected segment anywhere in the path instead.
covers() {
  local prefix=${1%/}/
  [[ "$path" == "$prefix"* || "$path" == */"$prefix"* ]]
}

protected_paths() {
  local d
  for d in "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    if [ -n "$d" ] && [ -f "$d/.sdlc/protected-paths.txt" ]; then
      cat "$d/.sdlc/protected-paths.txt"
      return
    fi
  done
  echo "tests/"
}

if [[ "${SDLC_FIX_MODE:-}" == "1" ]]; then
  while IFS= read -r prefix || [[ -n "$prefix" ]]; do
    [[ -z "$prefix" || "$prefix" == \#* ]] && continue
    if covers "$prefix"; then
      echo "Blocked: SDLC_FIX_MODE=1, so $prefix is frozen. Fix the code, not the test." >&2
      exit 2
    fi
  done < <(protected_paths)
fi

if [[ "${SDLC_STAGE:-}" == "build" ]] && { covers .sdlc/intent || covers .sdlc/specs; }; then
  echo "Blocked: intent and approved specs are read-only during build. Raise a question in the PR instead." >&2
  exit 2
fi
exit 0
