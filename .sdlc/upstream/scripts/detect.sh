#!/usr/bin/env bash
# Deterministic control-band detection. No model involved, no project toolchain.
# Reads a metric series and a bands config, compares the latest value with the rolling baseline,
# and prints the tier (none | 1sigma | 2sigma | 3sigma) plus evidence as JSON.
# Needs: jq, awk.
#
# Usage: detect.sh --bands <bands.json> --metrics <metrics.json> [--inject <value>]
set -euo pipefail

bands= metrics= inject=
while [ $# -gt 0 ]; do
  case $1 in
    --bands) bands=$2; shift 2 ;;
    --metrics) metrics=$2; shift 2 ;;
    --inject) inject=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$bands" ] && [ -n "$metrics" ] || { echo "usage: detect.sh --bands F --metrics F [--inject V]" >&2; exit 2; }

metric=$(jq -r '.metric' "$bands")
window=$(jq -r '.baseline_window' "$bands")
series=$(jq -r --arg m "$metric" '.[$m][]' "$metrics")
[ -n "$inject" ] && series="$series
$inject"

read -r tier latest mean sd z <<EOF
$(printf '%s\n' "$series" | awk -v window="$window" '
  { v[n++] = $1 + 0 }
  END {
    if (n < 2) { print "none 0 0 0 0"; exit }
    latest = v[n - 1]
    start = n - 1 - window; if (start < 0) start = 0
    for (i = start; i < n - 1; i++) { sum += v[i]; count++ }
    mean = sum / count
    for (i = start; i < n - 1; i++) { d = v[i] - mean; ss += d * d }
    sd = sqrt(ss / count); if (sd == 0) sd = 1e-9
    z = (latest - mean) / sd

    # Western Electric rule 2: 2 of the last 3 points beyond 2 sigma on the same side.
    for (i = (n - 3 > 0 ? n - 3 : 0); i < n; i++) if ((v[i] - mean) / sd > 2) drift++

    tier = z >= 3 ? "3sigma" : (z >= 2 || drift >= 2) ? "2sigma" : z >= 1 ? "1sigma" : "none"
    printf "%s %g %.4f %.4f %.2f\n", tier, latest, mean, sd, z
  }')
EOF

action=$(jq -r --arg t "$tier" '.tiers[$t].action // "none"' "$bands")
jq -nc --arg metric "$metric" --arg tier "$tier" --arg action "$action" \
  --argjson latest "$latest" --argjson mean "$mean" --argjson sd "$sd" --argjson z "$z" \
  '{metric: $metric, tier: $tier, action: $action, latest: $latest, mean: $mean, sd: $sd, z: $z}'
