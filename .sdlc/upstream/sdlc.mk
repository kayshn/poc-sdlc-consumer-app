# The SDLC targets, received rather than owned. Your Makefile includes this file; keep your own
# targets there and leave this one alone — `make sdlc-update` replaces it.
#
# `manifest` is absent on purpose: it regenerates the drift baseline, so shipping it would put
# "silence the drift check" one command away from anyone facing a red build.

.PHONY: flow-check template-check sdlc-update evals detect

flow-check:
	./.sdlc/upstream/scripts/check_flow.sh

template-check:
	./.sdlc/upstream/scripts/check_template.sh

# Upgrade the received layer. Not part of `install`: CI verifies, humans upgrade.
sdlc-update:
	./.sdlc/upstream/scripts/sdlc_update.sh

evals:
	./.sdlc/upstream/evals/run_evals.sh

detect:
	./.sdlc/upstream/scripts/detect.sh --bands .sdlc/monitoring/bands.json --metrics .sdlc/monitoring/metrics.json
