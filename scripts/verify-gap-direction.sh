#!/usr/bin/env bash
# Structural check: gap sign convention (left=ahead, right=behind) and smooth meters.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check() {
  if rg -q "$1" "${@:2}" 2>/dev/null; then
    echo "OK: $1"
  else
    echo "FAIL: expected pattern $1"
    fail=1
  fi
}

echo "=== Gap direction & animation checks ==="

check 'role == "LEAD"' common/api/battle/battle_phases.lua
check 'role == "CHASE"' common/api/battle/battle_phases.lua
check 'signed = abs_m' common/api/battle/battle_phases.lua
check 'signed = -abs_m' common/api/battle/battle_phases.lua
check 'display_meters' common/battle/gap_anim.lua
check 'disappearGapM' common/api/battle/battle_phases.lua

if rg -q '"lead"' common/mock_data.lua && rg -q '"chase"' common/mock_data.lua; then
  echo "OK: mock lead/chase roles"
else
  echo "FAIL: mock lead/chase roles"
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo ""
  echo "Verification FAILED"
  exit 1
fi

echo ""
echo "Verification PASSED"
