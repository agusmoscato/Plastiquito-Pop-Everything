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

# Lint: carga todos los scripts con las advertencias de tipos como errores.
LINT_OUT="$("$GODOT_BIN" --headless -s tools/lint.gd 2>&1)"
if echo "$LINT_OUT" | grep -qE "LINT FAIL|SCRIPT ERROR: Parse"; then
  echo "$LINT_OUT" | grep -E -A1 "LINT FAIL|SCRIPT ERROR" >&2
  echo "run_tests: el lint falló" >&2
  exit 1
fi

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
if [ "$CODE" != "0" ]; then
  exit "$CODE"
fi

# Paso "balance": el simulador con los perfiles activo y casual, 3 semillas cada uno.
# Se puede saltear con SKIP_BALANCE=1 (por ejemplo, para iterar rápido en código sin tocar data/).
if [ "${SKIP_BALANCE:-0}" != "1" ]; then
  for PROFILE in active casual; do
    for SEED in 1 2 3; do
      if ! "$GODOT_BIN" --headless --path . --script tools/balance_sim.gd --           --profile=$PROFILE --minutes=46 --seed=$SEED > "$LOG.balance" 2>&1; then
        cat "$LOG.balance" >&2
        echo "run_tests: el simulador de balance falló ($PROFILE, semilla $SEED)" >&2
        exit 1
      fi
    done
  done
  echo "balance: activo y casual aprobados (3 semillas cada uno)"
fi
exit 0
