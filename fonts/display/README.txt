Display fonts — Google Fonts (SIL Open Font License)

Used for player/rival display_style names (fontId registry v1):
- Rajdhani (Regular, SemiBold, Bold)
- Orbitron (variable)
- Teko (variable)
- Bebas Neue (Regular)
- Oxanium (variable)
- Chakra Petch (Regular, SemiBold, Bold)
- Audiowide (Regular)

License: see OFL.txt in this folder.

Refresh fonts:
  ./scripts/download-display-fonts.sh

v1 limitations (see common/display_style.lua):
- Gradient/chrome effects are static DWrite approximations, not identical to web CSS.
- Animated effects (taillight pulse, speed skew) render as static.
- italic only when the TTF supports :Italic; otherwise ignored.
- letterSpacing fine tracking is ignored.

Legacy font ids (system, inter, mono, …) map to Rajdhani like the web app.
