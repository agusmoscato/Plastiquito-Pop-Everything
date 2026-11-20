#!/usr/bin/env bash
# Informe de rendimiento SIN ventana: tabla de métricas y comparación con la línea de base (sección 8, 0.7.0).
# Uso: GODOT=/ruta/godot tools/perf_report.sh [minutos de corrida larga, por defecto 30]
# Genera tools/out/perf.json y tools/out/perf_report.md. Sale con 1 si alguna métrica empeora más de 15 %
# respecto de tools/perf_baseline.json (o rompe un objetivo: sim <= 2 ms, memoria <= +5 %).
# Los fps y draw calls reales salen del benchmark en modo CASA y de las líneas "PERF" de la prueba de humo en CI.
set -u
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT:-godot}"
MIN="${1:-30}"
mkdir -p tools/out
"$GODOT_BIN" --headless -s tools/perf_report.gd -- --minutes="$MIN" --out=res://tools/out/perf.json 2>&1 | grep -E "^==|^[a-z_]+ +[0-9\[]|^sim <=" 
python3 tools/ci/perf_compare.py tools/out/perf.json tools/perf_baseline.json tools/out/perf_report.md || python tools/ci/perf_compare.py tools/out/perf.json tools/perf_baseline.json tools/out/perf_report.md
