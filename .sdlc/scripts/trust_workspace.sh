#!/usr/bin/env bash
# Claude Code ignores .claude/settings.json in a workspace it has not been told to trust — the
# permission rules and the hooks alike — and says so only on one line of stderr. Every CI checkout
# is a new directory, so without this the hooks that freeze approved artefacts during a build stop
# enforcing while everything still reports success.
#
# Run this before invoking the agent headlessly. Interactively, the trust dialog does the same job.
# Usage: trust_workspace.sh [dir]   (default: the current directory)
set -euo pipefail
dir=$(cd "${1:-.}" && pwd)
config="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"

python3 - "$config" "$dir" <<'PY'
import json, os, sys

path, project = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except (OSError, ValueError):
    data = {}
if not isinstance(data, dict):
    data = {}
data.setdefault("projects", {}).setdefault(project, {})["hasTrustDialogAccepted"] = True
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

echo "Trusted $dir for Claude Code (hooks and permissions from .claude/settings.json will apply)."
