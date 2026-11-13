#!/usr/bin/env bash
# Regenera todos los .glb y los renders de control. BLENDER=<ruta> para otro ejecutable (hoy 4.5.10 LTS).
cd "$(dirname "$0")/.."
BL="${BLENDER:-/c/Program Files/Blender Foundation/Blender 4.5/blender.exe}"
OUT="$(pwd)/assets/models"
REN="$(pwd)/art/renders"
mkdir -p "$OUT" "$REN"
run() { # script nombre-de-salida [args extra]
  local script="$1" name="$2"; shift 2
  echo "== $name"
  "$BL" -b --factory-startup -P "art/models/$script.py" -- --out "$OUT/$name.glb" --render "$REN" "$@" 2>&1 \
    | grep -E "TRIS|Error|Traceback|error|File \"" || true
}
run hand hand_ghost --no-arm
for m in hand pin iron boot roller; do run "$m" "$m"; done
for w in gem bomb line; do run specials "special_$w" --which "$w"; done
for w in cup pencil chair_leg shelf cone; do run props "prop_$w" --which "$w"; done
