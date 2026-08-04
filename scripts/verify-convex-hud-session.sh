#!/usr/bin/env bash
# Assert HUD SSE returns a successful hud_session (profile) for an online player.
set -euo pipefail

API_BASE="${API_BASE:-https://dev-api.projectd.space}"
STEAM_ID="${1:-}"
API_KEY="${API_KEY:-}"
CAR_MODEL="${CAR_MODEL:-}"
TIMEOUT="${TIMEOUT:-20}"

if [[ -z "$STEAM_ID" ]]; then
  echo "Usage: $0 <steamId> [api_key] [carModel]"
  echo "Player must be connected on a ProjectD server (not just in AC menu)."
  exit 1
fi

ENC_STEAM=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$STEAM_ID'''))")
URL="${API_BASE}/hud/stream?steamId=${ENC_STEAM}&carFilter=global"
if [[ -n "$CAR_MODEL" ]]; then
  ENC_CAR=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$CAR_MODEL'''))")
  URL="${URL}&carModel=${ENC_CAR}"
fi
if [[ -n "$API_KEY" ]]; then
  ENC_KEY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$API_KEY'''))")
  URL="${URL}&api_key=${ENC_KEY}"
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

echo "GET $URL"
echo "--- waiting up to ${TIMEOUT}s for hud_session ---"

curl -sN --max-time "$TIMEOUT" -H "Accept: text/event-stream" "$URL" > "$TMP" || true

if [[ ! -s "$TMP" ]]; then
  echo "FAIL: empty response (player offline or stream closed)"
  exit 1
fi

python3 - "$TMP" <<'PY'
import json, re, sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
blocks = re.split(r"\n\n+", text.strip())
session = None
errors = []

for block in blocks:
    event = ""
    data_lines = []
    for line in block.splitlines():
        if line.startswith("event:"):
            event = line[6:].strip()
        elif line.startswith("data:"):
            data_lines.append(line[5:].strip())
    if not data_lines:
        continue
    raw = "\n".join(data_lines)
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        continue
    if event in ("hud_error", "session:error") or (
        payload.get("ok") is False and payload.get("reason")
    ):
        errors.append(payload.get("reason") or payload)
        continue
    if event in ("hud_session", "session:update") or payload.get("profile") is not None:
        session = payload
        break
    if payload.get("ok") is True and payload.get("version"):
        session = payload
        break

if session is None:
    print("FAIL: no hud_session received")
    if errors:
        print("hud_error reasons:", errors)
    else:
        print("raw (first 800 chars):", text[:800])
    sys.exit(1)

profile = session.get("profile") or {}
print("OK: hud_session received")
print("  version:", session.get("version"))
print("  ok:", session.get("ok"))
print("  profile.name:", profile.get("name"))
print("  profile.rank:", profile.get("rank"))
print("  profile.elo:", profile.get("elo"))
print("  profile.tier:", profile.get("tier"))
PY

echo "Done."
