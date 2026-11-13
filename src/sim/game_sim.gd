class_name GameSim
extends RefCounted
## Orquestador de la simulación del juego: junta lámina, herramientas, cadenas, economía,
## compras, combo y reciclado. Lo usan el juego (vista) y el simulador de balance:
## una sola implementación de las reglas. Lógica pura, sin nodos.

const TYPE_GOLDEN: int = 1
const TYPE_BOMB: int = 2
const TYPE_LINE: int = 3
const TYPE_ECHO: int = 4

var db: DataDB
var upgrades: Upgrades
var state: GameState = GameState.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var eco: Dictionary

var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver
var tools: Dictionary = {} ## id -> ToolModel
var hands: HandsModel
var roller: AutoRoller
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
var ev_revived: PackedInt32Array = PackedInt32Array() ## Ecos que se volvieron a inflar
var ev_auto_from: int = 0 ## desde este índice de ev_* los reventones son de la automatización

var chain_count: int = 0 ## tamaño de la cadena en curso (0 si no hay)
var chain_value: float = 0.0
var reload_timer: float = -1.0

var _prev_pointer: Vector2 = Vector2.ZERO
var _chain_active: bool = false
var idle_s: float = 0.0 ## segundos sin apretar
var hands_power: float = 1.0 ## multiplicador de valor del toque de las Manitos
var _hands_in_events: int = 0
var _dr_count: int = 0 ## reventones de la cadena en curso (rendimientos decrecientes)
var _prev_pressing: bool = false
var _echoes: Array[Vector2] = [] ## (índice, segundos que faltan para volver a inflarse)


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


## Centro de la lámina en el plano XZ.
func center() -> Vector2:
	return Vector2(grid.spacing * (float(grid.width) - 0.5) * 0.5, grid.row_step * float(grid.height - 1) * 0.5)


func sheet_dimension() -> int:
	var sizes: Array = eco["phase_sheet_sizes"]
	if phase() >= 2:
		var s: float = sizes[mini(phase(), sizes.size()) - 1]
		return int(s)
	var cap: float = sizes[0]
	return mini(Cfg.integer(eco, "sheet_start_size") + Cfg.integer(stats, "sheet_growth"), int(cap))


func refresh_stats() -> void:
	stats = upgrades.global_stats(state)
	var scales: Array = eco["phase_cost_scales"]
	upgrades.cost_scale = scales[mini(phase(), scales.size()) - 1]
	var discounted: bool = phase() >= 2 and state.run_buys < Cfg.integer(eco, "new_phase_discount_levels")
	upgrades.discount = Cfg.num(eco, "new_phase_discount") if discounted else 1.0
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
	for id: String in ["finger", "palm", "rolling_pin", "iron", "boot"]:
		var tm: ToolModel = ToolModel.new(sheet, grid)
		tm.resistance = Cfg.num(db.sheet, "resistance")
		tm.recovery_per_second = Cfg.num(db.sheet, "recovery_per_second")
		tools[id] = tm
	sheet.reload_threshold = Cfg.num(db.sheet, "reload_threshold")
	hands = HandsModel.new(sheet, grid, rng.randi())
	roller = AutoRoller.new(sheet, grid)
	_echoes = []


func _apply_to_sheet() -> void:
	sheet.tense_threshold = Cfg.num(stats, "tense_threshold")
	sheet.max_pressure = Cfg.num(db.sheet, "max_pressure")
	sheet.min_pressure = Cfg.num(db.sheet, "min_pressure")
	chain.k = Cfg.num(stats, "chain_k")
	for id: String in tools:
		_configure_tool(id)
	var hp: Dictionary = upgrades.hands_params(state)
	hands.set_count(Cfg.integer(hp, "count"))
	hands.rate = Cfg.num(hp, "rate")
	hands.smart = Cfg.flag(hp, "smart")
	hands_power = Cfg.num(hp, "power")
	var rp: Dictionary = upgrades.roller_params(state)
	roller.enabled = Cfg.flag(rp, "enabled")
	roller.speed = Cfg.num(rp, "speed")
	roller.half_width = Cfg.num(rp, "half_width")


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
	tm.heat_rate = Cfg.num(p, "heat_rate")
	tm.heat_cap = Cfg.num(eco, "iron_heat_cap")
	tm.heat_reach = Cfg.num(eco, "iron_heat_reach")
	tm.cooldown = Cfg.num(p, "cooldown")
	tm.wave_k = Cfg.num(eco, "boot_wave_k")
	tm.wave_reach = Cfg.num(p, "wave_reach")
	if tm.shape == "rect":
		tm.heat_reach = Cfg.num(eco, "iron_heat_reach")


