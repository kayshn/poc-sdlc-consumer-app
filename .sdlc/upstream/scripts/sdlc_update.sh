#!/usr/bin/env bash
# Install or upgrade the invariant layer from a tag of the template repo, and nothing else:
# the Makefile bodies, CLAUDE.md, flow.yaml, skills and deploy scripts are yours and are never
# touched. Files the new version drops are removed, so the standard can shrink as well as grow.
#
#   make sdlc-update                        the newest tag of the source in .sdlc/TEMPLATE_VERSION
#   ./.sdlc/upstream/scripts/sdlc_update.sh v1.2.0   a specific tag
#   ./.sdlc/upstream/scripts/sdlc_update.sh --source kayshn/poc-sdlc-template v1.0.0   first install
#   ./.sdlc/upstream/scripts/sdlc_update.sh --rewire   re-run at the version already installed
#   ./.sdlc/upstream/scripts/sdlc_update.sh --accept-promotions   take the standard's copy of a file it has
#                                           taken over, keeping yours on disk to port by hand
#
# A release can also change the shape of a project: relocate something the project owns, or take
# over a file the project used to own. Neither can be worked out by comparing manifests, so the
# release declares it in .sdlc/MIGRATIONS, whose header explains the two kinds.
#
# --rewire exists because this script is itself part of the invariant layer: the copy that runs an
# upgrade is always the one installed *before* it, so a release that changes how the callers are
# wired cannot wire them on the way in. check_template.sh names the gap and asks for this.
#
# Deliberately not run by `make install`: CI that overwrote the invariant layer before testing it
# could never detect drift, and one bad tag would break every consumer at once. Upgrading is an
# act with a diff and a review, which is the whole point.
set -euo pipefail
trap 'echo "sdlc_update.sh failed at line $LINENO" >&2' ERR

# This script copies the invariant layer, which contains this script. Bash reads a script
# incrementally from a file offset, so overwriting it mid-run resumes at a meaningless offset and
# fails with a syntax error, after some of the work has been done. Re-exec from a copy first.
if [ "${SDLC_UPDATE_REEXEC:-}" != 1 ]; then
  SDLC_UPDATE_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
  export SDLC_UPDATE_ROOT SDLC_UPDATE_REEXEC=1
  self=$(mktemp)
  trap 'rm -f "$self"' EXIT
  cat "$0" >"$self"
  # Not `bash "$self" "$@"` bare: the ERR trap would fire here and report this line for a failure
  # the child has already explained, making a deliberate refusal read like a crash.
  rc=0
  bash "$self" "$@" || rc=$?
  exit $rc
fi

cd "${SDLC_UPDATE_ROOT:-$(dirname "$0")/../../..}"
# shellcheck source=.sdlc/upstream/scripts/_sdlc_lib.sh
. ./.sdlc/upstream/scripts/_sdlc_lib.sh

source_repo="" ref="" rewire=0 accept_promotions=0
while [ $# -gt 0 ]; do
  case $1 in
  --source)
    source_repo=${2:?--source needs owner/repo}
    shift 2
    ;;
  --rewire)
    rewire=1
    shift
    ;;
  --accept-promotions)
    accept_promotions=1
    shift
    ;;
  -*)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
  *)
    ref=$1
    shift
    ;;
  esac
done

[ -n "$source_repo" ] || source_repo=$(template_source)
[ -n "$source_repo" ] || {
  echo "No template source: $VERSION_FILE is missing and --source was not given." >&2
  exit 1
}

if [ -z "$ref" ]; then
  if [ "$rewire" = 1 ]; then
    ref=$(template_version)
  else
    ref=$(latest_tag "$source_repo")
  fi
  [ -n "$ref" ] || {
    echo "Could not read the tags of $source_repo." >&2
    exit 1
  }
fi

current=$(template_version)
if [ "$ref" = "$current" ] && [ "$rewire" != 1 ]; then
  echo "Already on $source_repo $ref."
  exit 0
fi
first_install=0
[ -n "$current" ] || first_install=1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "Fetching $source_repo $ref"
# The API tarball endpoint rather than codeload's /tar.gz path: the latter is eventually consistent
# and 404s for a tag created moments ago, while the API redirects to the archive that exists now.
# It also takes a token, which codeload does not, so a private source only needs one set here.
auth=()
[ -z "${GH_TOKEN:-${SDLC_BOT_TOKEN:-}}" ] || auth=(-H "Authorization: Bearer ${GH_TOKEN:-$SDLC_BOT_TOKEN}")
curl -fsSL "${auth[@]}" "https://api.github.com/repos/$source_repo/tarball/$ref" | tar -xzf - -C "$tmp"
src=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
[ -n "$src" ] || {
  echo "$source_repo $ref does not look like a template archive." >&2
  exit 1
}
[ -f "$src/$MANIFEST" ] || {
  echo "$source_repo $ref has no $MANIFEST, so its invariant layer is undefined." >&2
  exit 1
}

