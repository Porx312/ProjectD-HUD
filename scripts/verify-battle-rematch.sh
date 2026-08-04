#!/usr/bin/env bash
# Structural checks: second-battle recovery after result latch (rematch / poll fallback).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check_pattern() {
  if rg -q "$1" "$2" 2>/dev/null; then
    echo "OK: $3"
  else
    echo "FAIL: missing $3"
    fail=1
  fi
}

echo "=== Battle rematch / second-battle structural checks ==="

check_pattern 'ui\.is_lobby == true' common/api/battle/battle_phases.lua 'center_image_key is_lobby branch'
check_pattern 'battle_has_battle_id\(ui\)' common/api/battle/battle_phases.lua 'center_image_key battle_id guard'
check_pattern 'PREP_LIVE\[phase_state\]' common/api/battle/battle_phases.lua 'center_image_key PREP_LIVE guard'

check_pattern 'snapshot_poll_at = 0' common/api/battle_fetch.lua 'force snapshot poll after latch / battleId change'
check_pattern 'is_terminal_ui\(ui\)' common/api/battle_fetch.lua 'no_battle ignored for live battle'

check_pattern 'needs_battle_poll_backup' common/api/session_snapshot.lua 'poll backup when battle_ui nil'
check_pattern 'battle_backup' common/api/session_snapshot.lua 'SSE poll bypass for battle recovery'

check_pattern 'looking_for_opponent = false' common/api/battle_parse.lua 'clear looking when rival present'

check_pattern 'BATTLE_GAP_H = 176' common/layout/battle.lua 'gap strip height doubled'
check_pattern 'BATTLE_GAP_MARGIN = -20' common/layout/battle.lua 'gap strip closer to battle bar'

if [[ "${fail}" -ne 0 ]]; then
  echo ""
  echo "Verification FAILED"
  exit 1
fi

echo ""
echo "Verification PASSED"
