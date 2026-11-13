extends SceneTree
## Simulador de balance v1. Usa la MISMA sim que el juego (GameSim: SheetModel, ChainSolver,
## Economy, Prestige...) con un jugador bot. Sin pantalla:
##   godot --headless --script tools/balance_sim.gd -- --profile=active|casual|idle --minutes=60 --seed=N
## Escribe tools/out/balance_<perfil>_<seed>.csv y un resumen APROBADO/FALLÓ por métrica
## (sección 6 de la Fase 2). Sale con código 1 si alguna métrica falla (perfiles activo y casual).

const DT: float = 1.0 / 30.0
const OUT_DIR: String = "res://tools/out"

var profile: String = "active"
var minutes: float = 60.0
var seed_value: int = 1

var sim: GameSim
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pointer: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var has_target: bool = false
var click_timer: float = 0.0
var press_timer: float = 0.0
var click_cell: int = -1

# Registro
var csv: PackedStringArray = PackedStringArray(["segundo,evento,detalle,pops,pops_por_s"])
var purchase_times: Array[float] = []
var first_chain10: float = -1.0
var first_golden: float = -1.0
var palm_time: float = -1.0
var pin_time: float = -1.0
var phase2_time: float = -1.0
var first_recycle: float = -1.0
var max_dry_gap: float = 0.0
var max_dry_at: float = 0.0
var near_buy_time: float = 0.0
var counted_time: float = 0.0
var _dry_since: float = -1.0
var _income_window: Array[Vector2] = [] ## (tiempo, pops acumulados)
var _next_decision: float = 0.0
var _next_minute_log: float = 60.0
var total_pop_events: int = 0
var tool_pop_events: int = 0
var chain_events: int = 0


func _initialize() -> void:
	_parse_args()
	var db: DataDB = DataDB.new()
	if not db.load_all():
		print("balance_sim: data inválida: ", "; ".join(db.errors))
		quit(2)
		return
	rng.seed = seed_value
	sim = GameSim.new(db, seed_value)
	pointer = sim.center()
	var t0: int = Time.get_ticks_msec()
	_run()
	var wall: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var ok: bool = _report(wall)
	_write_csv()
	quit(0 if ok else 1)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			profile = arg.trim_prefix("--profile=")
		elif arg.begins_with("--minutes="):
			minutes = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))


func _run() -> void:
	var steps: int = int(minutes * 60.0 / DT)
	for i: int in steps:
		_bot_input()
		var was_phase: int = sim.phase()
		sim.step(DT, pointer, press_timer > 0.0)
		_after_step(was_phase)
		if profile != "idle":
			_decide()
		_track_availability()


# --- Bot -------------------------------------------------------------------------------

func _bot_input() -> void:
	if profile == "idle":
		return
	if profile == "active":
		_move_active()
	else:
		_move_casual()


## Activo: ~8 clics por segundo con buen apunte (tensas y especiales primero). Con el palo
## de amasar barre filas arrastrando. Suelta entre clics para no contar como arrastre.
func _move_active() -> void:
	if sim.state.selected_tool == "rolling_pin":
		_sweep_with_pin()
		return
	click_timer -= DT
	if press_timer > 0.0:
		press_timer -= DT
		if not _still_pressing():
			press_timer = 0.0
		return
	if click_timer > 0.0:
		return
	click_cell = _pick_cell(sim.grid.spacing * 5.0)
	pointer = sim.grid.cell_to_world(click_cell)
	press_timer = 0.5
	click_timer = 1.0 / 8.0


func _sweep_with_pin() -> void:
	press_timer = 1.0
	if not has_target or pointer.distance_to(target) < sim.grid.spacing * 0.6:
		var row_cell: int = _pick_cell(sim.grid.spacing * 8.0)
		var y: float = sim.grid.cell_to_world(row_cell).y
		var x_far: float = sim.grid.spacing * float(sim.grid.width) + 1.0 if pointer.x < sim.center().x else -1.0
		target = Vector2(x_far, y)
		pointer = Vector2(pointer.x, y)
		has_target = true
	pointer = pointer.move_toward(target, sim.grid.spacing * 7.0 * DT)


