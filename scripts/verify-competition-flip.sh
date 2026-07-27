#!/usr/bin/env bash
# Structural smoke test for competition FLIP reorder (no AC runtime required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check_absent() {
  if rg -q "$1" common/competition_anim.lua common/draw.lua common/layout.lua competition/first.lua 2>/dev/null; then
    echo "FAIL: found forbidden pattern: $1"
    fail=1
  else
    echo "OK: absent $1"
  fi
}

check_present() {
  if rg -q "$1" common/competition_anim.lua common/draw.lua common/layout.lua 2>/dev/null; then
    echo "OK: present $1"
  else
    echo "FAIL: missing required pattern: $1"
    fail=1
  fi
}

echo "=== Competition FLIP structural checks ==="
check_absent 'player_climb'
check_absent 'rival_swap'
check_absent 'alpha_old'
check_absent 'alpha_new'
check_present 'flip_reorder'
check_present 'competition_slot_y'
check_present 'COMPETITION_FLIP_SEC'
check_present 'player_direction'

echo ""
echo "=== Manual in-game mock (Asset Corsa console) ==="
cat <<'EOF'
ac.storage("ProjectD-HUD:use_api", false):set()

-- Player rank change (rivals reorder, no overlap/fade)
ac.storage("ProjectD-HUD:competition_mock_rank", 3):set()
ac.storage("ProjectD-HUD:competition_mock_rank", 2):set()

-- Rival below swap only (Keisuke -> Itsuki, ~0.55s)
ac.storage("ProjectD-HUD:competition_mock_rank", 2):set()
ac.storage("ProjectD-HUD:competition_mock_rival_below", "itsuki"):set()

-- Lap-only change: no animation (same names/ranks in slots)
EOF

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "Verification FAILED"
  exit 1
fi

echo ""
echo "Verification PASSED"
