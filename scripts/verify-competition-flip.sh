#!/usr/bin/env bash
# Structural smoke test for competition FLIP reorder (no AC runtime required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check_absent() {
  if rg -q "$1" common/competition/anim.lua common/draw.lua common/layout.lua competition/first.lua 2>/dev/null; then
    echo "FAIL: found forbidden pattern: $1"
    fail=1
  else
    echo "OK: absent $1"
  fi
}

check_present() {
  local paths=(
    common/competition/anim.lua
    common/draw.lua
    common/draw/init.lua
    common/draw/competition/ladder.lua
    common/layout.lua
    common/layout/init.lua
    common/layout/competition.lua
  )
  if rg -q "$1" "${paths[@]}" 2>/dev/null; then
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
check_present 'avatar_with_tier'
check_present 'competition_time_block'
check_present 'format_lap_gap_sec'
check_present 'competition_delta_ahead'
check_present 'player_lap_ms'
check_present 'competition_card_fill'
if rg -q 'get_competition_rivals_overlay' common/draw.lua common/draw/competition/card.lua common/draw/competition/row.lua 2>/dev/null; then
  echo "OK: overlay texture used per card"
else
  echo "FAIL: missing per-card overlay"
  fail=1
fi
if rg -q 'get_competition_rivals_overlay' common/draw.lua common/draw/competition/*.lua 2>/dev/null && rg -q 'draw\.competition_panel' common/draw.lua common/draw/competition/*.lua common/draw/init.lua -A5 2>/dev/null | rg -q 'get_competition_rivals_overlay' 2>/dev/null; then
  echo "FAIL: overlay in general panel"
  fail=1
else
  echo "OK: no overlay on general panel"
fi

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
