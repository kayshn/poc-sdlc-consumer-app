#!/usr/bin/env bash
# Run each eval case in a fresh worktree with the repo's CLAUDE.md, skills and hooks,
# then apply its deterministic check. Fails if the pass rate drops below MIN_PASS_RATE.
#
# A case is a folder under .sdlc/evals/cases/ with:
#   prompt.md  the task given to the agent
#   check.sh   exits 0 if the result is acceptable (runs in the worktree)
#   setup.sh   optional, runs before the agent (e.g. introduce a bug)
#   env        optional KEY=VALUE lines exported for the agent run (e.g. SDLC_FIX_MODE=1)
# Folders whose name starts with "_" are skipped.
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel)
MIN_PASS_RATE=${MIN_PASS_RATE:-0.66}
MODEL=${EVAL_MODEL:-claude-sonnet-5-5}
OUT=${EVAL_OUT:-$ROOT/eval-results}
mkdir -p "$OUT"

CASES=$ROOT/.sdlc/evals/cases
compgen -G "$CASES/*/" >/dev/null || { echo "No eval cases found under $CASES" >&2; exit 1; }

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
    CLAUDE_PROJECT_DIR="$wt" claude -p "$(cat "$case/prompt.md")" \
      --model "$MODEL" \
      --permission-mode acceptEdits \
      --allowedTools "Read,Edit,Write,Glob,Grep,Bash(make test),Bash(make lint),Bash(make format)" \
      --max-turns 30 \
      --output-format json > "$OUT/$name.json"
  )

  if (cd "$wt" && bash "$case/check.sh") > "$OUT/$name.check.log" 2>&1; then
    echo "PASS $name"; pass=$((pass + 1))
  else
    echo "FAIL $name (see $OUT/$name.check.log)"
  fi
  git -C "$ROOT" worktree remove --force "$wt"
done

rate=$(awk "BEGIN { printf \"%.2f\", $pass / $total }")
echo "EVAL-RESULT passed=$pass total=$total rate=$rate min=$MIN_PASS_RATE" | tee "$OUT/summary.txt"
awk "BEGIN { exit ($rate >= $MIN_PASS_RATE) ? 0 : 1 }"
