#!/usr/bin/env bash
# Build the Skeletyl firmware locally (scripts/build.sh) and flash it.
# No commit or push needed: it uses whatever is in config/ right now.
#
#   scripts/flash.sh        # left (central) half only – enough for keymap changes
#   scripts/flash.sh right  # right half only
#   scripts/flash.sh both   # left, then right
#
# Needs: docker, udisksctl.
set -euo pipefail
cd "$(dirname "$0")/.."

ARG=${1:-left}
case "$ARG" in
  left|right) SIDES=("$ARG") ;;
  both) SIDES=(left right) ;;
  *) echo "usage: $0 [left|right|both]" >&2; exit 1 ;;
esac

LABEL=NICENANO # volume label of the nice!nano bootloader drive

scripts/build.sh "$ARG"

flash_side() {
  local side=$1 uf2 dev mnt
  uf2=firmware/corne_${side}-nice_nano_v2-zmk.uf2
  [[ -f "$uf2" ]] || { echo "Missing $uf2" >&2; exit 1; }

  echo
  echo ">> Plug in the ${side^^} half via USB and double-tap its reset button."
  echo "   Waiting for the $LABEL drive..."
  until dev=$(lsblk -rpno NAME,LABEL | awk -v l="$LABEL" '$2 == l {print $1; exit}') && [[ -n "$dev" ]]; do
    sleep 0.5
  done

  mnt=$(lsblk -rno MOUNTPOINT "$dev")
  if [[ -z "$mnt" ]]; then
    udisksctl mount -b "$dev" >/dev/null
    mnt=$(lsblk -rno MOUNTPOINT "$dev")
  fi

  echo "   Copying $(basename "$uf2") to $mnt"
  # The board reboots as soon as the file lands, so errors after copying are harmless.
  cp "$uf2" "$mnt/" 2>/dev/null || true
  sync 2>/dev/null || true

  # Wait for the drive to disappear so the next side isn't mistaken for this one.
  while lsblk -rpno NAME,LABEL | awk -v l="$LABEL" '$2 == l {f=1} END {exit !f}'; do sleep 0.5; done
  echo "   ${side^} half flashed."
}

for side in "${SIDES[@]}"; do flash_side "$side"; done
echo
echo "Done."
