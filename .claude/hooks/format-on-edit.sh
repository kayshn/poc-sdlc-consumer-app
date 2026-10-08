#!/usr/bin/env bash
# PostToolUse(Edit|Write): keep formatting drift at zero. Fast, scoped to the edited file, never blocks.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
path=$(field "$payload" tool_input.file_path)
[ -f "$path" ] || exit 0

RUFF="${CLAUDE_PROJECT_DIR:-.}/.venv/bin/ruff"
[ -x "$RUFF" ] || RUFF=ruff

case "$path" in
*.py) "$RUFF" format -q "$path" && "$RUFF" check -q --fix "$path" ;;
*) ;;
esac >/dev/null 2>&1
exit 0
