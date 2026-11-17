#!/usr/bin/env bash
# Revisa un log de Godot de CI. Imprime "APROBADO <nombre>" o "FALLÓ <nombre>" con las líneas culpables.
# Falla con ERROR, NaN, !v.is_finite(), SCRIPT ERROR, código de salida != 0 o (smoke) sin "SMOKE OK".
# Uso: tools/ci/check_log.sh <log> <nombre>
set -u
LOG="$1"
NAME="$2"
PROBLEMS="$(grep -nE 'ERROR|!v\.is_finite\(\)' "$LOG"; grep -niwE 'nan' "$LOG")"
CODE="$(grep -oE '^exit_code=[0-9]+' "$LOG" | tail -n1 | cut -d= -f2)"
FAIL=0
[ -n "$PROBLEMS" ] && FAIL=1
[ "${CODE:-1}" != "0" ] && FAIL=1
if [ "$NAME" = "smoke" ] && ! grep -q "SMOKE OK" "$LOG"; then FAIL=1; PROBLEMS="$PROBLEMS
(no apareció SMOKE OK)"; fi
if [ "$FAIL" = "1" ]; then
  echo "FALLÓ $NAME (exit_code=${CODE:-?})"
  echo "$PROBLEMS" | sort | uniq -c | sort -rn | head -n 40
  exit 1
fi
echo "APROBADO $NAME"
grep -E "SMOKE OK" "$LOG" || true
