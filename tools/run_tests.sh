#!/usr/bin/env bash
# Corre todos los tests GUT sin pantalla. Sale con código != 0 si alguno falla.
# Usa $GODOT si está definido; si no, "godot" del PATH.
set -u
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT:-godot}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Importar primero para que se registren los class_name (cache de scripts globales).
"$GODOT_BIN" --headless --import >/dev/null 2>&1

"$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json -gexit 2>&1 | tee "$LOG"
CODE=${PIPESTATUS[0]}

# Red de seguridad: errores de parseo o tests fallidos aunque el exit code sea 0.
if grep -qE "SCRIPT ERROR|Parse Error|^Failing Tests|Failing +[1-9]|Failures +[1-9]" "$LOG"; then
  echo "run_tests: se detectaron fallos o errores" >&2
  exit 1
fi
if ! grep -qE "Passing Tests|Passing +[0-9]|Tests +[0-9]+" "$LOG"; then
  echo "run_tests: no se encontró el resumen de GUT (¿no corrieron los tests?)" >&2
  exit 1
fi
exit "$CODE"
