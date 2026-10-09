#!/usr/bin/env bash
# Run each eval case in a fresh worktree with the repo's CLAUDE.md, skills and hooks,
# then apply its deterministic check. Fails if the pass rate drops below MIN_PASS_RATE.
#
# A case is a folder under .sdlc/upstream/evals/cases/ with:
#   prompt.md  the task given to the agent
#   check.sh   exits 0 if the result is acceptable (runs in the worktree)
#   setup.sh   optional, runs before the agent (e.g. introduce a bug)
#   env        optional KEY=VALUE lines exported for the agent run (e.g. SDLC_FIX_MODE=1)
# Folders whose name starts with "_" are skipped.
#
# Each run writes <case>.json (the result), <case>.check.log and <case>.debug.log to EVAL_OUT.
# The debug log is where hook resolution shows up: a case that fails because a hook did not fire
# is indistinguishable from one that fails on its own merits without it.
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel)
MIN_PASS_RATE=${MIN_PASS_RATE:-0.66}
MODEL=${EVAL_MODEL:-claude-sonnet-5-5}
OUT=${EVAL_OUT:-$ROOT/eval-results}
mkdir -p "$OUT"

CASES=$ROOT/.sdlc/upstream/evals/cases
compgen -G "$CASES/*/" >/dev/null || { echo "No eval cases found under $CASES" >&2; exit 1; }

# `claude -p` exits 0 even when the run failed, reporting it as `is_error` in the JSON result.
# Most checks are negative assertions ("the agent did not touch X"), which an agent that never ran
# satisfies perfectly — so an errored run has to fail the case regardless of what its check says.
# Prints the reason, or nothing if the agent completed.
agent_error() {
  local f=$1
  [ -n "$(tr -d '[:space:]' <"$f" 2>/dev/null)" ] || { echo "the agent produced no result"; return; }
  # Fails closed: only an explicit `is_error: false` counts as the agent having completed.
  # Note `.is_error // true` would be wrong — jq's // treats false as absent.
  if command -v jq >/dev/null 2>&1; then
    jq -r 'if (has("is_error") and .is_error == false) then "" else (.result // .terminal_reason // "unknown error") end' "$f" 2>/dev/null ||
      echo "unreadable result file"
  else
    python3 - "$f" <<'PY' 2>/dev/null || echo "unreadable result file"
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("result") or d.get("terminal_reason") or "unknown error" if d.get("is_error", True) else "")
PY
  fi
}

pass=0 total=0
for case in "$CASES"/*/; do
  name=$(basename "$case")
  [[ $name == _* ]] && continue # _-prefixed folders are examples, not cases
  total=$((total + 1))
  wt=$(mktemp -d)/"$name"
  git -C "$ROOT" worktree add -q --detach "$wt" HEAD

  (
    cd "$wt"
    [[ -f "$case/setup.sh" ]] && bash "$case/setup.sh"
    [[ -f "$case/env" ]] && set -a && source "$case/env" && set +a
    # Without this the workspace is untrusted, .claude/settings.json is ignored, and the hooks the
    # case exists to exercise never run. Claude Code keys trust on the repository, so the main
    # checkout has to be trusted as well as the worktree.
    "$ROOT/.sdlc/upstream/scripts/trust_workspace.sh" "$ROOT" "$wt" >/dev/null
    CLAUDE_PROJECT_DIR="$wt" claude -p "$(cat "$case/prompt.md")" \
      --model "$MODEL" \
      --permission-mode acceptEdits \
      --allowedTools "Read,Edit,Write,Glob,Grep,Bash(make test),Bash(make lint),Bash(make format)" \
      --max-turns 30 \
      --debug-file "$OUT/$name.debug.log" \
      --output-format json > "$OUT/$name.json"
  )

  if err=$(agent_error "$OUT/$name.json") && [ -n "$err" ]; then
    echo "FAIL $name (the agent did not complete: $err)"
  elif (cd "$wt" && bash "$case/check.sh") > "$OUT/$name.check.log" 2>&1; then
    echo "PASS $name"; pass=$((pass + 1))
  else
    echo "FAIL $name (see $OUT/$name.check.log)"
  fi
  git -C "$ROOT" worktree remove --force "$wt"
done

rate=$(awk "BEGIN { printf \"%.2f\", $pass / $total }")
echo "EVAL-RESULT passed=$pass total=$total rate=$rate min=$MIN_PASS_RATE" | tee "$OUT/summary.txt"
awk "BEGIN { exit ($rate >= $MIN_PASS_RATE) ? 0 : 1 }"