migrations=$(read_migrations "$src")

# A file this project owns can be taken over by the standard. Copying the new version over a local
# edit would revert it with no diff and no record, so that case stops here and a person decides.
#
# But "differs from the incoming copy" is not the same as "this project changed it": the standard
# may simply have moved on since the project was seeded. Telling the two apart needs the version
# the project actually received, so when there is anything to decide, that tag is fetched too.
# Nothing is written until the whole question is settled.
candidates=""
while read -r kind from to; do
  [ "$kind" = promote ] || continue
  [ -e "$from" ] || continue
  same_tree "$from" "$src/$to" && continue
  candidates="$candidates $from"
done <<EOF
$migrations
EOF

prev=""
if [ -n "$candidates" ] && [ -n "$current" ]; then
  mkdir -p "$tmp/prev"
  if curl -fsSL "${auth[@]}" "https://api.github.com/repos/$source_repo/tarball/$current" |
    tar -xzf - -C "$tmp/prev" 2>/dev/null; then
    prev=$(find "$tmp/prev" -mindepth 1 -maxdepth 1 -type d | head -1)
  fi
  [ -n "$prev" ] || echo "  warn could not fetch $current, so every difference below is treated as yours" >&2
fi

blocked="" untouched=""
while read -r kind from to; do
  [ "$kind" = promote ] || continue
  [ -e "$from" ] || continue
  same_tree "$from" "$src/$to" && continue
  if [ -n "$prev" ] && same_tree "$from" "$prev/$from"; then
    untouched="$untouched $from"
    echo "  ~ $from is the standard's now; it still matches the copy $current shipped, so nothing of yours is in it"
    continue
  fi
  blocked="$blocked $from"
  if [ "$from" = "$to" ]; then
    echo "  !  $from becomes part of the standard where it stands, and your copy differs:" >&2
  else
    echo "  !  $from becomes part of the standard, as $to, and your copy differs:" >&2
  fi
  diff -ru "$from" "$src/$to" | sed 's/^/     /' >&2 || true
done <<EOF
$migrations
EOF
if [ -n "$blocked" ] && [ "$accept_promotions" != 1 ]; then
  echo >&2
  echo "Nothing has been changed. Each file above has a documented seam for holding a local" >&2
  echo "difference without holding a copy of the file; see .sdlc/upstream/GUIDE.md. Port the change into" >&2
  echo "the seam, or re-run with --accept-promotions to take the standard's version and keep" >&2
  echo "yours on disk to port later." >&2
  exit 1
fi

# Relocations of paths the project owns. Applied first, so the rest of the upgrade writes into the
# shape this version expects.
while read -r kind from to; do
  [ "$kind" = move ] || continue
  [ -e "$from" ] || continue
  [ ! -e "$to" ] || {
    echo "Cannot move $from to $to: $to already exists. Resolve it by hand, then re-run." >&2
    exit 1
  }
  mkdir -p "$(dirname "$to")"
  mv "$from" "$to"
  echo "  > $from -> $to"
done <<EOF
$migrations
EOF

incoming=$(expand_invariant "$src")

# Drop invariant files this version no longer ships.
if [ -f "$MANIFEST" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$incoming" | grep -Fxq "$f" || {
      echo "  - $f"
      rm -f "$f"
      # A release that relocates the standard leaves its old directories behind. rmdir -p stops at
      # the first one that is not empty, so a directory holding anything of the project's survives.
      rmdir -p "$(dirname "$f")" 2>/dev/null || true
    }
  done < <(awk '{print $2}' "$MANIFEST")
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ] && cmp -s "$src/$f" "$f"; then continue; fi
  cp -p "$src/$f" "$f"
  echo "  + $f"
done <<<"$incoming"

cp -p "$src/$MANIFEST" "$MANIFEST"

# The standard now ships what these paths held. An identical copy is simply redundant; one that
# differs got here through --accept-promotions, and is left on disk for a person to port.
while read -r kind from to; do
  [ "$kind" = promote ] || continue
  [ -e "$from" ] || continue
  if [ "$from" = "$to" ]; then
    # Taken over in place: the install above has already written the standard's version here, so
    # there is no second copy to remove and nothing to port from. Whatever was replaced is in the
    # diff of this upgrade, which is the only place it can be. Comparing it with itself and
    # deleting on a match would remove the file that has just been installed.
    continue
  fi
  # An untouched copy holds nothing of the project's, so it goes without comment even though its
  # contents differ from the version that has just replaced it.
  case " $untouched " in *" $from "*) same=1 ;; *) same="" ;; esac
  if [ -n "$same" ] || same_tree "$from" "$to"; then
    rm -rf "$from"
    rmdir -p "$(dirname "$from")" 2>/dev/null || true
    echo "  - $from (the standard ships it as $to)"
  else
    echo "  !  $from is now inert: the pipeline reads $to. Port your change into the seam and" >&2
    echo "     delete it; template-check fails until you do." >&2
  fi
