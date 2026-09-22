#!/usr/bin/env bash
# start|status|stop for the von decision server. Never blocks: start detaches
# immediately into a log file, status is one curl with a timeout, stop is one kill.
# Env: VON_SERVE_PORT (default 5381), VON_BACKEND; VON_DEVICE defaults to cuda:1.
set -euo pipefail
cd "$(dirname "$0")/.."
PIDFILE=output/von-serve.pid
LOG="${VON_SERVE_LOG:-output/von-serve.log}"
PORT="${VON_SERVE_PORT:-5381}"

alive() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "${1:-status}" in
  start)
    if alive; then
      echo "already running (pid $(cat "$PIDFILE")) -> http://127.0.0.1:${PORT}/health"
      exit 0
    fi
    mkdir -p output
    # Backend/device flow through the CLI flags; cli.py ignores the raw env vars for serve.
    uv run von serve --host 0.0.0.0 --port "$PORT" \
      --backend "${VON_BACKEND:-option-marker}" --device "${VON_DEVICE:-cuda:1}" \
      >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    echo "starting pid $(cat "$PIDFILE") (backend=${VON_BACKEND:-option-marker}, device=${VON_DEVICE:-cuda:1}, port=${PORT}), log: $LOG"
    echo "poll readiness with: make status"
    ;;
  status)
    if alive; then
      echo "pid $(cat "$PIDFILE") alive; health:"
      curl -s -m 3 "http://127.0.0.1:${PORT}/health" || echo "(still warming up — model load)"
    else
      echo "not running"
      exit 1
    fi
    ;;
  stop)
    if alive; then
      kill "$(cat "$PIDFILE")" && rm -f "$PIDFILE" && echo "stopped pid $PIDFILE"
    else
      echo "not running"
      rm -f "$PIDFILE"
    fi
    ;;
  *)
    echo "usage: $0 start|status|stop" >&2
    exit 2
    ;;
esac
