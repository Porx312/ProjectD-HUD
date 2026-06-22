#!/usr/bin/env bash
# Quick smoke test for Battle HUD SSE endpoint (run on VPS or with API access).
set -euo pipefail

API_BASE="${API_BASE:-http://13.140.160.131:3000}"
SERVER_NAME="${1:-ProjectD}"
STEAM_ID="${2:-}"
API_KEY="${API_KEY:-}"

if [[ -z "$STEAM_ID" ]]; then
  echo "Usage: $0 <serverName> <steamId> [api_key]"
  exit 1
fi

ENC_SERVER=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SERVER_NAME'''))")
ENC_STEAM=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$STEAM_ID'''))")
URL="${API_BASE}/hud/battle/stream?serverName=${ENC_SERVER}&steamId=${ENC_STEAM}"
if [[ -n "$API_KEY" ]]; then
  ENC_KEY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$API_KEY'''))")
  URL="${URL}&api_key=${ENC_KEY}"
fi

echo "GET $URL"
echo "--- first SSE events (15s timeout) ---"
curl -sN --max-time 15 -H "Accept: text/event-stream" "$URL" | head -n 40
echo ""
echo "Done."
