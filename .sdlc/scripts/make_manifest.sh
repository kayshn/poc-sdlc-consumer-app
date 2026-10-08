#!/usr/bin/env bash
# Regenerate .sdlc/MANIFEST.sha256 from the paths declared in .sdlc/invariant.txt.
# Run `make manifest` in the template repo after changing anything in the invariant layer;
# check_template.sh fails everywhere until you do, which is how the standard stays honest.
set -euo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=.sdlc/scripts/_sdlc_lib.sh
. ./.sdlc/scripts/_sdlc_lib.sh

files=$(expand_invariant .)
printf '%s\n' "$files" | manifest_lines | LC_ALL=C sort -k2 >"$MANIFEST"
echo "Wrote $MANIFEST ($(printf '%s\n' "$files" | wc -l | tr -d ' ') files)"
