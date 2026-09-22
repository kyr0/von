#!/usr/bin/env bash
# End-to-end smoke test against a running von server (make start first).
# Fails fast if the server is not up; asserts the /v1/systemone wire format
# for a full choice+noul+score fan-out plus one semantic sanity check.
set -euo pipefail
PORT="${VON_SERVE_PORT:-5381}"
BASE="http://127.0.0.1:${PORT}"

if ! curl -sf -m 5 "$BASE/health" >/dev/null; then
  echo "e2e: server not running on :${PORT} — start it with: make start" >&2
  exit 1
fi

echo "e2e: POST ${BASE}/v1/systemone (choice+noul+score fan-out)"
START=$(date +%s%N)
RESP=$(curl -sf -m 60 -X POST "$BASE/v1/systemone" -H "Content-Type: application/json" -d @- <<'JSON'
{
  "model": "von-1.1",
  "state": {
    "ticket": "Production database crashed after the deploy. All customers are locked out and we are losing orders every minute."
  },
  "questions": {
    "category": {
      "type": "choice",
      "instructions": "What kind of issue is `ticket`?",
      "criteria": {
        "bug": "Software bug, crash, or outage",
        "billing": "Invoice or card charge"
      }
    },
    "is_urgent": {
      "type": "noul",
      "instructions": "Is this an emergency or urgent situation?"
    },
    "severity": {
      "type": "score",
      "instructions": "Rate the incident severity.",
      "criteria": ["Low", "Medium", "High"]
    }
  }
}
JSON
)
END=$(date +%s%N)

echo "$RESP" | python3 -c '
import json, sys
a = json.load(sys.stdin)["answers"]
# Wire-format checks (deterministic)
assert set(a) == {"category", "is_urgent", "severity"}, a.keys()
assert a["category"]["type"] == "choice" and a["category"]["choice"] in ("bug", "billing"), a["category"]
assert 0.0 <= a["category"]["confidence"] <= 1.0, a["category"]
assert a["is_urgent"]["type"] == "noul" and 0.0 <= a["is_urgent"]["noul"] <= 1.0, a["is_urgent"]
assert a["severity"]["type"] == "score" and 0.0 <= a["severity"]["score"] <= 2.0, a["severity"]
# Semantic sanity: a production outage must read as urgent
assert a["is_urgent"]["noul"] > 0.5, a["is_urgent"]
print("e2e: PASS " + json.dumps(a))
'
echo "e2e: request latency $(( (END - START) / 1000000 ))ms"
