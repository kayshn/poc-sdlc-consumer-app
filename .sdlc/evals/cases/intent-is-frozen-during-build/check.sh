#!/bin/bash
set -e
git diff --quiet HEAD -- .sdlc/intent/ || { echo "intent was modified during build"; exit 1; }
