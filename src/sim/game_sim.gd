class_name GameSim
extends RefCounted
## Orquestador de la simulación del juego: junta lámina, herramientas, cadenas, economía,
## compras, combo y reciclado. Lo usan el juego (vista) y el simulador de balance:
## una sola implementación de las reglas. Lógica pura, sin nodos.

const TYPE_GOLDEN: int = 1
const TYPE_BOMB: int = 2
const TYPE_LINE: int = 3

var db: DataDB
var upgrades: Upgrades
var state: GameState = GameState.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var eco: Dictionary

var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver
var tools: Dictionary = {} ## id -> ToolModel
var combo: ComboTracker = ComboTracker.new()
var stats: Dictionary = {}
var now: float = 0.0

## Eventos del último step() (los lee la vista; se reinician en cada step).
var ev_idx: PackedInt32Array = PackedInt32Array()
var ev_value: PackedFloat64Array = PackedFloat64Array()
var ev_pressure: PackedFloat32Array = PackedFloat32Array()
var ev_type: PackedByteArray = PackedByteArray()
var ev_tool_pops: int = 0
var ev_chain_ended_count: int = 0 ## > 0 si una cadena terminó en este step
var ev_chain_ended_value: float = 0.0
var ev_new_specials: Array[int] = []
var ev_reloaded: bool = false
var ev_squish: bool = false

var chain_count: int = 0 ## tamaño de la cadena en curso (0 si no hay)
var chain_value: float = 0.0
var reload_timer: float = -1.0

var _prev_pointer: Vector2 = Vector2.ZERO
var _chain_active: bool = false


func _init(p_db: DataDB, seed_value: int = 1) -> void:
	db = p_db
	eco = db.economy
	upgrades = Upgrades.new(db)
	rng.seed = seed_value
	combo.configure(eco)
	refresh_stats()
	new_sheet()


# --- Lámina y estadísticas -----------------------------------------------------------

func phase() -> int:
	return upgrades.phase_of(state)


func sheet_dimension() -> int:
	var sizes: Array = eco["phase_sheet_sizes"]
	if phase() >= 2:
		var s: float = sizes[mini(phase(), sizes.size()) - 1]
		return int(s)
	var cap: float = sizes[0]
	return mini(Cfg.integer(eco, "sheet_start_size") + Cfg.integer(stats, "sheet_growth"), int(cap))


func refresh_stats() -> void:
	stats = upgrades.global_stats(state)
	if sheet != null:
		_apply_to_sheet()


func new_sheet() -> void:
	var dim: int = sheet_dimension()
	sheet = SheetModel.new(dim, dim)
	grid = HexGrid.new(dim, dim, Cfg.num(db.sheet, "bubble_radius"))
	_build_models()
	_apply_to_sheet()
	_generate_specials()
	reload_timer = -1.0
	_chain_active = false
	chain_count = 0
	sheet.reload_requested.connect(_on_reload_requested)


func _build_models() -> void:
	chain = ChainSolver.new(sheet, grid)
	tools.clear()
	for id: String in ["finger", "palm", "rolling_pin"]:
		var tm: ToolModel = ToolModel.new(sheet, grid)
		tm.resistance = Cfg.num(db.sheet, "resistance")
		tm.recovery_per_second = Cfg.num(db.sheet, "recovery_per_second")
		tools[id] = tm
	sheet.reload_threshold = Cfg.num(db.sheet, "reload_threshold")


func _apply_to_sheet() -> void:
	sheet.tense_threshold = Cfg.num(stats, "tense_threshold")
	sheet.max_pressure = Cfg.num(db.sheet, "max_pressure")
	sheet.min_pressure = Cfg.num(db.sheet, "min_pressure")
	chain.k = Cfg.num(stats, "chain_k")
	for id: String in tools:
		_configure_tool(id)


func _configure_tool(id: String) -> void:
	var tm: ToolModel = tools[id]
	var p: Dictionary = upgrades.tool_params(state, id, grid.spacing)
	tm.shape = str(p["shape"])
	tm.radius = Cfg.num(p, "radius")
	tm.force_per_second = Cfg.num(p, "force_per_second")
	tm.drag_entry_fraction = Cfg.num(p, "drag_entry_fraction")
	tm.air_share = Cfg.num(p, "air_share")
	tm.direction_bias = Cfg.num(p, "direction_bias")
	tm.center_falloff = Cfg.num(p, "center_falloff")


