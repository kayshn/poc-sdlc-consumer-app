# Example eval case — copy this folder to a name without the leading underscore to activate it.
# run_evals.sh skips folders starting with "_".
#
# A case is a folder under .sdlc/upstream/evals/cases/ with:
#   prompt.md  the task given to the agent (required)
#   check.sh   exits 0 if the result is acceptable; runs in a throwaway worktree (required)
#   setup.sh   optional, runs before the agent, e.g. to introduce a bug
#   env        optional KEY=VALUE lines exported for the agent run, e.g. SDLC_FIX_MODE=1
#
# This example is the "fix the code, not the test" eval: setup.sh breaks the source, the prompt
# asks for a fix, and check.sh fails if tests/ changed. It needs a real failing test to exist,
# so adapt setup.sh to this project before enabling it.
