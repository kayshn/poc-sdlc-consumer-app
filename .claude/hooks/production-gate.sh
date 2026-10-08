#!/usr/bin/env bash
# PreToolUse(Bash): production deploys require a named release authorisation.
source "$(dirname "$0")/_lib.sh"
payload=$(cat)
cmd=$(field "$payload" tool_input.command)
# Match an actual deploy invocation targeting prod (e.g. `scripts/deploy.sh production`, `deploy --env prod`),
# not any command that merely mentions both words.
if [[ "$cmd" =~ deploy(\.sh)?[[:space:]]+(--env[=[:space:]])?prod(uction)?([[:space:]]|$) && -z "${RELEASE_APPROVAL:-}" ]]; then
  echo "Production deploys need a release authorisation. Ask the release manager to approve the 'production' environment in the Deploy workflow." >&2
  exit 2  # exit 2 blocks the action; the message goes to the agent
fi
exit 0