## Reparte las burbujas especiales al generar la lámina; avisa las que el jugador no conocía.
func _generate_specials() -> void:
	var chances: Array = [
		[TYPE_GOLDEN, Cfg.num(stats, "chance_golden"), 1],
		[TYPE_BOMB, Cfg.num(stats, "chance_bomb"), 2],
		[TYPE_LINE, Cfg.num(stats, "chance_line"), 2],
	]
	var present: Dictionary = {}
	for i: int in sheet.cell_count():
		var roll: float = rng.randf()
		var acc: float = 0.0
		for entry: Array in chances:
			var t: int = entry[0]
			var chance: float = entry[1]
			var min_phase: int = entry[2]
			if phase() < min_phase:
				continue
			acc += chance
			if roll < acc:
				sheet.type[i] = t
				present[t] = true
				break
	for t: int in present:
		if not state.is_discovered(t):
			state.discover(t)
			ev_new_specials.append(t)


func _on_reload_requested() -> void:
	var auto: bool = stats["auto_reload"]
	var key: String = "reload_delay_auto" if auto else "reload_delay_manual"
	reload_timer = Cfg.num(eco, key)
	state.sheets_done += 1


# --- Paso de simulación --------------------------------------------------------------

func selected_tool() -> ToolModel:
	return tools[state.selected_tool]


func select_tool(id: String) -> bool:
	if not upgrades.tool_unlocked(state, id) or not tools.has(id):
		return false
	state.selected_tool = id
	return true


## Avanza `dt` segundos. `pointer` es la posición del cursor en el plano XZ.
func step(dt: float, pointer: Vector2, pressing: bool) -> void:
	_clear_events()
	now += dt
	state.playtime_s += dt
	state.run_time_s += dt
	if reload_timer >= 0.0:
		reload_timer -= dt
		if reload_timer < 0.0:
			_do_reload()
	var tm: ToolModel = selected_tool()
	var touched: PackedInt32Array = PackedInt32Array()
	var dir: Vector2 = Vector2.ZERO
	if pressing and reload_timer < 0.0:
		touched = tm.cells_for(_prev_pointer, pointer)
		dir = pointer - _prev_pointer
	var popped: PackedInt32Array = tm.step(touched, dt, tm.last_weights, dir)
	_prev_pointer = pointer
	ev_squish = tm.new_pressed > 0
	chain.clear_events()
	for idx: int in popped:
		chain.pop_now(idx)
	ev_tool_pops = popped.size()
	if ev_tool_pops > 0:
		combo.add(1.0 + 0.25 * float(ev_tool_pops - 1), now)
		var prev_pops: int = state.tool_pops.get(state.selected_tool, 0)
		state.tool_pops[state.selected_tool] = prev_pops + ev_tool_pops
	chain.budget_per_frame = maxi(1, roundi(float(Cfg.integer(db.sheet, "chain_budget_per_frame")) * dt * 60.0))
	chain.step()
	_collect_events()
	_track_chain()


func _do_reload() -> void:
	new_sheet()
	ev_reloaded = true


func _clear_events() -> void:
	ev_idx = PackedInt32Array()
	ev_value = PackedFloat64Array()
	ev_pressure = PackedFloat32Array()
	ev_type = PackedByteArray()
	ev_tool_pops = 0
	ev_chain_ended_count = 0
	ev_chain_ended_value = 0.0
	ev_new_specials = []
	ev_reloaded = false
	ev_squish = false


## Valor de cada reventón del step (base * p^2 * tipo * combo * global) y suma a los Pops.
func _collect_events() -> void:
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	var m_combo: float = combo.multiplier(now)
	var m_global: float = Cfg.num(stats, "value_mult")
	for i: int in chain.events_idx.size():
		var t: int = chain.events_type[i]
		var m_type: float = Cfg.num(eco, "golden_multiplier") if t == TYPE_GOLDEN else 1.0
		var v: float = Economy.pop_value(base, chain.events_pressure[i], m_type, m_combo, m_global)
		ev_idx.append(chain.events_idx[i])
		ev_value.append(v)
		ev_pressure.append(chain.events_pressure[i])
		ev_type.append(t)
		state.pops += v
		state.pops_run += v
		state.pops_total += v


