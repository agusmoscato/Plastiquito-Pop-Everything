extends SceneTree
## Informe de rendimiento SIN ventana (sección 8 de la 0.7.0). Mide lo que se puede medir en --headless:
##   - costo de la simulación por frame en el peor caso (lámina de 1000x1000, plancha, bota, manitos y rodillo a
##     la vez, cadenas masivas),
##   - tiempo de carga de los datos y de armar una partida,
##   - memoria estática al arrancar y después de una corrida larga acelerada (búsqueda de fugas),
##   - cantidad de objetos y de nodos de la escena principal y de la utilería de cada escenario.
## Los fps reales, los draw calls y las partículas activas dependen de la GPU: se miden con el benchmark en
## modo CASA (docs/BENCHMARK_FASE3.md) y con las capturas de CI.
## Uso: godot --headless -s tools/perf_report.gd [-- --minutes=30 --out=tools/out/perf.json]

const WORST_FRAMES: int = 240

var minutes: float = 30.0
var out_path: String = "res://tools/out/perf.json"
var report: Dictionary = {}


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var db: DataDB = _load_db()
	_measure_worst_case(db)
	_measure_leaks(db)
	_write()
	quit(0)


func _load_db() -> DataDB:
	var t0: int = Time.get_ticks_usec()
	var db: DataDB = DataDB.new()
	db.load_all()
	report["load_data_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	var t1: int = Time.get_ticks_usec()
	var s: GameSim = GameSim.new(db, 1)
	report["new_game_ms"] = float(Time.get_ticks_usec() - t1) / 1000.0
	var t2: int = Time.get_ticks_usec()
	s.save_dict()
	report["save_ms"] = float(Time.get_ticks_usec() - t2) / 1000.0
	return db


## Peor caso: 1000x1000, todas las herramientas desbloqueadas y las automatizaciones prendidas.
func _worst_sim(db: DataDB) -> GameSim:
	var sim: GameSim = GameSim.new(db, 3)
	for id: String in ["global_hold", "unlock_palm", "unlock_pin", "unlock_iron", "unlock_boot", "unlock_hands", "unlock_roller"]:
		sim.state.levels[id] = 1
	sim.state.levels["hands_count"] = 12
	sim.state.levels["global_chain"] = 3
	sim.state.perm["perm_sheet"] = 3
	sim.refresh_stats()
	sim.sheet = SheetModel.new(1000, 1000)
	sim.grid = HexGrid.new(1000, 1000, Cfg.num(db.sheet, "bubble_radius"))
	sim._build_models()
	sim._apply_to_sheet()
	return sim


func _measure_worst_case(db: DataDB) -> void:
	var sim: GameSim = _worst_sim(db)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var tools: Array[String] = ["finger", "palm", "rolling_pin", "iron", "boot"]
	var times: Array[float] = []
	var pointer: Vector2 = sim.center()
	for f: int in WORST_FRAMES:
		sim.select_tool(tools[(f / 48) % tools.size()])
		pointer += Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-3.0, 3.0))
		var t0: int = Time.get_ticks_usec()
		sim.step(1.0 / 60.0, pointer, f % 2 == 0)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	var total: float = 0.0
	for v: float in times:
		total += v
	report["sim_step_avg_ms"] = total / float(times.size())
	report["sim_step_p95_ms"] = times[int(float(times.size()) * 0.95)]
	report["sim_step_max_ms"] = times[times.size() - 1]


## 30 minutos de juego acelerado: la memoria estática no puede crecer más de 5 %.
func _measure_leaks(db: DataDB) -> void:
	var sim: GameSim = GameSim.new(db, 5)
	for id: String in ["global_hold", "global_reload", "unlock_palm", "unlock_pin", "unlock_iron", "unlock_boot", "unlock_hands", "unlock_roller"]:
		sim.state.levels[id] = 1
	sim.state.perm["perm_sheet"] = 2
	sim.refresh_stats()
	sim.new_sheet()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var dt: float = 0.1
	var steps: int = int(minutes * 60.0 / dt)
	var tools: Array[String] = ["finger", "palm", "rolling_pin", "iron", "boot"]
	for i: int in 200: # calentamiento: que los cachés y pools lleguen a su tamaño normal
		sim.step(dt, sim.center(), true)
	var mem_start: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	report["mem_start_mb"] = mem_start / 1048576.0
	report["objects_start"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	for i: int in steps:
		if i % 300 == 0:
			sim.select_tool(tools[rng.randi() % tools.size()])
		if sim.awaiting_reload:
			sim.request_reload()
		var cell: int = rng.randi() % sim.sheet.cell_count()
		sim.step(dt, sim.grid.cell_to_world(cell), i % 2 == 0)
		if sim.state.sheets_done > 0 and i % 6000 == 0:
			sim.state.pops_run = 1.0e12
			sim.recycle()
	var mem_end: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	report["mem_end_mb"] = mem_end / 1048576.0
	report["mem_growth_pct"] = 100.0 * (mem_end - mem_start) / maxf(mem_start, 1.0)
	report["objects_end"] = Performance.get_monitor(Performance.OBJECT_COUNT)


## Nodos de la escena principal y de la utilería de cada escenario (instanciando la escena sin dibujar).
func _measure_scene() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if ps == null:
		return
	var t0: int = Time.get_ticks_usec()
	var main: Node = ps.instantiate()
	root.add_child(main)
	report["main_scene_instantiate_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
	report["nodes_main"] = _count(main)
	var per_phase: Array[float] = []
	var world: Node = main.find_child("World", true, false)
	if world != null and world.has_method("apply_phase"):
		for ph: int in range(1, 5):
			var t1: int = Time.get_ticks_usec()
			world.call("apply_phase", ph)
			per_phase.append(float(Time.get_ticks_usec() - t1) / 1000.0)
	report["scenario_switch_ms"] = per_phase
	report["nodes_total"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	main.queue_free()


func _count(n: Node) -> int:
	var total: int = 1
	for c: Node in n.get_children():
		total += _count(c)
	return total


func _write() -> void:
	var path: String = ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
	print("== PERF ==")
	for key: String in report:
		print("%-28s %s" % [key, str(report[key])])
	var sim_ms: float = report["sim_step_avg_ms"] if report.has("sim_step_avg_ms") else 99.0
	var growth: float = report["mem_growth_pct"] if report.has("mem_growth_pct") else 99.0
	print("sim <= 2 ms (media): %s   |   memoria <= +5 %%: %s" % ["OK" if sim_ms <= 2.0 else "FALLA", "OK" if growth <= 5.0 else "FALLA"])
