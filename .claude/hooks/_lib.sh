#!/usr/bin/env bash
# Shared helper for the hooks. Claude Code sends the hook payload as JSON on stdin.
# jq is used when available, with python3 and node as fallbacks, so the hooks never depend on
# the project's own toolchain. Source this file, then:
#   payload=$(cat); path=$(field "$payload" tool_input.file_path)
field() {
  local payload=$1 path=$2
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$payload" | jq -r --arg p "$path" 'try (getpath($p | split(".")) | strings) // ""'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$payload" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print(d if isinstance(d, str) else "")' "$path"
  elif command -v node >/dev/null 2>&1; then
    printf '%s' "$payload" | node -e '
let s = ""
process.stdin.on("data", c => s += c).on("end", () => {
  let d = JSON.parse(s)
  for (const k of process.argv[1].split(".")) d = d && typeof d === "object" ? d[k] : undefined
  process.stdout.write(typeof d === "string" ? d : "")
})' "$path"
  else
    echo "Hook error: no jq, python3 or node found, so the SDLC hooks cannot read their input." >&2
    return 1
  fi
}