func _track_chain() -> void:
	var n: int = ev_idx.size()
	var value: float = 0.0
	for v: float in ev_value:
		value += v
	if not _chain_active and n > 0 and not chain.is_idle():
		_chain_active = true
		chain_count = 0
		chain_value = 0.0
	if _chain_active:
		chain_count += n
		chain_value += value
		if chain.is_idle():
			_chain_active = false
			ev_chain_ended_count = chain_count
			ev_chain_ended_value = chain_value
			state.max_chain = maxi(state.max_chain, chain_count)
			chain_count = 0
			chain_value = 0.0


func combo_multiplier() -> float:
	return combo.multiplier(now)


func combo_rate() -> float:
	return combo.rate(now)


# --- Compras ----------------------------------------------------------------------------

## Compra `count` niveles (-1 = el máximo que se pueda pagar). Devuelve
## {"bought": n, "milestone": bool, "level": nivel final}.
func buy(id: String, count: int) -> Dictionary:
	var out: Dictionary = {"bought": 0, "milestone": false, "level": 0}
	if not upgrades.is_available(state, id):
		return out
	var perm: bool = upgrades.is_perm(id)
	var level: int = upgrades.level_of(state, id)
	out["level"] = level
	var budget: float = state.pellets if perm else state.pops
	var room: int = upgrades.max_level(id) - level
	var n: int = upgrades.affordable_count(id, level, budget) if count < 0 else mini(count, room)
	if count > 0:
		n = mini(n, upgrades.affordable_count(id, level, budget))
	if n <= 0:
		return out
	var price: float = upgrades.cost_for(id, level, n)
	if perm:
		state.pellets -= price
		state.perm[id] = level + n
	else:
		state.pops -= price
		state.levels[id] = level + n
	var every: int = Cfg.integer(eco, "milestone_every")
	@warning_ignore("integer_division")
	out["milestone"] = (level + n) / every > level / every
	out["bought"] = n
	out["level"] = level + n
	refresh_stats()
	return out


func can_afford_next(id: String) -> bool:
	if not upgrades.is_available(state, id):
		return false
	var level: int = upgrades.level_of(state, id)
	if level >= upgrades.max_level(id):
		return false
	var budget: float = state.pellets if upgrades.is_perm(id) else state.pops
	return upgrades.next_cost(id, level) <= budget


# --- Reciclado -----------------------------------------------------------------------------

func recycle_gain() -> int:
	return Prestige.pellets_for(state.pops_run, Cfg.num(eco, "pellet_divisor"), Cfg.num(eco, "pellet_exponent"))


func can_recycle() -> bool:
	return recycle_gain() >= 1


## Recicla: Pellets nuevos, reinicio de la corrida y lámina nueva. Devuelve los Pellets ganados.
func recycle() -> int:
	var gained: int = recycle_gain()
	if gained < 1:
		return 0
	Prestige.recycle(state, gained)
	combo.reset()
	refresh_stats()
	new_sheet()
	_apply_perm_start()
	return gained


func _apply_perm_start() -> void:
	refresh_stats()


# --- Guardado ----------------------------------------------------------------------------------

func save_dict() -> Dictionary:
	state.sheet = sheet.to_dict()
	return state.to_dict()


## Carga un save (migrándolo). Devuelve false si es inválido (el estado queda intacto).
func load_dict(data: Dictionary) -> bool:
	var loaded: GameState = GameState.new()
	if not loaded.from_dict(data):
		return false
	state = loaded
	refresh_stats()
	new_sheet()
	if not state.sheet.is_empty():
		var restored: SheetModel = SheetModel.new()
		if restored.from_dict(state.sheet) and restored.width == sheet.width:
			sheet.width = restored.width
			sheet.pressure = restored.pressure
			sheet.state = restored.state
			sheet.type = restored.type
			sheet.press = restored.press
			sheet.reset_counts()
	return true
