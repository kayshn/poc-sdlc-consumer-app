#!/usr/bin/env bash
# PostToolUse(Edit|Write): keep formatting drift at zero. Fast, scoped to the edited file, never blocks.
# TEMPLATE: uncomment or add the formatter for each file type this project uses. Keep it quiet and
# keep `exit 0` — a formatter failure must never block the agent.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
path=$(field "$payload" tool_input.file_path)
[ -f "$path" ] || exit 0

case "$path" in
  # *.py)            ruff format -q "$path" && ruff check -q --fix "$path" ;;
  # *.ts|*.tsx|*.js) npx --no-install prettier --write "$path" ;;
  # *.go)            gofmt -w "$path" ;;
  # *.rs)            rustfmt "$path" ;;
  # *.java)          ;;
  *) ;;
esac >/dev/null 2>&1
exit 0
