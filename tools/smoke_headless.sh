#!/usr/bin/env bash
# Prueba de humo SIN ventana: el bot juega el juego real con --headless (sin render, sin capturas).
# Sirve en la PC del dueño para detectar errores de script, NaN y errores del motor en la lógica.
# Las capturas y el render real se hacen en GitHub Actions (render.yml).
# Uso: GODOT=/ruta/godot tools/smoke_headless.sh [minutos]   (por defecto 4)
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
MIN="${1:-4}"
mkdir -p tools/out
LOG=tools/out/smoke_headless.txt
"$GODOT_BIN" --headless --path . --audio-driver Dummy --fixed-fps 30 -- --smoke=tools/out/smoke --minutes="$MIN" > "$LOG" 2>&1
echo "exit_code=$?" >> "$LOG"
grep -E "SMOKE OK|salto de fase" "$LOG"
bash tools/ci/check_log.sh "$LOG" smoke
