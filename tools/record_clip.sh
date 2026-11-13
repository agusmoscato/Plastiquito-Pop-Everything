#!/usr/bin/env bash
# Graba una escena de scenes/clips/ con el Movie Maker de Godot (60 fps, con audio).
# Uso: tools/record_clip.sh <clip> [vertical|horizontal]
#   <clip>: 1, 2, 3, 4 (o el nombre completo, por ejemplo clip_1_zoom_out)
#   vertical (por defecto) = 1080x1920 para shorts; horizontal = 1920x1080.
# Deja el archivo en builds/clips/<clip>_<formato>.avi. Usa $GODOT o "godot" del PATH.
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
CLIP="${1:?falta el clip: 1, 2, 3 o 4}"
FORMAT="${2:-vertical}"

case "$CLIP" in
  1) NAME="clip_1_zoom_out" ;;
  2) NAME="clip_2_pin_wave" ;;
  3) NAME="clip_3_iron_bomb" ;;
  4) NAME="clip_4_transition" ;;
  *) NAME="$CLIP" ;;
esac
[ -f "scenes/clips/$NAME.tscn" ] || { echo "no existe scenes/clips/$NAME.tscn" >&2; exit 1; }

if [ "$FORMAT" = "horizontal" ]; then RES="1920x1080"; else RES="1080x1920"; fi
mkdir -p builds/clips
OUT="builds/clips/${NAME}_${FORMAT}.avi"

"$GODOT_BIN" --path . --write-movie "$OUT" --fixed-fps 60 --resolution "$RES" "scenes/clips/$NAME.tscn"
echo "listo: $OUT ($(( ($(stat -c %s "$OUT") + 524288) / 1048576 )) MB)"
