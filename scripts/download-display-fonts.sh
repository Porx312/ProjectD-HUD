#!/usr/bin/env bash
# Download Google Fonts (OFL) into ProjectD-HUD/fonts/display/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/fonts/display"
BASE="https://github.com/google/fonts/raw/main/ofl"

mkdir -p "$DEST"

fetch() {
  local repo="$1"
  local remote_name="$2"
  local local_name="${3:-$remote_name}"
  local url="$BASE/$repo/$remote_name"
  echo "→ $local_name"
  curl -fsSL "$url" -o "$DEST/$local_name"
}

fetch rajdhani Rajdhani-Regular.ttf
fetch rajdhani Rajdhani-SemiBold.ttf
fetch rajdhani Rajdhani-Bold.ttf

fetch orbitron "Orbitron%5Bwght%5D.ttf" Orbitron-Variable.ttf
fetch teko "Teko%5Bwght%5D.ttf" Teko-Variable.ttf
fetch bebasneue BebasNeue-Regular.ttf
fetch oxanium "Oxanium%5Bwght%5D.ttf" Oxanium-Variable.ttf

fetch chakrapetch ChakraPetch-Regular.ttf
fetch chakrapetch ChakraPetch-SemiBold.ttf
fetch chakrapetch ChakraPetch-Bold.ttf

fetch audiowide Audiowide-Regular.ttf

curl -fsSL "$BASE/rajdhani/OFL.txt" -o "$DEST/OFL.txt"

echo "Done: $(ls -1 "$DEST"/*.ttf 2>/dev/null | wc -l) TTF files in $DEST"
