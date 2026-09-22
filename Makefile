SHELL := /bin/bash
PORT ?= 5381
VON_SERVE_PORT ?= $(PORT)
# Pass Hugging Face cache/credentials and von knobs through to the detached
# server (also inherited automatically when set in the invoking shell).
export HF_HOME HF_TOKEN VON_BACKEND VON_DEVICE VON_SERVE_LOG VON_SERVE_PORT
.PHONY: start status stop log e2e

# Non-blocking server lifecycle; log goes to output/von-serve.log.
start:
	@bash scripts/serve_ctl.sh start

status:
	@bash scripts/serve_ctl.sh status

stop:
	@bash scripts/serve_ctl.sh stop

# Follow the server log (Ctrl-C to detach; VON_SERVE_LOG overrides the path).
log:
	@tail -f "$${VON_SERVE_LOG:-output/von-serve.log}"

# End-to-end smoke against the running server; fails fast if it is not up.
e2e:
	@bash scripts/e2e.sh