## Sigue apretando mientras quede algo por reventar bajo la herramienta (la palma espera a
## que cedan casi todas las burbujas de su círculo).
func _still_pressing() -> bool:
	if click_cell < 0:
		return false
	var tm: ToolModel = sim.selected_tool()
	if tm.shape != "circle" or tm.radius <= 0.0:
		return sim.sheet.state[click_cell] != SheetModel.STATE_POPPED
	var left: int = 0
	for n: int in sim.grid.cells_in_circle(sim.grid.cell_to_world(click_cell), tm.radius):
		if sim.sheet.state[n] != SheetModel.STATE_POPPED:
			left += 1
	return left > 2


## Casual: ~3 clics por segundo cerca del centro. Mira la lámina: casi siempre elige una
## burbuja entera cercana al punto al que apuntaba (a veces falla y clickea una reventada).
func _move_casual() -> void:
	click_timer -= DT
	press_timer -= DT
	if click_timer <= 0.0:
		var c: Vector2 = sim.center()
		var ext: Vector2 = Vector2(sim.grid.spacing * float(sim.grid.width), sim.grid.row_step * float(sim.grid.height))
		pointer = c + Vector2(rng.randfn(0.0, ext.x * 0.22), rng.randfn(0.0, ext.y * 0.22))
		if rng.randf() < 0.85:
			var idx: int = _pick_cell(sim.grid.spacing * 2.5)
			pointer = sim.grid.cell_to_world(idx)
		press_timer = 0.28
		click_timer = 1.0 / 3.0


## Mejor celda cercana al cursor: especiales y tensas primero, luego la más próxima. Con
## herramientas de área prefiere donde hay más burbujas enteras alrededor.
func _pick_cell(search: float) -> int:
	var best: int = -1
	var best_score: float = -1.0e9
	var area: float = sim.selected_tool().radius
	for idx: int in sim.grid.cells_in_circle(pointer, search):
		var st: int = sim.sheet.state[idx]
		if st == SheetModel.STATE_POPPED:
			continue
		var score: float = 1.0 - sim.grid.cell_to_world(idx).distance_to(pointer) * 0.05
		if st == SheetModel.STATE_TENSE:
			score += 3.0
		if sim.sheet.type[idx] != 0:
			score += 5.0
		if area > 0.0 and sim.state.selected_tool == "palm":
			for n: int in sim.grid.cells_in_circle(sim.grid.cell_to_world(idx), area):
				if sim.sheet.state[n] != SheetModel.STATE_POPPED:
					score += 0.5
		score += rng.randf() * 3.0 # elige repartido: así se acumula tensión en vez de barrer
		if score > best_score:
			best_score = score
			best = idx
	if best >= 0:
		return best
	for k: int in 80:
		var idx: int = rng.randi() % sim.sheet.cell_count()
		if sim.sheet.state[idx] != SheetModel.STATE_POPPED:
			return idx
	return 0


## Compra la mejora de mejor retorno estimado por Pop gastado; recicla cuando conviene.
func _decide() -> void:
	if sim.now < _next_decision:
		return
	_next_decision = sim.now + 0.5
	_pick_tool()
	if sim.can_recycle() and _should_recycle():
		_do_recycle()
	_buy_best()


func _pick_tool() -> void:
	for id: String in ["rolling_pin", "palm", "finger"]:
		if sim.select_tool(id):
			return


func _should_recycle() -> bool:
	# Primer reciclado en cuanto da 1 Pellet; los siguientes cuando rinden bastante más.
	return sim.recycle_gain() >= 1 + 3 * sim.state.recycles


func _do_recycle() -> void:
	var before: float = sim.state.pops_run
	var gained: int = sim.recycle()
	_log("reciclar", "pellets=%d pops_corrida=%.0f" % [gained, before])
	if first_recycle < 0.0:
		first_recycle = sim.now
	for id: String in ["perm_sheet", "perm_bonus", "perm_finger", "perm_golden"]:
		var r: Dictionary = sim.buy(id, -1)
		var n: int = r["bought"]
		if n > 0:
			_log("compra_perm", "%s x%d" % [id, n])
	if sim.phase() >= 2 and phase2_time < 0.0:
		phase2_time = sim.now
		_log("hito", "fase 2 (Piso)")
	has_target = false
	click_cell = -1
	press_timer = 0.0


## Ganancia relativa aproximada de cada tipo de mejora (juicio del bot, no balance del juego).
func _gain(kind: String, level: int) -> float:
	match kind:
		"unlock":
			return 0.9
		"force":
			return 0.18
		"value":
			return 0.14
		"size":
			return 0.22 / (1.0 + float(level) * 0.3)
		"speed":
			return 0.07
		"special":
			return 0.04
		"chain_k":
			return 0.08
		"special_chance":
			return 0.03
		"tense":
			return 0.05
		"sheet_growth":
			return 0.09
		"auto_reload":
			return 0.06
	return 0.02


