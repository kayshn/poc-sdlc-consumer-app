#!/bin/bash
# Simulated pre-approved rollback runbook. The monitor may call this at the 3-sigma tier only.
set -euo pipefail
env=${1:?usage: rollback.sh <environment>}
echo "Rolling $env back to the previous release (simulated)"
