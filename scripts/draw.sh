#!/usr/bin/env bash
# Regenerates the layer images in img/ from config/corne.keymap.
# Needs keymap-drawer: `pipx install keymap-drawer` (or set KEYMAP=/path/to/keymap).
set -euo pipefail
cd "$(dirname "$0")/.."
KEYMAP=${KEYMAP:-keymap}
LAYERS=(Base Mouse Nav Sym-R Sym-L Fn Num Always)

# The firmware uses the 42-key Corne shield, but the Skeletyl only has 36 keys:
# drop the unused outer columns and draw on the real Skeletyl physical layout.
"$KEYMAP" -c scripts/keymap_drawer.yaml parse -z config/corne.keymap -l "${LAYERS[@]}" \
  | python3 -c '
import sys
outer = {0, 11, 12, 23, 24, 35}
out = []
for line in sys.stdin:
    if line.startswith("layout:"):
        line = "layout: {qmk_keyboard: bastardkb/skeletyl/promicro, layout_name: LAYOUT_split_3x5_3}\n"
    elif line.startswith("  ") and not line.startswith("  -"):
        idx = 0
    elif line.startswith("  - "):
        idx += 1
        if idx - 1 in outer:
            continue
    out.append(line)
sys.stdout.write("".join(out))
' > img/keymap.yaml
"$KEYMAP" -c scripts/keymap_drawer.yaml draw img/keymap.yaml > img/keymap.svg
for i in "${!LAYERS[@]}"; do
  "$KEYMAP" -c scripts/keymap_drawer.yaml draw img/keymap.yaml -s "${LAYERS[$i]}" > "img/layer$i.svg"
done
echo "Images written to img/"
