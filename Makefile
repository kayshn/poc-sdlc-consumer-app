# The workflows call install, lint, test and format by name, and the agent calls format-file and
# verify. Everything the SDLC loop itself needs arrives in .sdlc/upstream/sdlc.mk, included below.
.PHONY: install lint test format format-file verify run

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

# One file, called by the format-on-edit hook after every agent edit. Output and exit status are
# discarded by the hook, so a missing venv here can never interrupt a session.
format-file:
	@$(BIN)/ruff format -q "$(FILE)" && $(BIN)/ruff check -q --fix "$(FILE)"

verify:
	PYTHONPATH=src $(BIN)/python scripts/verify.py

run:
	$(BIN)/uvicorn app.main:app --reload --app-dir src

include .sdlc/upstream/sdlc.mk
