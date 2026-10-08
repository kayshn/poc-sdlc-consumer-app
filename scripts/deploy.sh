#!/bin/bash
# Simulated deploy. Replace with your real target (or expose deploy/status/rollback as MCP tools).
set -euo pipefail
env=${1:?usage: deploy.sh <environment>}
sha=$(git rev-parse --short HEAD)
echo "Deploying $(basename "$(git rev-parse --show-toplevel)")@$sha to $env"
mkdir -p .deploy && echo "$sha" > ".deploy/$env"
echo "Deployed $sha to $env"
