"""Compara tools/out/perf.json con la línea de base y escribe la tabla en Markdown.
Alerta (exit 1) si una métrica empeora más de 15 % o rompe un objetivo duro."""
import json
import os
import sys

cur_path, base_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
cur = json.load(open(cur_path, encoding="utf-8"))
base = json.load(open(base_path, encoding="utf-8")) if os.path.exists(base_path) else {}
# métrica -> (objetivo duro o None). Todas "menos es mejor".
GOALS = {"sim_step_avg_ms": 2.0, "mem_growth_pct": 5.0, "load_data_ms": 5000.0, "new_game_ms": 2000.0}
LOWER_IS_BETTER = ["sim_step_avg_ms", "sim_step_p95_ms", "load_data_ms", "new_game_ms", "save_ms", "mem_end_mb", "objects_end"]
rows = ["| Métrica | Ahora | Línea de base | Cambio | Estado |", "| --- | --- | --- | --- | --- |"]
bad = False
for k, v in cur.items():
    if not isinstance(v, (int, float)):
        continue
    b = base.get(k)
    state = "ok"
    change = ""
    if isinstance(b, (int, float)) and b > 0:
        pct = 100.0 * (v - b) / b
        change = "%+.1f %%" % pct
        # un piso de 0,05 ms/MB evita alertar por ruido en valores diminutos
        if k in LOWER_IS_BETTER and pct > 15.0 and (v - b) > 0.05:
            state = "EMPEORÓ >15 %"
            bad = True
    if k in GOALS and v > GOALS[k]:
        state = "FALLA OBJETIVO (<= %s)" % GOALS[k]
        bad = True
    rows.append("| %s | %.3f | %s | %s | %s |" % (k, v, "%.3f" % b if isinstance(b, (int, float)) else "-", change, state))
open(out_path, "w", encoding="utf-8").write("\n".join(rows) + "\n")
print("\n".join(rows))
sys.exit(1 if bad else 0)
