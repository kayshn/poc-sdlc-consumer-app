# The workflows call these targets by name: install, lint, test, flow-check, template-check,
# evals, detect. Keep the names; replace the bodies with whatever this project's stack needs.
.PHONY: install lint test format run flow-check template-check evals detect manifest sdlc-update

VENV := .venv
BIN := $(VENV)/bin

install:
	python3 -m venv $(VENV)
	$(BIN)/pip install -q --upgrade pip
	$(BIN)/pip install -q -r requirements.txt -r requirements-dev.txt

lint:
	$(BIN)/ruff check src tests
	$(BIN)/ruff format --check src tests

test:
	$(BIN)/pytest

format:
	$(BIN)/ruff format src tests
	$(BIN)/ruff check --fix src tests

run:
	$(BIN)/uvicorn app.main:app --reload --app-dir src

# Nothing below this line is stack-specific — leave it alone.

flow-check:
	./.sdlc/scripts/check_flow.sh

template-check:
	./.sdlc/scripts/check_template.sh

# Upgrade the invariant layer. Not part of `install`: CI verifies, humans upgrade.
sdlc-update:
	./.sdlc/scripts/sdlc_update.sh

# Template repo only: re-hash the invariant layer after changing it.
manifest:
	./.sdlc/scripts/make_manifest.sh

evals:
	./.sdlc/evals/run_evals.sh

detect:
	./scripts/detect.sh --bands .sdlc/monitoring/bands.json --metrics .sdlc/monitoring/metrics.json
