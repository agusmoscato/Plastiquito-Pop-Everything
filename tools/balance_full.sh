#!/usr/bin/env bash
# Simulador de balance hasta 3 h 35 (activo, casual e idle) con varias semillas. Tarda ~20 minutos
# con 3 semillas. A diferencia del paso "balance" de run_tests.sh (45 min, fases 1 y 2), este chequea
# las métricas de las fases 3 y 4. El idle se compara con el activo de la misma semilla, así que el
# activo corre primero.
# Uso: GODOT=/ruta/godot ./tools/balance_full.sh            (semillas 1 2 3)
#      SEEDS="1" PROFILES="active idle" ./tools/balance_full.sh
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
SEEDS="${SEEDS:-1 2 3}"
PROFILES="${PROFILES:-active casual idle}"
STATUS=0
for SEED in $SEEDS; do
  for PROFILE in $PROFILES; do
    OUT="$("$GODOT_BIN" --headless --path . --script tools/balance_sim.gd -- --profile=$PROFILE --minutes=215 --seed=$SEED --dt=20 2>&1)"
    CODE=$?
    echo "$OUT" | grep -E "^==|^   " || true
    if [ "$CODE" != "0" ] || echo "$OUT" | grep -qE "FALLÓ|SCRIPT ERROR"; then STATUS=1; fi
  done
done
[ "$STATUS" = "0" ] && echo "balance_full: TODO APROBADO" || echo "balance_full: hay métricas que fallan"
exit $STATUS
