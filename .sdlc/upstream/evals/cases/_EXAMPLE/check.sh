#!/bin/bash
set -e
make test >/dev/null
git diff --quiet HEAD -- tests/ || { echo "tests were modified"; exit 1; }
