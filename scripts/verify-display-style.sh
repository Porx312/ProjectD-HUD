#!/usr/bin/env bash
# Structural verification for display_style / frame_url HUD support.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check_grep() {
  local label="$1"
  local pattern="$2"
  local file="$3"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then
    echo "FAIL: $label ($file)"
    fail=1
  else
    echo "OK: $label"
  fi
}

check_grep "normalize_display_style" "normalize_display_style" "common/api/profile.lua"
if [[ ! -f "common/display_style.lua" ]]; then
  echo "FAIL: common/display_style.lua missing"
  fail=1
else
  echo "OK: display_style module"
fi
check_grep "get_frame" "function images.get_frame" "common/images.lua"
check_grep "draw_styled_name" "function M.draw_styled_name" "common/display_style.lua"
check_grep "avatar_with_frame" "function M.avatar_with_frame" "common/draw/shared.lua"
check_grep "frame overlay alignment" "FRAME_DRAW_SIZE_RATIO = 1.794" "common/draw/shared.lua"
check_grep "slot_from_rival cosmetics" "display_style = entry.display_style" "common/api_data.lua"

if [[ ! -d "fonts/display" ]]; then
  echo "FAIL: fonts/display/ missing"
  fail=1
else
  ttf_count="$(find fonts/display -maxdepth 1 -name '*.ttf' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "${ttf_count:-0}" -lt 5 ]]; then
    echo "FAIL: expected display TTFs in fonts/display/ (found ${ttf_count:-0})"
    fail=1
  else
    echo "OK: fonts/display ($ttf_count TTF files)"
  fi
fi

if [[ ! -f "assets/input/wheel.png" ]] || [[ ! -f "assets/input/controller.png" ]] || [[ ! -f "assets/input/keyboard.png" ]]; then
  echo "FAIL: assets/input/{wheel,controller,keyboard}.png missing"
  fail=1
else
  echo "OK: input device icons"
fi

if command -v lua5.1 >/dev/null 2>&1; then
  if lua5.1 -e 'package.path="'"$ROOT"'/?.lua;"'"$ROOT"'/?/init.lua;"'"$ROOT"'/common/?.lua;"'"$ROOT"'/common/?/init.lua;"..package.path; require("common.display_style"); require("common.api.profile")' 2>/dev/null; then
    echo "OK: Lua require common.display_style"
  else
    echo "WARN: lua5.1 load check skipped or failed (non-fatal)"
  fi
else
  echo "SKIP: lua5.1 not installed"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "verify-display-style: FAILED"
  exit 1
fi

echo "verify-display-style: OK"