## Reparte las burbujas especiales al generar la lámina; avisa las que el jugador no conocía.
func _generate_specials() -> void:
	var chances: Array = [
		[TYPE_GOLDEN, Cfg.num(stats, "chance_golden"), 1],
		[TYPE_BOMB, Cfg.num(stats, "chance_bomb"), 2],
		[TYPE_LINE, Cfg.num(stats, "chance_line"), 2],
		[TYPE_ECHO, Cfg.num(stats, "chance_echo"), 4],
	]
	var present: Dictionary = {}
	var picked: Array[Vector2i] = []
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
				picked.append(Vector2i(i, t))
				break
	# Tope por lámina: crece como la raíz del área (si no, las especiales dominarían las láminas grandes).
	var cap: int = maxi(4, roundi(Cfg.num(eco, "special_cap_k") * sqrt(float(sheet.cell_count()))))
	while picked.size() > cap:
		picked.remove_at(rng.randi() % picked.size())
	for pick: Vector2i in picked:
		sheet.type[pick.x] = pick.y
		present[pick.y] = true
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
	tm.tick_cooldown(dt)
	var touched: PackedInt32Array = PackedInt32Array()
	var dir: Vector2 = Vector2.ZERO
	idle_s = 0.0 if pressing else idle_s + dt
	var live: bool = reload_timer < 0.0
	if pressing and live:
		touched = tm.cells_for(_prev_pointer, pointer)
		dir = pointer - _prev_pointer
	var popped: PackedInt32Array = PackedInt32Array()
	if tm.shape == ToolModel.SHAPE_STOMP:
		if pressing and not _prev_pressing and live:
			popped = tm.stomp(pointer, chain.k)
			_enqueue_overloaded(tm.last_wave_cells)
	else:
		popped = tm.step(touched, dt, tm.last_weights, dir)
		if tm.shape == ToolModel.SHAPE_RECT and live:
			tm.cells_for(_prev_pointer, pointer) # orienta la plancha hacia donde se mueve
			tm.apply_heat(pointer, dt)
		ev_squish = tm.new_pressed > 0
	_prev_pointer = pointer
	_prev_pressing = pressing
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
	_collect_events(false, ev_tool_pops)
	ev_auto_from = ev_idx.size()
	_step_automation(dt)
	_tick_echoes(dt)
	_track_chain()


## Manitos y rodillo automático: revientan solos; su valor no lleva combo (premia jugar activo).
func _step_automation(dt: float) -> void:
	if reload_timer >= 0.0:
		return
	var hand_cells: PackedInt32Array = hands.step(dt)
	var roll_cells: PackedInt32Array = roller.step(dt)
	if hand_cells.is_empty() and roll_cells.is_empty():
		return
	chain.clear_events()
	chain.budget_per_frame = maxi(1, roundi(float(Cfg.integer(db.sheet, "chain_budget_per_frame")) * dt * 30.0))
	for idx: int in hand_cells:
		chain.pop_now(idx)
	for idx: int in roll_cells:
		chain.pop_now(idx)
	chain.step()
	_hands_in_events = hand_cells.size()
	_collect_events(true, hand_cells.size() + roll_cells.size())
	_count_tool_pops("hands", hand_cells.size())
	_count_tool_pops("auto_roller", roll_cells.size())


## Las Manitos rinden más cuando nadie toca (turno de noche): x`idle_hand_mult` tras
## `idle_hand_after_seconds` sin apretar. Es la fuente principal del perfil idle.
func hands_idle_mult() -> float:
	if idle_s >= Cfg.num(eco, "idle_hand_after_seconds"):
		return Cfg.num(eco, "idle_hand_mult")
	return 1.0


func _count_tool_pops(tool_id: String, n: int) -> void:
	if n <= 0:
		return
	var prev: int = state.tool_pops.get(tool_id, 0)
	state.tool_pops[tool_id] = prev + n


## Las celdas que la onda llevó al máximo revientan solas (entran a la cola de cadenas).
func _enqueue_overloaded(cells: PackedInt32Array) -> void:
	for n: int in cells:
		if sheet.pressure[n] >= sheet.max_pressure:
			chain.enqueue(n)


## Eco: pasados `echo_delay_seconds` de reventar, vuelve a inflarse UNA vez (queda como normal).
func _tick_echoes(dt: float) -> void:
	var keep: Array[Vector2] = []
	for e: Vector2 in _echoes:
		var left: float = e.y - dt
		if left > 0.0:
			keep.append(Vector2(e.x, left))
			continue
		var idx: int = int(e.x)
		if sheet.state[idx] == SheetModel.STATE_POPPED:
			sheet.type[idx] = 0
			sheet.revive(idx)
			ev_revived.append(idx)
			sheet.notify_changed(PackedInt32Array([idx]))
	_echoes = keep


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
	ev_revived = PackedInt32Array()
	ev_auto_from = 0