done <<EOF
$migrations
EOF

# Every pattern below is anchored to the start of the line, so the `#   uses: ...` example in a
# caller's header comment is never mistaken for the real job key.

# Rewrite `uses: ./.github/workflows/_x.yml` to the pinned form. The `./` form only resolves
# inside the repo that holds the body, so it is what the template itself uses and what every
# caller arrives with.
pin_local_calls() {
  local wf
  for wf in .github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    case $(basename "$wf") in _*) continue ;; esac
    grep -qE '^[[:space:]]*uses: *\./\.github/workflows/_[a-z-]+\.yml' "$wf" || continue
    sed -i.bak -E "s#^([[:space:]]*uses: *)\./(\.github/workflows/_[a-z-]+\.yml)#\1$source_repo/\2@$ref#" "$wf"
    rm -f "$wf.bak"
    echo "  ~ $wf now calls $source_repo@$ref"
  done
}

if [ "$first_install" = 1 ]; then
  # A repo made from the template inherits the template's own maintenance files. GitHub has no
  # .templateignore, so they are removed here instead.
  for leftover in TODO.md tools/make_manifest.sh; do
    [ -e "$leftover" ] || continue
    rm -f "$leftover"
    echo "  - $leftover (belongs to the template, not to this project)"
  done

  # A repo made from the template calls the bodies through its own copies. Switch it over to
  # calling them by tag, and drop the copies: workflow_call never self-fires, so they are inert.
  pin_local_calls
  for callable in .github/workflows/_*.yml; do
    [ -f "$callable" ] || continue
    rm -f "$callable"
    echo "  - $callable"
  done
else
  # A project created before a workflow's body was split out still holds a full-body copy, and no
  # upgrade can reach it: repointing a pinned ref cannot deliver a fix to logic the project owns,
  # so the fix is announced in the release notes and silently not installed. Swap such a copy for
  # this version's thin caller. A trigger the project had customised is then in the diff of the
  # upgrade pull request, which is where it should be argued about.
  for body in "$src"/.github/workflows/_*.yml; do
    [ -f "$body" ] || continue
    name=${body##*/_}
    caller=".github/workflows/$name"
    [ -f "$caller" ] || continue
    if grep -qE "^[[:space:]]*uses: *[^ #]+/\.github/workflows/_${name%.yml}\.yml@" "$caller"; then continue; fi
    cp -p "$src/.github/workflows/$name" "$caller"
    echo "  ~ $caller is now a thin caller; its body moved into the standard as _$name"
  done
  pin_local_calls

  # Repoint the thin callers at the new tag. Needs a token allowed to touch .github/workflows/.
  for wf in .github/workflows/*.yml; do
    [ -f "$wf" ] || continue
    grep -qE "^[[:space:]]*uses: *$source_repo/\.github/workflows/_[a-z-]+\.yml@" "$wf" || continue
    sed -i.bak -E "s#^([[:space:]]*uses: *$source_repo/\.github/workflows/_[a-z-]+\.yml@)[^ ]*#\1$ref#" "$wf"
    rm -f "$wf.bak"
    echo "  ~ $wf -> $ref"
  done
fi

{
  echo "# Written by .sdlc/upstream/scripts/sdlc_update.sh. The invariant layer below this project's own"
  echo "# files came from the tag named here. Run \`make sdlc-update\` to move to a newer one."
  echo "source: $source_repo"
  echo "version: $ref"
  echo "installed: $(date -u +%Y-%m-%d)"
} >"$VERSION_FILE"

echo "Now on $source_repo $ref (was ${current:-nothing}). Verifying:"
verify_manifest "$MANIFEST" && echo "  ok   the invariant layer matches $ref"

# A release that relocates a script leaves `make` pointing at a path that no longer exists, and
# `No such file or directory` is no help at the moment it is least welcome. The conformance check
# names every step a release leaves to a person, so point at it by the path this version puts it at
# rather than the one this copy of the script was run from.
checker=$(awk '{print $2}' "$MANIFEST" | grep -E '/check_template\.sh$' | head -1)
[ -z "$checker" ] || echo "Next: ./$checker — it names anything this release leaves for you to do."
