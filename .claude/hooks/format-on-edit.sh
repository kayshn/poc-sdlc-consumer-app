#!/usr/bin/env bash
# PostToolUse(Edit|Write): keep formatting drift at zero. Fast, scoped to the edited file, never
# blocks. What to run is `make format-file` in this project's Makefile, so this hook stays the same
# in every project and arrives with each template release.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
path=$(field "$payload" tool_input.file_path)
[ -f "$path" ] || exit 0

cd "$(dirname "$0")/../.." || exit 0
# Output and status are both discarded: a formatter that is missing, slow to fail or merely noisy
# must never interrupt the agent mid-edit.
make format-file FILE="$path" >/dev/null 2>&1
exit 0