## Valor de cada reventón del step (base * p^2 * tipo * combo * global) y suma a los Pops.
func _collect_events(auto: bool, direct: int = 0) -> void:
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	var m_combo: float = 1.0 if auto else combo.multiplier(now)
	var m_global: float = Cfg.num(stats, "value_mult")
	for i: int in chain.events_idx.size():
		var t: int = chain.events_type[i]
		var m_type: float = Cfg.num(eco, "golden_multiplier") if t == TYPE_GOLDEN else 1.0
		var v: float = Economy.pop_value(base, chain.events_pressure[i], m_type, m_combo, m_global)
		if auto and i < _hands_in_events:
			v *= hands_power * hands_idle_mult()
		if i >= direct:
			_dr_count += 1
			v *= Economy.chain_factor(_dr_count, Cfg.integer(eco, "chain_dr_size"), Cfg.num(eco, "chain_dr_alpha"))
		ev_idx.append(chain.events_idx[i])
		ev_value.append(v)
		ev_pressure.append(chain.events_pressure[i])
		ev_type.append(t)
		if t == TYPE_ECHO:
			_echoes.append(Vector2(float(chain.events_idx[i]), Cfg.num(eco, "echo_delay_seconds")))
		state.pops += v
		state.pops_run += v
		state.pops_total += v


func _track_chain() -> void:
	var n: int = ev_idx.size()
	var value: float = 0.0
	for v: float in ev_value:
		value += v
	if not _chain_active and n > 0 and (not chain.is_idle() or n > ev_tool_pops):
		_chain_active = true
		chain_count = 0
		chain_value = 0.0
	if _chain_active:
		chain_count += n
		chain_value += value
		if chain.is_idle():
			_chain_active = false
			_dr_count = 0
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
		state.run_buys += n
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
	var previous: Dictionary = state.levels.duplicate()
	Prestige.recycle(state, gained)
	state.last_levels = previous
	_apply_memory(previous)
	combo.reset()
	refresh_stats()
	new_sheet()
	_echoes = []
	return gained


## "Memoria del turno": arrancás con un % de los niveles de la partida anterior.
func _apply_memory(previous: Dictionary) -> void:
	var mem: float = upgrades.effect("perm_memory", state.perm_level("perm_memory"))
	if mem <= 0.0:
		return
	for key: Variant in previous:
		var id: String = str(key)
		var prev_level: int = previous[key]
		var restored: int = int(floorf(float(prev_level) * mem))
		if restored > 0 and upgrades.max_level(id) > 1:
			state.levels[id] = mini(restored, upgrades.max_level(id))


# --- Guardado ----------------------------------------------------------------------------------

func save_dict(now_unix: float = 0.0) -> Dictionary:
	state.sheet = sheet.to_dict()
	if now_unix > 0.0:
		state.saved_at_unix = now_unix
		state.max_unix_seen = maxf(state.max_unix_seen, now_unix)
	return state.to_dict()


# --- Ganancias mientras no jugás -----------------------------------------------------------

## Reventones por segundo de la automatización: (manitos, rodillo).
func automation_rates() -> Vector2:
	var hands_s: float = float(hands.count) * hands.rate * hands_power * Cfg.num(eco, "idle_hand_mult") # sin conexión = nadie toca
	var roller_s: float = 0.0
	if roller.enabled:
		roller_s = roller.speed * 2.0 * roller.half_width * 0.9
	return Vector2(hands_s, roller_s)


## Valor medio de un reventón automático (base de la fase x multiplicador global, sin combo).
func average_pop_value() -> float:
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	return base * 1.2 * Cfg.num(stats, "value_mult")


## Lo que produjo la automatización mientras el juego estuvo cerrado (ver OfflineEarnings).
func compute_offline(now_unix: float) -> Dictionary:
	var rates: Vector2 = automation_rates()
	return OfflineEarnings.compute(now_unix, state.saved_at_unix, state.max_unix_seen, rates.x, rates.y,
		average_pop_value(), Cfg.num(eco, "offline_efficiency"), Cfg.num(eco, "offline_cap_hours"))


## Acredita el resultado de compute_offline() y actualiza la hora más alta vista.
func apply_offline(result: Dictionary, now_unix: float) -> void:
	var pops: float = result["pops"]
	state.pops += pops
	state.pops_run += pops
	state.pops_total += pops
	state.offline_total += pops
	state.max_unix_seen = maxf(state.max_unix_seen, now_unix)


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
