#!/bin/bash
# Commit the given paths to a new branch and open a PR. Used by workflows so that
# Claude only writes files and PR creation stays deterministic.
#
# Usage: open_pr.sh [--unless <path>] <branch> <title> <body-file> <path>...
#
#   --unless <path>   exit without doing anything if <path> already exists on origin/main.
#                     Repeatable. For an artefact that should be produced exactly once: two
#                     concurrent runs otherwise both generate one, and the loser opens a pull
#                     request that can never merge. `concurrency:` does not cover a re-run of a
#                     completed run racing a fresh dispatch, which is how that happened.
#
# Needs GH_TOKEN. Use a token other than GITHUB_TOKEN (see README.md) so the PR triggers CI and review.
set -euo pipefail

unless=()
while [ "${1:-}" = "--unless" ]; do
  unless+=("$2")
  shift 2
done
branch=$1 title=$2 body=$3
shift 3

# The expensive step has already run by the time this script is called, so failing here throws away
# work that was generated and paid for. Put it somewhere a person can retrieve it.
# `staged` is captured before the commit, because `git diff --cached` is empty afterwards.
staged=""
preserve() {
  local reason=$1 f
  echo "::error::$reason"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  {
    echo "### Could not open the pull request"
    echo
    echo "$reason"
    echo
    echo "The generated files are below so the work is not lost. Re-run once the cause is fixed,"
    echo "or copy them out and commit them by hand."
  } >>"$GITHUB_STEP_SUMMARY"
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    {
      echo
      echo "<details><summary><code>$f</code></summary>"
      echo
      echo '```'
      cat "$f"
      echo '```'
      echo
      echo "</details>"
    } >>"$GITHUB_STEP_SUMMARY"
  done <<<"$staged"
}

git fetch -q origin main 2>/dev/null || true
for path in ${unless+"${unless[@]}"}; do
  if git cat-file -e "origin/main:$path" 2>/dev/null; then
    echo "$path already exists on origin/main; another run produced it. Nothing to do."
    exit 0
  fi
done

git config user.name "sdlc-bot"
git config user.email "sdlc-bot@users.noreply.github.com"
git checkout -b "$branch"
git add -- "$@"
if git diff --cached --quiet; then
  echo "Nothing to commit for $branch"
  exit 0
fi
staged=$(git diff --cached --name-only)
git commit -q -m "$title"

# A push rejected with 403 has one likely cause, and naming it is the difference between a
# two-minute fix and reading the raw log.
if ! push_output=$(git push origin "$branch" 2>&1); then
  printf '%s\n' "$push_output" >&2
  case $push_output in
  *403* | *"Permission to"*denied*)
    preserve "Push denied. GH_TOKEN authenticated but lacks write access: a fine-grained PAT needs Contents: write on this repository, and Workflows: write if the change touches .github/workflows/."
    ;;
  *)
    preserve "Push to $branch failed. See the log above."
    ;;
  esac
  exit 1
fi

if ! pr_output=$(gh pr create --base main --head "$branch" --title "$title" --body-file "$body" 2>&1); then
  printf '%s\n' "$pr_output" >&2
  preserve "The branch $branch was pushed but the pull request could not be opened. Open it by hand; nothing is lost."
  exit 1
fi
printf '%s\n' "$pr_output"
