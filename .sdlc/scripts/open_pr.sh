#!/bin/bash
# Commit the given paths to a new branch and open a PR. Used by workflows so that
# Claude only writes files and PR creation stays deterministic.
# Usage: open_pr.sh <branch> <title> <body-file> <path>...
# Needs GH_TOKEN. Use a token other than GITHUB_TOKEN (see README.md) so the PR triggers CI and review.
set -euo pipefail
branch=$1 title=$2 body=$3; shift 3

git config user.name "sdlc-bot"
git config user.email "sdlc-bot@users.noreply.github.com"
git checkout -b "$branch"
git add -- "$@"
if git diff --cached --quiet; then
  echo "Nothing to commit for $branch"; exit 0
fi
git commit -q -m "$title"
git push -q origin "$branch"
gh pr create --base main --head "$branch" --title "$title" --body-file "$body"
