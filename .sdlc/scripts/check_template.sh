#!/usr/bin/env bash
# Does this repo still conform to the AI-native SDLC template?
#
#   drift      the invariant layer matches the manifest it shipped with
#   structure  the contracts the workflows depend on still hold
#   wiring     consumers only: callers point at a tag, no leftover callables, no stub targets
#   staleness  consumers only: warns when a newer tag exists. Never fails, because CI should not
#              go red the moment github.com is slow; the scheduled sdlc-update job acts on it.
#
# The drift check compares the invariant layer against the manifest sitting next to it, so it
# detects accidental edits, not deliberate ones: nothing authenticates the local manifest. The
# tool that regenerates it is not shipped to consumers, so the obvious way to silence the check is
# not one command away, but a determined edit can still do it. Treat a green result as "nobody has
# drifted from the standard by accident".
#
# Run by ci.yml via `make template-check`, as its own step, independent of your test runner.
set -uo pipefail
cd "$(dirname "$0")/../.."
# shellcheck source=.sdlc/scripts/_sdlc_lib.sh
. ./.sdlc/scripts/_sdlc_lib.sh

fail=0
check() { if [ "$1" = ok ]; then echo "  ok   $2"; else echo "  FAIL $2"; fail=1; fi; }
ok_if() { if eval "$1"; then check ok "$2"; else check fail "$2"; fi; }
warn() { echo "  warn $1"; }

source_repo=$(template_source)
version=$(template_version)
if [ -n "$version" ]; then
  echo "Checking conformance to ${source_repo:-unknown} $version"
else
  echo "Checking conformance (no $VERSION_FILE, so this repo is the template itself)"
fi

# --- the invariant layer is unmodified -----------------------------------------------------------
if [ ! -f "$MANIFEST" ]; then
  check fail "$MANIFEST exists (run: make manifest)"
else
  declared=$(expand_invariant . 2>/dev/null)
  listed=$(awk '{print $2}' "$MANIFEST" | LC_ALL=C sort -u)
  ok_if '[ "$declared" = "$listed" ]' "$MANIFEST covers exactly the paths named in $INVARIANT_LIST"

  if verify_manifest "$MANIFEST"; then
    check ok "the invariant layer matches the manifest"
  else
    check fail "the invariant layer matches the manifest (files above differ; run: make sdlc-update)"
  fi

  # The class of bug that silently disables a gate: a script committed without its executable bit.
  # Files named _*.sh are sourced, not run.
  nonexec=""
  while IFS= read -r f; do
    case $(basename "$f") in
    _*) continue ;;
    *.sh) [ -x "$f" ] || nonexec="$nonexec $f" ;;
    esac
  done <<<"$listed"
  ok_if '[ -z "$nonexec" ]' "invariant scripts are executable (not executable:${nonexec:- none})"
fi

# --- structural contracts the workflows depend on ----------------------------------------------
# .sdlc/REVIEW.md and .claude/settings.json stay yours to edit, so they are checked for the
# contract the pipeline reads, not for byte equality.
ok_if 'grep -q "REVIEW-TALLY" .sdlc/REVIEW.md' "REVIEW.md still ends in a machine-readable tally"
for pass in Bugs Security Compliance; do
  ok_if 'grep -qi "\*\*$pass\*\*" .sdlc/REVIEW.md' "REVIEW.md keeps the $pass pass"
done
ok_if 'grep -q "Claims about what was run" .sdlc/REVIEW.md' \
  "REVIEW.md keeps the rule that an execution claim is unverified (copy that section from the template)"
for hook in protect-paths production-gate; do
  ok_if 'grep -q "hooks/$hook.sh" .claude/settings.json' "settings.json still registers $hook.sh"
done

# --- consumer wiring ---------------------------------------------------------------------------
if [ -n "$version" ]; then
  ok_if '! ls .github/workflows/_*.yml >/dev/null 2>&1' \
    "no leftover _*.yml callables (workflow_call never self-fires; delete them)"

  for wf in ci claude-review deploy agent-evals sdlc-update intent-to-spec spec-to-build claude monitor; do
    [ -f ".github/workflows/$wf.yml" ] || continue
    # Anchored to the start of the line so the `#   uses: ...@vX` example in the file header
    # cannot satisfy the check.
    ok_if 'grep -qE "^[[:space:]]*uses: *[^ #]+/\.github/workflows/_$wf\.yml@" ".github/workflows/$wf.yml"' \
      "$wf.yml calls the standard by ref, not by local copy"
    pinned=$(sed -nE "s#^[[:space:]]*uses: *[^ #]+/\.github/workflows/_$wf\.yml@([^ ]+).*#\1#p" ".github/workflows/$wf.yml")
    [ -z "$pinned" ] || ok_if '[ "$pinned" = "$version" ]' \
      "$wf.yml is pinned to $version (found ${pinned:-none})"
    # A caller that still carries a body is the defect this split exists to close: an upgrade can
    # repoint a pinned ref, but it can never reach logic the project holds itself, so a fix to that
    # logic is announced in the release notes and silently not installed.
    ok_if '! grep -qE "^[[:space:]]*(runs-on|steps):" ".github/workflows/$wf.yml"' \
      "$wf.yml is a thin caller, not a local copy of the body (fix: ./.sdlc/scripts/sdlc_update.sh --rewire)"
  done

  ok_if '! grep -q "TODO: wire up" Makefile' \
    "make lint and make test are wired up (the template ships them failing on purpose)"

  # Files that belong to the template's own upkeep, not to a project built from it.
  for leftover in TODO.md .sdlc/scripts/make_manifest.sh; do
    ok_if '[ ! -e "$leftover" ]' "$leftover is not carried over from the template"
  done

  # ONBOARDING.md was merged into SDLC-GUIDE.md. A consumer that predates the merge still has its
  # own copy, which sdlc_update.sh cannot remove because the project owns it.
  if [ -f ONBOARDING.md ]; then
    warn "ONBOARDING.md was merged into SDLC-GUIDE.md and can be deleted"
  fi
fi

# --- staleness, as a warning only --------------------------------------------------------------
if [ -n "$source_repo" ] && [ "${SDLC_SKIP_STALENESS:-0}" != 1 ]; then
  latest=$(latest_tag "$source_repo")
  if [ -z "$latest" ]; then
    warn "could not reach $source_repo to check for a newer template"
  elif [ "$latest" != "$version" ]; then
    warn "$source_repo $latest is available; this repo is on $version (run: make sdlc-update)"
  else
    check ok "on the latest template tag ($version)"
  fi
fi

[ $fail -eq 0 ] && echo "This repo conforms to the SDLC template."
exit $fail