func _buy_best() -> void:
	var best_id: String = ""
	var best_score: float = 0.0
	var affordable_best: String = ""
	var affordable_score: float = 0.0
	for id: String in sim.upgrades.order:
		if sim.upgrades.is_perm(id) or not sim.upgrades.is_available(sim.state, id):
			continue
		var level: int = sim.state.level(id)
		if level >= sim.upgrades.max_level(id):
			continue
		var d: Dictionary = sim.upgrades.def(id)
		var cost: float = sim.upgrades.next_cost(id, level)
		var score: float = _gain(str(d["kind"]), level) / cost
		if score > best_score:
			best_score = score
			best_id = id
		if cost <= sim.state.pops and score > affordable_score:
			affordable_score = score
			affordable_best = id
	if best_id != "" and str(sim.upgrades.def(best_id)["kind"]) == "unlock" and affordable_best != best_id:
		var income: float = _income_per_s()
		var missing: float = sim.upgrades.next_cost(best_id, 0) - sim.state.pops
		if income > 0.0 and missing / income < 90.0:
			return # un humano ahorra para desbloquear la herramienta
	if affordable_best.is_empty():
		return
	# Compra lo mejor que pueda pagar si no es mucho peor que lo mejor absoluto (si no, ahorra).
	if affordable_best == best_id or affordable_score >= best_score * 0.15:
		_purchase(affordable_best)


func _purchase(id: String) -> void:
	var level: int = sim.state.level(id)
	var r: Dictionary = sim.buy(id, 1)
	var n: int = r["bought"]
	if n <= 0:
		return
	purchase_times.append(sim.now)
	_log("compra", "%s nivel %d" % [id, level + 1])
	var ms: bool = r["milestone"]
	if ms:
		_log("hito", "%s nivel %d (x2)" % [id, level + 1])
	if id == "unlock_palm" and palm_time < 0.0:
		palm_time = sim.now
	elif id == "unlock_pin" and pin_time < 0.0:
		pin_time = sim.now


# --- Seguimiento --------------------------------------------------------------------------

func _after_step(_was_phase: int) -> void:
	total_pop_events += sim.ev_idx.size()
	tool_pop_events += sim.ev_tool_pops
	if sim.ev_chain_ended_count >= 10:
		chain_events += 1
	if sim.ev_chain_ended_count >= 10 and first_chain10 < 0.0:
		first_chain10 = sim.now
		_log("primera_cadena_10", str(sim.ev_chain_ended_count))
	if sim.chain_count >= 10 and first_chain10 < 0.0:
		first_chain10 = sim.now
	if first_golden < 0.0:
		for t: int in sim.ev_type:
			if t == GameSim.TYPE_GOLDEN:
				first_golden = sim.now
				_log("primera_dorada", "")
				break
	if sim.ev_reloaded:
		click_cell = -1
		press_timer = 0.0
		_log("lamina_nueva", "%dx%d" % [sim.sheet.width, sim.sheet.height])
	if sim.now >= _next_minute_log:
		_next_minute_log += 60.0
		_log("minuto", "")


func _income_per_s() -> float:
	_income_window.append(Vector2(sim.now, sim.state.pops_total))
	while _income_window.size() > 2 and _income_window[0].x < sim.now - 20.0:
		_income_window.pop_front()
	var a: Vector2 = _income_window[0]
	var span: float = sim.now - a.x
	if span < 1.0:
		return 0.0
	return (sim.state.pops_total - a.y) / span


## "Siempre hay algo por comprar": una mejora pagable, o pagable en menos de 30 s de ingreso.
func _track_availability() -> void:
	if sim.now > 45.0 * 60.0:
		return
	var income: float = _income_per_s()
	var affordable_now: bool = false
	var near: bool = false
	for id: String in sim.upgrades.order:
		if sim.upgrades.is_perm(id) or not sim.upgrades.is_available(sim.state, id):
			continue
		var level: int = sim.state.level(id)
		if level >= sim.upgrades.max_level(id):
			continue
		var cost: float = sim.upgrades.next_cost(id, level)
		if cost <= sim.state.pops:
			affordable_now = true
			break
		if income > 0.0 and (cost - sim.state.pops) / income <= 30.0:
			near = true
	counted_time += DT
	if affordable_now or near:
		near_buy_time += DT
	if affordable_now:
		_dry_since = -1.0
	else:
		if _dry_since < 0.0:
			_dry_since = sim.now
		if sim.now - _dry_since > max_dry_gap:
			max_dry_gap = sim.now - _dry_since
			max_dry_at = sim.now


