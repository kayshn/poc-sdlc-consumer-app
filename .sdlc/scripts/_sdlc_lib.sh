#!/usr/bin/env bash
# Shared helpers for the three template-distribution scripts. Source it; do not execute it.
# Kept bash 3.2 compatible so it runs on a stock macOS shell as well as on the runners.

INVARIANT_LIST=.sdlc/invariant.txt
MANIFEST=.sdlc/MANIFEST.sha256
VERSION_FILE=.sdlc/TEMPLATE_VERSION

# The manifest format is ours: `<hash>  <path>`, sorted by path. Deliberately not delegated to
# `sha256sum -c`, whose output and input formats differ between GNU, BSD and macOS — a manifest
# written on a laptop has to verify byte-identically on the runners.

# Bare sha256 of one file, whichever tool is present and whichever format it prints.
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1"
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    openssl dgst -sha256 "$1"
  fi | grep -oE '[0-9a-f]{64}' | head -1
}

# Read paths on stdin, write `<hash>  <path>` lines.
manifest_lines() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s  %s\n' "$(sha256_of "$f")" "$f"
  done
}

# Check every line of a manifest against the working tree. Names the offenders on stderr.
verify_manifest() {
  local want path rc=0
  while read -r want path; do
    [ -n "$path" ] || continue
    if [ ! -f "$path" ]; then
      echo "$path: MISSING" >&2
      rc=1
    elif [ "$(sha256_of "$path")" != "$want" ]; then
      echo "$path: CHANGED" >&2
      rc=1
    fi
  done <"$1"
  return $rc
}

# Print every file covered by <root>/.sdlc/invariant.txt, as paths relative to <root>, sorted.
# Returns non-zero if the list declares something that is not there.
expand_invariant() {
  local root=${1:-.} line missing=0 tmp
  [ -f "$root/$INVARIANT_LIST" ] || { echo "missing $root/$INVARIANT_LIST" >&2; return 1; }
  tmp=$(mktemp)
  while IFS= read -r line; do
    case $line in '' | '#'*) continue ;; esac
    if [ -d "$root/$line" ]; then
      (cd "$root" && find "$line" -type f ! -name '.DS_Store')>>"$tmp"
    elif [ -f "$root/$line" ]; then
      printf '%s\n' "$line" >>"$tmp"
    else
      echo "$INVARIANT_LIST declares a path that does not exist: $line" >&2
      missing=1
    fi
  done <"$root/$INVARIANT_LIST"
  LC_ALL=C sort -u "$tmp"
  rm -f "$tmp"
  return $missing
}

# owner/repo this project takes the standard from, or empty in the template repo itself.
# The `|| true` matters: callers run under `set -e`, and a first install has no version file yet.
template_source() { sed -n 's/^source: *//p' "$VERSION_FILE" 2>/dev/null || true; }

# The tag currently installed, or empty in the template repo itself.
template_version() { sed -n 's/^version: *//p' "$VERSION_FILE" 2>/dev/null || true; }

# Highest v* tag published by owner/repo. Empty if the network or the repo is unavailable.
latest_tag() {
  git ls-remote --tags --refs "https://github.com/$1" 'v*' 2>/dev/null |
    awk -F/ '{print $NF}' | LC_ALL=C sort -V | tail -1 || true
}
