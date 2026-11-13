#!/usr/bin/env bash
# Corre perfiles sueltos: GODOT=... tools/bal.sh active idle [semilla] (minutos 215, dt 20)
cd "$(dirname "$0")/.."
SEED="${SEED:-1}"
for P in "$@"; do
  "${GODOT:-godot}" --headless --path . --script tools/balance_sim.gd -- --profile=$P --minutes=215 --seed=$SEED --dt=20 2>&1 | grep -E "^==|^   |ERROR|SCRIPT" 
done
