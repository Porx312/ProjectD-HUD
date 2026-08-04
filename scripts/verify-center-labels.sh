#!/usr/bin/env bash
# Structural check: battle center labels never blank for mock phase states.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check_pattern() {
  if rg -q "$1" common/api/battle/battle_phases.lua common/draw/battle/center.lua 2>/dev/null; then
    echo "OK: $2"
  else
    echo "FAIL: missing $2"
    fail=1
  fi
}

echo "=== Battle center never-blank structural checks ==="

check_pattern 'center_label' 'center_label field in build_display'
check_pattern 'countdown_label' 'countdown_label fallback'
check_pattern 'center_key == "countdown"' 'countdown center_key handling'
check_pattern 'MATCHMAKING|matchmaking' 'matchmaking fallback text'
check_pattern 'VS|vs' 'VS fallback text'

MOCK_STATES=(matchmaking vs countdown active cancelled result draw)
for state in "${MOCK_STATES[@]}"; do
  if rg -q "\"${state}\"" common/mock_data.lua 2>/dev/null; then
    echo "OK: mock state ${state}"
  else
    echo "FAIL: mock state ${state} missing in mock_data.lua"
    fail=1
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  echo ""
  echo "Verification FAILED"
  exit 1
fi

echo ""
echo "Verification PASSED"
