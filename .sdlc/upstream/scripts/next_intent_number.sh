#!/bin/bash
# Print the next free 3-digit intent number (000, 001, ...), based on .sdlc/intent/NNN-*.md.
# Two open intent PRs can pick the same number; whoever merges second renumbers.
set -euo pipefail
dir=${1:-.sdlc/intent}
last=$(ls "$dir" 2>/dev/null | { grep -E '^[0-9]{3}-.*\.md$' || true; } | sort | tail -1 | cut -c1-3)
printf '%03d\n' $(( ${last:+10#$last + 1} + 0 ))