func _log(kind: String, detail: String) -> void:
	var per_s: float = _income_per_s()
	csv.append("%.1f,%s,%s,%.0f,%.1f" % [sim.now, kind, detail.replace(",", ";"), sim.state.pops, per_s])


func _write_csv() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path: String = OUT_DIR.path_join("balance_%s_%d.csv" % [profile, seed_value])
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(csv) + "\n")
		f.close()


# --- Métricas ----------------------------------------------------------------------------------

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var s: Array[float] = values.duplicate()
	s.sort()
	return s[s.size() >> 1]


func _gaps(from_s: float, to_s: float) -> Array[float]:
	var out: Array[float] = []
	for i: int in range(1, purchase_times.size()):
		var t: float = purchase_times[i]
		if t >= from_s and t < to_s:
			out.append(t - purchase_times[i - 1])
	return out


func _report(wall: float) -> bool:
	print("== balance_sim perfil=%s minutos=%.0f semilla=%d (%.1f s de reloj)" % [profile, minutes, seed_value, wall])
	var tm: ToolModel = sim.selected_tool()
	print("   estado: herramienta=%s forma=%s radio=%.2f fuerza=%.2f lámina %d%% reventada, cursor=%s objetivo=%s" % [sim.state.selected_tool, tm.shape, tm.radius, tm.force_per_second, int(sim.sheet.popped_ratio() * 100.0), str(pointer), str(target)])
	print("   pops_total=%.0f pops=%.0f compras=%d cadena_max=%d reciclados=%d" % [
		sim.state.pops_total, sim.state.pops, purchase_times.size(), sim.state.max_chain, sim.state.recycles])
	print("   reventones=%d (herramienta %d, %.0f%% por cadena) cadenas>=10: %d" % [total_pop_events, tool_pop_events, 100.0 * float(total_pop_events - tool_pop_events) / maxf(float(total_pop_events), 1.0), chain_events])
	if profile == "idle":
		print("   (idle: sin métricas)")
		return true
	var checks: Array[Array] = []
	var early: float = _median(_gaps(0.0, 600.0))
	var late: float = _median(_gaps(600.0, 2700.0))
	checks.append(["mediana entre compras 0-10 min", "15-40 s", early, early >= 15.0 and early <= 40.0])
	checks.append(["mediana entre compras 10-45 min", "30-90 s", late, late >= 30.0 and late <= 90.0])
	print("   (la mayor espera sin compra terminó en el minuto %.1f)" % (max_dry_at / 60.0))
	checks.append(["máx. tiempo sin poder comprar", "<= 120 s", max_dry_gap, max_dry_gap <= 120.0])
	var pct: float = 100.0 * near_buy_time / maxf(counted_time, 1.0)
	checks.append(["% tiempo con compra pagable o a < 30 s", ">= 70 %", pct, pct >= 70.0])
	checks.append(["primera cadena de 10+ (min)", "< 3", first_chain10 / 60.0, first_chain10 >= 0.0 and first_chain10 < 180.0])
	checks.append(["primera dorada (min)", "< 4", first_golden / 60.0, first_golden >= 0.0 and first_golden < 240.0])
	checks.append(["palma comprada (min)", "< 8", palm_time / 60.0, palm_time >= 0.0 and palm_time < 480.0])
	checks.append(["llegada a Piso / palo (min)", "28-42", phase2_time / 60.0, phase2_time >= 28.0 * 60.0 and phase2_time <= 42.0 * 60.0])
	checks.append(["primer reciclado (min)", "28-42", first_recycle / 60.0, first_recycle >= 28.0 * 60.0 and first_recycle <= 42.0 * 60.0])
	var all_ok: bool = true
	for c: Array in checks:
		var passed: bool = c[3]
		all_ok = all_ok and passed
		var value: float = c[2]
		print("   %-42s objetivo %-9s obtenido %8.2f  %s" % [c[0], c[1], value, "APROBADO" if passed else "FALLÓ"])
		csv.append("0,metrica,%s %s,%.2f,%s" % [str(c[0]).replace(",", ";"), c[1], value, "APROBADO" if passed else "FALLO"])
	print("   RESULTADO: %s" % ("APROBADO" if all_ok else "FALLÓ"))
	return all_ok
