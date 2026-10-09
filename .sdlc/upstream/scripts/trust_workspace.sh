#!/usr/bin/env bash
# Claude Code ignores .claude/settings.json in a workspace it has not been told to trust — the
# permission rules and the hooks alike — and says so only on one line of stderr. Every CI checkout
# is a new directory, so without this the hooks that freeze approved artefacts during a build stop
# enforcing while everything still reports success.
#
# Run this before invoking the agent headlessly. Interactively, the trust dialog does the same job.
# Usage: trust_workspace.sh [dir ...]   (default: the current directory)
#
# Pass every directory the agent might resolve as its project. For a git worktree that means the
# main repository as well: Claude Code keys trust on the repository, not on the linked worktree.
set -euo pipefail
config="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"

dirs=()
for d in "${@:-.}"; do dirs+=("$(cd "$d" && pwd)"); done

python3 - "$config" "${dirs[@]}" <<'PY'
import json, os, sys

path, projects = sys.argv[1], sys.argv[2:]
try:
    with open(path) as f:
        data = json.load(f)
except (OSError, ValueError):
    data = {}
if not isinstance(data, dict):
    data = {}
for project in projects:
    data.setdefault("projects", {}).setdefault(project, {})["hasTrustDialogAccepted"] = True
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

printf 'Trusted for Claude Code (.claude/settings.json hooks and permissions will apply):\n'
printf '  %s\n' "${dirs[@]}"
