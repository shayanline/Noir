#!/usr/bin/env bash
# Launch Inkfall in a phone-sized window for responsive UI testing.
#
# Usage:
#   ./tools/run_phone.sh              # default: iPhone 16 Pro (393x852)
#   ./tools/run_phone.sh se           # iPhone SE (375x667)
#   ./tools/run_phone.sh pro-max      # iPhone 16 Pro Max (430x932)
#   ./tools/run_phone.sh 390 844      # custom width x height
#
# The project's stretch mode (canvas_items + expand) handles the rest,
# and UIScale recomputes every responsive variable from the new viewport.

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"

# Presets (CSS logical pixels, matching real device viewport sizes)
case "${1:-pro}" in
    se)         W=375;  H=667  ;;
    mini)       W=375;  H=812  ;;
    pro)        W=393;  H=852  ;;
    pro-max)    W=430;  H=932  ;;
    air)        W=402;  H=874  ;;
    [0-9]*)     W="${1}"; H="${2:-844}" ;;
    *)          echo "Unknown preset: $1"; exit 1 ;;
esac

echo "Launching Inkfall at ${W}x${H} (portrait)..."
exec "$GODOT" --path . \
    --resolution "${W}x${H}" \
    --position 100,50
