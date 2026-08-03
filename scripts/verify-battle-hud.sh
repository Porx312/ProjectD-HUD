#!/usr/bin/env bash
# Quick smoke test for unified HUD SSE stream (run on VPS or with API access).
set -euo pipefail

API_BASE="${API_BASE:-https://dev-api.projectd.space}"
STEAM_ID="${1:-}"
API_KEY="${API_KEY:-}"
CAR_MODEL="${CAR_MODEL:-}"

if [[ -z "$STEAM_ID" ]]; then
  echo "Usage: $0 <steamId> [api_key] [carModel]"
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

echo "GET $URL"
echo "--- first SSE events (15s timeout) ---"
curl -sN --max-time 15 -H "Accept: text/event-stream" "$URL" | head -n 40
echo ""
echo "Done."
