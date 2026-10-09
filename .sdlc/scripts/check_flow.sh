#!/usr/bin/env bash
# .sdlc/flow.yaml declares the shape of the loop. Keep it true to the repo.
# Run by ci.yml; run it yourself with `make flow-check`. Needs: yq (mikefarah), preinstalled on
# GitHub's Ubuntu runners. This is deliberately independent of the project's own test runner.
set -uo pipefail
cd "$(dirname "$0")/../.."

FLOW=.sdlc/flow.yaml
WORKFLOWS=.github/workflows
fail=0
check() { if [ "$1" = ok ]; then echo "  ok   $2"; else echo "  FAIL $2"; fail=1; fi; }
ok_if() { if eval "$1"; then check ok "$2"; else check fail "$2"; fi; }

# Predicates, not inline tests: ok_if evals its argument, and a mermaid fence is three backticks.
has_mermaid() { grep -q '^```mermaid' "$1"; }
hld_section() { awk '/^## /{f=0} /^## High-level design/{f=1} f' "$1"; }
hld_declared() {
  hld_section "$1" | grep -q '^```mermaid' || hld_section "$1" | grep -Fxq 'No architectural change.'
}

command -v yq >/dev/null || { echo "yq is not installed; cannot check $FLOW" >&2; exit 1; }

echo "Checking $FLOW"

stages=$(yq -r '.stages | keys | join(" ")' "$FLOW")
ok_if '[ "$stages" = "plan design build test deploy maintain" ]' "six stages in order (got: $stages)"
ok_if '[ "$(yq -r ".stages.maintain.next" "$FLOW")" = plan ]' "the loop closes back to plan"
ok_if '[ "$(yq -r ".stages.build.start" "$FLOW")" = manual ]' "build never starts on its own"

for stage in $stages; do
  for key in '.trigger.workflow' '.workflow' '.review'; do
    wf=$(yq -r ".stages.$stage$key // \"\"" "$FLOW")
    [ -n "$wf" ] && ok_if '[ -f "$WORKFLOWS/$wf" ]' "$stage: $WORKFLOWS/$wf exists"
  done
  for key in template config diagram; do
    f=$(yq -r ".stages.$stage.$key // \"\"" "$FLOW")
    [ -n "$f" ] && ok_if '[ -f "$f" ]' "$stage: $f exists"
  done

  [ "$(yq -r ".stages.$stage.gate // \"\"" "$FLOW")" = "" ] && continue
  if [ "$(yq -r ".stages.$stage.gate.configurable // false" "$FLOW")" = true ]; then
    approval=$(yq -r ".stages.$stage.gate.approval" "$FLOW")
    ok_if '[ "$approval" = auto ] || [ "$approval" = manual ]' "$stage: gate approval is auto or manual"
  else
    ok_if '[ -n "$(yq -r ".stages.$stage.gate.enforced_by // \"\"" "$FLOW")" ]' \
      "$stage: gate is configurable or says who enforces it"
    ok_if '[ "$(yq -r ".stages.$stage.gate.approval // \"manual\"" "$FLOW")" = manual ]' \
      "$stage: a gate the pipeline cannot automate is not marked auto"
  fi
done

configurable=$(yq -r '[.stages | to_entries[] | select(.value.gate.configurable) | .key] | join(" ")' "$FLOW")
ok_if '[ "$configurable" = design ]' "only the design gate is read by the pipeline (got: ${configurable:-none})"
# The step that reads the gate lives in the callable body. A consumer calls that body by tag and
# so has no local copy to grep, which leaves the call itself as the thing to assert.
if [ -f "$WORKFLOWS/_intent-to-spec.yml" ]; then
  ok_if 'grep -q "stages.design.gate.approval" "$WORKFLOWS/_intent-to-spec.yml"' \
    "_intent-to-spec.yml reads stages.design.gate.approval"
else
  ok_if 'grep -qE "^[[:space:]]*uses: *[^ #]+/\.github/workflows/_intent-to-spec\.yml@" "$WORKFLOWS/intent-to-spec.yml"' \
    "intent-to-spec.yml calls the standard body, which reads stages.design.gate.approval"
fi

# --- G6: the high-level diagram, and the specs that keep it honest -----------------------------
# A spec must declare one of two things: the architecture moved and here is the amended view, or it
# did not. Silence is the failure this closes — "not applicable" is the answer an agent reaches for
# when the rule costs it effort. Whether the picture is right stays the reviewer's job.
diagram=$(yq -r '.stages.design.diagram // ""' "$FLOW")
ok_if '[ -n "$diagram" ]' \
  "design: a high-level diagram is declared (add to $FLOW: stages.design.diagram: .sdlc/architecture/<name>.md)"
if [ -n "$diagram" ] && [ -f "$diagram" ]; then
  ok_if 'has_mermaid "$diagram"' "design: $diagram is a diagram as text (a mermaid block), not an image"
fi

for spec in .sdlc/specs/*.md; do
  [ -e "$spec" ] || continue
  name=$(basename "$spec")
  [ "$name" = _TEMPLATE.md ] && continue
  ok_if 'hld_declared "$spec"' \
    "specs/$name: High-level design carries a mermaid block, or the line 'No architectural change.' (G6)"
done

[ $fail -eq 0 ] && echo "flow.yaml is in step with the repo."
exit $fail
