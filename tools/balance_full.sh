#!/usr/bin/env bash
# Simulador de balance hasta 3 h 30 (activo, casual e idle, semilla 1). Tarda unos 5 minutos.
# A diferencia del paso "balance" de run_tests.sh (45 min, fases 1 y 2), este chequea las
# métricas de las fases 3 y 4. Uso: GODOT=/ruta/godot ./tools/balance_full.sh
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
STATUS=0
for PROFILE in active casual idle; do
  "$GODOT_BIN" --headless --path . --script tools/balance_sim.gd -- --profile=$PROFILE --minutes=215 --seed=1 --dt=20 2>&1 \
    | grep -E "^==|^   " || true
  [ "${PIPESTATUS[0]}" = "0" ] || STATUS=1
done
exit $STATUS
