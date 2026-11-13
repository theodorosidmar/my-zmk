#!/usr/bin/env bash
# Build the Skeletyl firmware locally, in the same Docker image GitHub Actions uses.
#
#   scripts/build.sh          # both halves
#   scripts/build.sh left     # left (central) half only
#   scripts/build.sh right    # right half only
#
# Output: firmware/<shield>-nice_nano_v2-zmk.uf2 (gitignored).
# ZMK + Zephyr sources are cached in ~/.cache/zmk-workspace (a few GB; safe to
# delete, the next build downloads them again).
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=$PWD

IMAGE=zmkfirmware/zmk-build-arm:stable
BOARD=nice_nano_v2
WORKSPACE=${ZMK_WORKSPACE:-$HOME/.cache/zmk-workspace}

case "${1:-both}" in
  left|right) SIDES=("$1") ;;
  both) SIDES=(left right) ;;
  *) echo "usage: $0 [left|right|both]" >&2; exit 1 ;;
esac

mkdir -p "$WORKSPACE" firmware

# Inside the container:
#   /w            west workspace (zmk, zephyr, modules, build dirs), cached on the host
#   /w/config     this repo's config/ (keymap, .conf, west.yml)
docker run --rm \
  --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$WORKSPACE:/w" -v "$REPO/config:/w/config:ro" \
  -v "$REPO/firmware:/firmware" \
  -w /w "$IMAGE" bash -euo pipefail -c '
    if [[ ! -d .west ]]; then
      echo ">> First run: fetching ZMK and Zephyr (takes a while)"
      west init -l config
    fi
    # Re-fetch only when west.yml (the ZMK version) changed.
    if ! cmp -s config/west.yml .west/west.yml.last; then
      west update --fetch-opt=--filter=tree:0
      cp config/west.yml .west/west.yml.last
    fi
    west zephyr-export >/dev/null
    for side in '"${SIDES[*]}"'; do
      shield=corne_$side
      echo ">> Building $shield"
      west build -s zmk/app -d build/$side -b '"$BOARD"' -p auto -- \
        -DSHIELD=$shield -DZMK_CONFIG=/w/config
      cp build/$side/zephyr/zmk.uf2 /firmware/$shield-'"$BOARD"'-zmk.uf2
    done
  '
echo
ls -l firmware/
