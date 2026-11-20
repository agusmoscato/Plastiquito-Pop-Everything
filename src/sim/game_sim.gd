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
var acc: Accessories
var big: BigOrder
var story: Story
var memo_queue: Array[String] = [] ## memos esperando (el primero se muestra; un clic lo cierra)
var ending_pending: bool = false ## hay que mostrar la secuencia final (telegrama, sello EX, créditos)
var acc_fx: Dictionary = {} ## efectos de los accesorios equipados (Accessories.aggregate)
var state: GameState = GameState.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var eco: Dictionary

var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver
var tools: Dictionary = {} ## id -> ToolModel
var wear: Dictionary[String, WearModel] = {} ## id -> WearModel (desgaste: plancha que se recalienta, bota que cansa...)
var _fresh_tool: String = ""
var _fresh_since: float = 0.0
var ev_tool_locked: String = "" ## herramienta que se trabó en este paso (la vista suena y echa humo)
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
var ev_burned: PackedInt32Array = PackedInt32Array() ## plancha quieta: celdas derretidas (humo y chirrido)
var ev_revived: PackedInt32Array = PackedInt32Array() ## Ecos que se volvieron a inflar
var ev_auto_from: int = 0 ## desde este índice de ev_* los reventones son de la automatización
var ev_cracked: PackedInt32Array = PackedInt32Array() ## doble film que se rompió (siguen enteras)
var ev_encargo_done: bool = false ## el encargo se cumplió en este paso
var ev_encargo_bonus: float = 0.0
var ev_big_started: bool = false ## apareció el pedido grande del escenario
var ev_big_done: bool = false ## se cumplió
var ev_big_failed: bool = false ## venció el plazo (multa)
var ev_big_fine: float = 0.0
var norm_rate: float = 0.0 ## ritmo de Pops por segundo en burbujas equivalentes (Pops/s / valor base)
var _rate_acc: float = 0.0
var _rate_t: float = 0.0
var _stomp_heavy: int = 0
var ev_encargo_failed: bool = false ## la lámina terminó sin cumplir el encargo (se cortó la racha)

var encargo: Encargo ## el pedido de la lámina en curso
var streak: int = 0 ## encargos cumplidos seguidos
var vein_cells: PackedInt32Array = PackedInt32Array() ## vetas de aire de la lámina en curso
var _sheet_finished: bool = false
var _step_dt: float = 0.0

var chain_count: int = 0 ## tamaño de la cadena en curso (0 si no hay)
var chain_value: float = 0.0
var reload_timer: float = -1.0
## Sin "Recarga automática" la lámina terminada espera a que el jugador tire una nueva del rollo.
var awaiting_reload: bool = false

var _prev_pointer: Vector2 = Vector2.ZERO
var _chain_active: bool = false
var idle_s: float = 0.0 ## segundos sin apretar
var hands_power: float = 1.0 ## multiplicador de valor del toque de las Manitos
var _hands_in_events: int = 0
var _auto_mult: Dictionary[int, float] = {}
## Pops ganados por herramienta (incluye lo que arrastran sus cadenas) y por escenario: clave "fase:herramienta".
## Es solo una medición (el simulador de balance la lee; no se guarda).
var tool_value: Dictionary[String, float] = {} ## idx -> multiplicador de valor por material (solo reventones automáticos)
var _dr_count: int = 0 ## reventones de la cadena en curso (rendimientos decrecientes)
var _prev_pressing: bool = false
var _echoes: Array[Vector2] = [] ## (índice, segundos que faltan para volver a inflarse)


func _init(p_db: DataDB, seed_value: int = 1) -> void:
	db = p_db
	eco = db.economy
	upgrades = Upgrades.new(db)
	acc = Accessories.new(db)
	big = BigOrder.new(db)
	story = Story.new(db)
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


## Lado de la lámina: cada fase arranca con una lámina chica (`phase_sheet_starts`) y "Rollo más
## ancho" la agranda hasta el tope de la fase (`phase_sheet_sizes`), repartido entre sus niveles.
func sheet_dimension() -> int:
	var caps: Array = eco["phase_sheet_sizes"]
	var starts: Array = eco["phase_sheet_starts"]
	var i: int = mini(phase(), caps.size()) - 1
	var cap: float = caps[i]
	var start: float = starts[mini(i, starts.size() - 1)]
	var max_lv: int = upgrades.max_level("global_sheet")
	var lv: int = mini(state.level("global_sheet"), max_lv)
	var grown: float = start + (cap - start) * float(lv) / float(maxi(max_lv, 1))
	return clampi(roundi(grown), int(start), int(cap))


func refresh_stats() -> void:
	stats = upgrades.global_stats(state)
	acc_fx = acc.aggregate(state.acc_equipped)
	stats["value_mult"] = Cfg.num(stats, "value_mult") * big_mult()
	var scales: Array = eco["phase_cost_scales"]
	upgrades.cost_scale = scales[mini(phase(), scales.size()) - 1]
	var discounted: bool = phase() >= 2 and state.run_buys < Cfg.integer(eco, "new_phase_discount_levels")
	upgrades.discount = Cfg.num(eco, "new_phase_discount") if discounted else 1.0
	upgrades.relearn = state.last_levels
	upgrades.relearn_factor = Cfg.num(eco, "relearn_cost_factor")
	if sheet != null:
		_apply_to_sheet()


func new_sheet() -> void:
	var dim: int = sheet_dimension()
	sheet = SheetModel.new(dim, dim)
	grid = HexGrid.new(dim, dim, Cfg.num(db.sheet, "bubble_radius"))
	_build_models()
	_apply_to_sheet()
	var pat: Dictionary = db.sheet["patterns"]
	vein_cells = SheetPatterns.apply(sheet, grid, rng, phase(), pat)
	_generate_specials()
	_roll_encargo()
	reload_timer = -1.0
	awaiting_reload = false
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
		if not wear.has(id):
			wear[id] = WearModel.new()
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
	hands.rate = Cfg.num(hp, "rate") * (1.0 + Accessories.flat(acc_fx, "auto_rate"))
	hands.smart = Cfg.flag(hp, "smart")
	hands_power = Cfg.num(hp, "power")
	var rp: Dictionary = upgrades.roller_params(state)
	roller.enabled = Cfg.flag(rp, "enabled")
	roller.speed = Cfg.num(rp, "speed") * (1.0 + Accessories.flat(acc_fx, "auto_rate"))
	roller.half_width = Cfg.num(rp, "half_width")


func _configure_tool(id: String) -> void:
	var tm: ToolModel = tools[id]
	var p: Dictionary = upgrades.tool_params(state, id, grid.spacing)
	tm.shape = str(p["shape"])
	tm.radius = Cfg.num(p, "radius")
	tm.force_per_second = Cfg.num(p, "force_per_second") * (1.0 + Accessories.per(acc_fx, "tool_force", id))
	tm.drag_entry_fraction = Cfg.num(p, "drag_entry_fraction")
	tm.air_share = Cfg.num(p, "air_share")
	tm.direction_bias = Cfg.num(p, "direction_bias")
	tm.center_falloff = Cfg.num(p, "center_falloff")
	tm.heat_rate = Cfg.num(p, "heat_rate")
	tm.heat_cap = Cfg.num(eco, "iron_heat_cap")
	tm.still_force = Cfg.num(eco, "iron_still_force")
	tm.burn_after = Cfg.num(eco, "iron_burn_after_seconds")
	tm.glide_min_speed = Cfg.num(eco, "iron_glide_min_speed")
	tm.heat_reach = Cfg.num(eco, "iron_heat_reach")
	tm.cooldown = Cfg.num(p, "cooldown")
	_configure_wear(id)
	var mx: Dictionary = eco["tool_matrix"]
	var row: Dictionary = mx[id]
	tm.material_mult = PackedFloat32Array([
		Cfg.num(row, "thermal") * (1.0 + Accessories.per(acc_fx, "material_force", "thermal")),
		Cfg.num(row, "cold") * (1.0 + Accessories.per(acc_fx, "material_force", "cold")),
		Cfg.num(row, "heavy") * (1.0 + Accessories.per(acc_fx, "material_force", "heavy"))])
	tm.wave_k = Cfg.num(eco, "boot_wave_k")
	tm.wave_reach = Cfg.num(p, "wave_reach")
	if tm.shape == "rect":
		tm.heat_reach = Cfg.num(eco, "iron_heat_reach")


## El desgaste de la herramienta: la capacidad y la recuperación suben con su mejora de velocidad
## (data/economy.json "wear"), pero el límite siempre existe.
func _configure_wear(id: String) -> void:
	var cfg: Dictionary = eco["wear"]
	var w: Dictionary = cfg[id]
	var k: float = 1.0 + Cfg.num(cfg, "speed_gain") * float(state.level(id + "_speed"))
	var wm: WearModel = wear[id]
	var cap_mult: float = 1.0 + Accessories.per(acc_fx, "wear_capacity", id)
	var rec_mult: float = 1.0 + Accessories.per(acc_fx, "wear_recover", id) + Accessories.per(acc_fx, "wear_recover", "all")
	var drain_mult: float = maxf(0.2, 1.0 + Accessories.per(acc_fx, "wear_drain", id))
	if w.has("size_drain"): # la palma se cansa más rápido cuanto más grande es la lámina (por cada duplicación del área)
		var doublings: float = maxf(0.0, log(float(sheet.cell_count()) / 400.0) / log(2.0))
		drain_mult *= 1.0 + Cfg.num(w, "size_drain") * doublings
	wm.configure(Cfg.num(w, "capacity") * k * cap_mult, Cfg.num(w, "drain") * drain_mult, Cfg.num(w, "recover") * k * rec_mult, Cfg.num(w, "resume"))


## Medidor de desgaste de una herramienta (0 fresca, 1 trabada). Manitos y rodillo: 0.
func wear_fraction(id: String) -> float:
	return wear[id].fraction() if wear.has(id) else 0.0


func tool_locked(id: String) -> bool:
	return wear.has(id) and wear[id].locked


## Desde cuándo aparece cada especial: la dorada tras el primer reciclado, bomba y línea en el
## Piso y el eco en el Estacionamiento (antes de eso el jugador todavía está aprendiendo lo básico).
func special_unlocked(t: int) -> bool:
	match t:
		TYPE_GOLDEN:
			return state.recycles >= 1 or phase() >= 2
		TYPE_BOMB, TYPE_LINE:
			return phase() >= 2
		TYPE_ECHO:
			return phase() >= 4
	return false


## Reparte las burbujas especiales al generar la lámina; avisa las que el jugador no conocía.
func _generate_specials() -> void:
	var chances: Array = [
		[TYPE_GOLDEN, Cfg.num(stats, "chance_golden")],
		[TYPE_BOMB, Cfg.num(stats, "chance_bomb")],
		[TYPE_LINE, Cfg.num(stats, "chance_line")],
		[TYPE_ECHO, Cfg.num(stats, "chance_echo")],
	]
	var present: Dictionary = {}
	var picked: Array[Vector2i] = []
	for i: int in sheet.cell_count():
		var roll: float = rng.randf()
		var acc: float = 0.0
		for entry: Array in chances:
			var t: int = entry[0]
			var chance: float = entry[1]
			if not special_unlocked(t):
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


func _roll_encargo() -> void:
	var specials: int = 0
	for t: int in sheet.type:
		if t != 0:
			specials += 1
	var cfg: Dictionary = eco["encargos"]
	encargo = Encargo.roll(rng, phase(), sheet.cell_count(), sheet.count_tense(), specials, cfg)
	_sheet_finished = false


func streak_cap() -> int:
	var cfg: Dictionary = eco["encargos"]
	return Cfg.integer(cfg, "streak_cap") + int(Accessories.flat(acc_fx, "streak_cap_add"))


## Plazo de los pedidos grandes (multiplicador por accesorios).
func big_order_time_mult() -> float:
	return 1.0 + Accessories.flat(acc_fx, "big_order_time")


## Multiplicador de la racha de encargos (+streak_bonus por cada uno seguido).
func streak_mult() -> float:
	var cfg: Dictionary = eco["encargos"]
	return 1.0 + Cfg.num(cfg, "streak_bonus") * float(streak)


## Sigue el encargo con los eventos del paso: paga el bono al cumplirlo y corta la racha si la lámina
## terminó sin cumplirlo.
func _track_encargo() -> void:
	if encargo == null:
		return
	var tense: int = 0
	var specials: int = 0
	for i: int in ev_idx.size():
		if ev_pressure[i] >= sheet.tense_threshold:
			tense += 1
		if ev_type[i] != 0:
			specials += 1
	for idx: int in ev_burned: # la plancha derritió una especial: ya no se puede reventar
		if sheet.type[idx] != 0:
			encargo.lost_special()
	var chain_now: int = maxi(chain_count, ev_chain_ended_count)
	if encargo.observe(chain_now, tense, specials, combo.level(now), _step_dt, combo.window_seconds):
		var cfg: Dictionary = eco["encargos"]
		var bases: Array = eco["phase_base_values"]
		var base: float = bases[mini(phase(), bases.size()) - 1]
		var bonus: float = float(sheet.cell_count()) * base * Cfg.num(stats, "value_mult") * Cfg.num(cfg, "reward_sheet_fraction") * streak_mult()
		state.pops += bonus
		state.pops_run += bonus
		state.pops_total += bonus
		streak = mini(streak + 1, streak_cap())
		ev_encargo_done = true
		ev_encargo_bonus = bonus
	if _sheet_finished:
		_sheet_finished = false
		if not encargo.done and not encargo.closed:
			streak = 0
			ev_encargo_failed = true
		encargo.closed = true # lo que se reviente después (el último 10 %) ya no cuenta


func _on_reload_requested() -> void:
	_sheet_finished = true
	state.phase_sheets += 1
	state.sheets_done += 1
	if auto_reload():
		reload_timer = Cfg.num(eco, "reload_delay_auto")
	else:
		awaiting_reload = true


func auto_reload() -> bool:
	return Cfg.flag(stats, "auto_reload")


## El jugador tira una lámina nueva del rollo (solo cuando la actual ya está terminada).
func request_reload() -> bool:
	if not awaiting_reload or reload_timer >= 0.0:
		return false
	awaiting_reload = false
	reload_timer = Cfg.num(eco, "reload_delay_manual")
	return true


## Sin "Mantener apretado" cada clic revienta una sola vez lo que hay bajo la herramienta.
func hold_unlocked() -> bool:
	return Cfg.flag(stats, "hold")


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
	_step_dt = dt
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
	var wm: WearModel = wear[state.selected_tool]
	var wear_cfg: Dictionary = eco["wear"]
	var tired: float = Cfg.num(wear_cfg, "tired_penalty")
	if state.selected_tool != _fresh_tool:
		_fresh_tool = state.selected_tool
		_fresh_since = now
	var fresh: float = Cfg.num(wear_cfg, "fresh_bonus") * exp(-(now - _fresh_since) / Cfg.num(wear_cfg, "fresh_seconds"))
	tm.fatigue_mult = (1.0 - tired * pow(wm.fraction(), 1.5)) * (1.0 + fresh) # cansada rinde menos; recién agarrada, más: alternar paga
	var live: bool = reload_timer < 0.0 and wm.available()
	var click_only: bool = not hold_unlocked()
	var press_edge: bool = pressing and not _prev_pressing
	if pressing and live and (press_edge or not click_only):
		touched = tm.cells_for(pointer if click_only else _prev_pointer, pointer)
		dir = pointer - _prev_pointer
	var popped: PackedInt32Array = PackedInt32Array()
	if tm.shape == ToolModel.SHAPE_STOMP:
		if press_edge and live:
			popped = tm.stomp(pointer, chain.k)
			_stomp_heavy = _count_material(popped, SheetModel.MAT_HEAVY)
			_enqueue_overloaded(tm.last_wave_cells)
	elif click_only and not touched.is_empty():
		popped = tm.step(touched, tm.resistance / maxf(tm.force_per_second, 0.01) + 0.001, tm.last_weights, Vector2.ZERO) # un clic, un reventón
		ev_cracked = tm.cracked
		tm.step(PackedInt32Array(), 0.0) # suelta: el próximo reventón pide otro clic
	else:
		popped = tm.step(touched, dt, tm.last_weights, dir)
		if tm.shape == ToolModel.SHAPE_RECT and live:
			tm.cells_for(_prev_pointer, pointer) # orienta la plancha hacia donde se mueve
			tm.apply_heat(pointer, dt, pointer - _prev_pointer)
			ev_burned = tm.burned
		ev_squish = tm.new_pressed > 0
		ev_cracked = tm.cracked
	_prev_pointer = pointer
	_prev_pressing = pressing
	_tick_wear(dt, wm, tm, touched, press_edge)
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
	_track_encargo()
	_track_rate(dt)
	_track_big(dt)
	_track_story()


## Gasta el desgaste de la herramienta en uso y deja descansar a las demás.
func _tick_wear(dt: float, wm: WearModel, tm: ToolModel, touched: PackedInt32Array, press_edge: bool) -> void:
	var was_locked: bool = wm.locked
	if tm.shape == ToolModel.SHAPE_STOMP:
		if press_edge and tm.cooldown_left >= tm.cooldown - 0.0001 and tm.cooldown > 0.0 and reload_timer < 0.0:
			wm.use(1.0) # un pisotón
	elif not touched.is_empty():
		wm.use(dt if hold_unlocked() else 0.15)
	for id: String in wear:
		wear[id].tick(dt)
	if wm.locked and not was_locked:
		ev_tool_locked = state.selected_tool


## Manitos y rodillo automático: revientan solos; su valor no lleva combo (premia jugar activo).
func _step_automation(dt: float) -> void:
	if reload_timer >= 0.0:
		return
	var hand_cells: PackedInt32Array = hands.step(dt * night_rate()) # de noche tocan más seguido
	var roll_cells: PackedInt32Array = roller.step(dt)
	if hand_cells.is_empty() and roll_cells.is_empty():
		return
	chain.clear_events()
	chain.budget_per_frame = maxi(1, roundi(float(Cfg.integer(db.sheet, "chain_budget_per_frame")) * dt * 30.0))
	_auto_mult.clear()
	_note_material_mult(hand_cells, "hands")
	_note_material_mult(roll_cells, "auto_roller")
	for idx: int in hand_cells:
		chain.pop_now(idx)
	for idx: int in roll_cells:
		chain.pop_now(idx)
	chain.step()
	_hands_in_events = hand_cells.size()
	_collect_events(true, hand_cells.size() + roll_cells.size())
	_count_tool_pops("hands", hand_cells.size())
	_count_tool_pops("auto_roller", roll_cells.size())


## Valor extra o menor de lo que reventan las manitos y el rodillo según el material (tool_matrix).
func _note_material_mult(cells: PackedInt32Array, tool_id: String) -> void:
	var row: Dictionary = eco["tool_matrix"][tool_id]
	var keys: Array[String] = ["thermal", "cold", "heavy"]
	for idx: int in cells:
		var m: int = sheet.material[idx]
		if m > 0 and sheet.state[idx] != SheetModel.STATE_POPPED:
			_auto_mult[idx] = Cfg.num(row, keys[m - 1])


## TURNO NOCHE (DESIGN 3.5): tras `idle_hand_after_seconds` sin apretar, las Manitos rinden
## x`idle_hand_mult` en total: tocan `night_rate_mult` veces más seguido y cada toque vale el resto.
## Es la fuente principal del perfil idle. Requiere Manitos compradas.
func night_shift() -> bool:
	return hands != null and hands.count > 0 and idle_s >= Cfg.num(eco, "idle_hand_after_seconds")


func night_rate() -> float:
	return Cfg.num(eco, "night_rate_mult") if night_shift() else 1.0


func hands_idle_mult() -> float:
	if night_shift():
		return Cfg.num(eco, "idle_hand_mult") / Cfg.num(eco, "night_rate_mult")
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
## Ecos pendientes: (índice de celda, segundos que faltan para volver a inflarse). Copia: la vista solo lee.
func pending_echoes() -> Array[Vector2]:
	return _echoes.duplicate()


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
	ev_burned = PackedInt32Array()
	ev_tool_locked = ""
	ev_big_started = false
	ev_big_done = false
	ev_big_failed = false
	ev_big_fine = 0.0
	_stomp_heavy = 0
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
	ev_cracked = PackedInt32Array()
	ev_encargo_done = false
	ev_encargo_bonus = 0.0
	ev_encargo_failed = false


## Valor de cada reventón del step (base * p^2 * tipo * combo * global) y suma a los Pops.
func _collect_events(auto: bool, direct: int = 0) -> void:
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	var m_combo: float = 1.0 if auto else combo.multiplier(now)
	var m_global: float = Cfg.num(stats, "value_mult") * streak_mult()
	var sum_a: float = 0.0 ## herramienta del jugador (o manitos en lo automático)
	var sum_b: float = 0.0 ## rodillo automático
	for i: int in chain.events_idx.size():
		var t: int = chain.events_type[i]
		var m_type: float = Cfg.num(eco, "golden_multiplier") if t == TYPE_GOLDEN else 1.0
		var v: float = Economy.pop_value(base, chain.events_pressure[i], m_type, m_combo, m_global)
		if auto and i < direct and _auto_mult.has(chain.events_idx[i]):
			v *= _auto_mult[chain.events_idx[i]]
		if auto and i < _hands_in_events:
			v *= hands_power * hands_idle_mult()
		if i >= direct:
			_dr_count += 1
			v *= Economy.chain_factor(_dr_count, Cfg.integer(eco, "chain_dr_size"), Cfg.num(eco, "chain_dr_alpha"))
			if _dr_count >= Cfg.integer(eco, "chain_big_size"):
				v *= 1.0 + Accessories.flat(acc_fx, "chain_big")
		if auto and i >= _hands_in_events and i < direct:
			sum_b += v
		else:
			sum_a += v
		ev_idx.append(chain.events_idx[i])
		ev_value.append(v)
		ev_pressure.append(chain.events_pressure[i])
		ev_type.append(t)
		if t == TYPE_ECHO:
			_echoes.append(Vector2(float(chain.events_idx[i]), Cfg.num(eco, "echo_delay_seconds")))
		state.pops += v
		state.pops_run += v
		state.pops_total += v
		_rate_acc += v
	_credit_tools(auto, sum_a, sum_b)


## Memos de la historia: bienvenida, primer cliente, primer reciclado, cada escenario nuevo, cada pedido grande
## y cada ascenso. "Una vez" se recuerda en el guardado; el final solo se dispara con `trigger_ending()`.
func _track_story() -> void:
	_once("welcome")
	_once("first_client")
	if state.recycles >= 1:
		_once("first_recycle")
	for ph: int in range(2, 5):
		if phase() >= ph:
			_once("phase_%d" % ph)
	if ev_big_done:
		memo_queue.append("big_done")
	if ev_big_failed:
		memo_queue.append("big_failed")
	var rank: int = story.rank_index(state.recycles)
	if rank > state.last_rank:
		state.last_rank = rank
		memo_queue.append("promotion")


func _once(id: String) -> void:
	if not state.story_seen.has(id):
		state.story_seen[id] = true
		memo_queue.append(id)


func current_memo() -> String:
	return memo_queue[0] if not memo_queue.is_empty() else ""


func dismiss_memo() -> void:
	if not memo_queue.is_empty():
		memo_queue.pop_front()


## El nombre del empleado para los textos (el de Steam o de la ficha; si no, "Empleado N° 4417").
func player_name(lang: String) -> String:
	return state.employee_name if state.employee_name != "" else story.fallback_name(lang)


func memo_text_now(lang: String) -> String:
	var id: String = current_memo()
	return story.memo_text(id, lang, player_name(lang), story.rank_name(state.last_rank, lang)) if id != "" else ""


## FINAL: reventaste todo el plástico del mundo y la empresa se quedó sin mercadería. En las builds de
## jugador se dispara al terminar el escenario 7 (todavía no existe); el modo DEV lo dispara con F8.
func trigger_ending() -> void:
	if state.ending_done:
		return
	ending_pending = true
	state.ending_done = true
	state.freelance = true # después del final se desbloquea el modo "AHORA SOS MONOTRIBUTISTA"
	memo_queue.clear()


func _count_material(cells: PackedInt32Array, mat: int) -> int:
	var n: int = 0
	for idx: int in cells:
		if sheet.material[idx] == mat:
			n += 1
	return n


## Ritmo en burbujas equivalentes por segundo (promediado) y requisitos de escenario que ya se demostraron.
func _track_rate(dt: float) -> void:
	_rate_t += dt
	if _rate_t < 1.0:
		return
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	norm_rate = lerpf(norm_rate, _rate_acc / _rate_t / base, 0.35)
	_rate_acc = 0.0
	_rate_t = 0.0
	_check_latches()


func _check_latches() -> void:
	var ph: int = phase()
	var tool_level: int = 0
	for e: Dictionary in db.phases:
		if Cfg.integer(e, "number") == ph and e.has("requires"):
			var req: Dictionary = e["requires"]
			if req.has("tool"):
				var t: Dictionary = req["tool"]
				tool_level = state.level(str(t["upgrade"]))
	for key: String in PhaseGate.newly_met(db, ph, tool_level, norm_rate):
		state.latched[key] = true


## Requisitos del escenario actual para abrir el siguiente: [{"id", "ok", "es", "en"}] (con el pedido grande).
func phase_requirements() -> Array[Dictionary]:
	return PhaseGate.list(db, phase(), state.big_done.has(str(phase())), state.latched)


func phase_gate_ok() -> bool:
	return PhaseGate.all_ok(phase_requirements())


## Pedido grande: aparece a mitad de camino, tiene plazo, paga al cumplirse y multa al vencer.
func _track_big(dt: float) -> void:
	var ph: int = phase()
	if not big.has_order(ph) or state.big_done.has(str(ph)):
		return
	var d: Dictionary = big.def_for(ph)
	var shown_phase: int = state.big.get("phase", 0)
	if shown_phase != ph:
		state.big = BigOrder.fresh(ph, Cfg.integer(d, "trigger_sheets"))
	if big.should_start(state.big, state.phase_sheets, false):
		big.start(state.big, big_order_time_mult())
		ev_big_started = true
	if not big.is_active(state.big):
		return
	state.big["left"] = Cfg.num(state.big, "left") - dt
	big.observe(state.big, _big_step())
	if big.is_met(state.big):
		_complete_big(d)
	elif Cfg.num(state.big, "left") <= 0.0:
		ev_big_fine = state.pops * Cfg.num(d, "fine")
		state.pops -= ev_big_fine
		big.expire(state.big, state.phase_sheets)
		ev_big_failed = true


func _big_step() -> Dictionary:
	var counts: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for idx: int in ev_idx:
		counts[sheet.material[idx]] += 1.0
	var mats: Dictionary = {"thermal": counts[SheetModel.MAT_THERMAL], "cold": counts[SheetModel.MAT_COLD], "heavy": counts[SheetModel.MAT_HEAVY]}
	return {"pops": float(ev_idx.size()), "material": mats, "chain": float(maxi(chain_count, ev_chain_ended_count)),
		"tool": state.selected_tool, "heavy_stomp": float(_stomp_heavy)}


func _complete_big(d: Dictionary) -> void:
	state.big_done[str(phase())] = true
	state.pellets += float(Cfg.integer(d, "reward_pellets"))
	state.big["status"] = BigOrder.IDLE
	ev_big_done = true
	refresh_stats() # el multiplicador permanente del pedido entra al valor global


## Multiplicador permanente por pedidos grandes cumplidos.
func big_mult() -> float:
	var m: float = 1.0
	for o: Dictionary in db.big_orders:
		if state.big_done.has(str(Cfg.integer(o, "phase"))):
			m *= 1.0 + Cfg.num(o, "reward_mult")
	return m


func _credit_tools(auto: bool, sum_a: float, sum_b: float) -> void:
	var ph: String = str(phase()) + ":"
	var main_id: String = "hands" if auto else state.selected_tool
	tool_value[ph + main_id] = tool_value.get(ph + main_id, 0.0) + sum_a
	if sum_b > 0.0:
		tool_value[ph + "auto_roller"] = tool_value.get(ph + "auto_roller", 0.0) + sum_b


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
	if id == "perm_sheet" and not phase_gate_ok():
		return out # faltan requisitos del escenario (pedido grande, herramienta, ritmo)
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
	if id == "perm_sheet": # escenario nuevo: el contador de láminas y el pedido grande empiezan de cero
		state.phase_sheets = 0
		state.big = {}
	refresh_stats()
	return out


func can_afford_next(id: String) -> bool:
	if not upgrades.is_available(state, id):
		return false
	if id == "perm_sheet" and not phase_gate_ok():
		return false
	var level: int = upgrades.level_of(state, id)
	if level >= upgrades.max_level(id):
		return false
	var budget: float = state.pellets if upgrades.is_perm(id) else state.pops
	return upgrades.next_cost(id, level) <= budget


## true si en este escenario ya no queda nada razonable para comprar: todo lo disponible está al máximo o
## lo más barato cuesta más de `nothing_left_minutes` minutos de ingreso. La orden de trabajo lo dice y
## RECICLAR late.
func nothing_left_to_buy() -> bool:
	var bases: Array = eco["phase_base_values"]
	var base: float = bases[mini(phase(), bases.size()) - 1]
	var income: float = maxf(norm_rate * base, 0.001)
	var cheapest: float = INF
	for id: String in upgrades.order:
		if upgrades.is_perm(id) or not upgrades.is_available(state, id):
			continue
		var lv: int = state.level(id)
		if lv < upgrades.max_level(id):
			cheapest = minf(cheapest, upgrades.next_cost(id, lv))
	return cheapest == INF or cheapest / income > Cfg.num(eco, "nothing_left_minutes") * 60.0


# --- Accesorios (permanentes: no se pierden al reciclar) ---------------------------------------

## Compra un accesorio con Pellets. Si queda una ranura libre del tipo, lo equipa.
func buy_accessory(id: String) -> bool:
	if state.acc_owned.has(id) or acc.def(id).is_empty():
		return false
	var cost: float = float(acc.cost_of(id))
	if state.pellets < cost:
		return false
	state.pellets -= cost
	state.acc_owned[id] = true
	for slot: String in Accessories.SLOTS:
		if acc.fits(slot, id) and not state.acc_equipped.has(slot):
			state.acc_equipped[slot] = id
			break
	refresh_stats()
	return true


## Equipa un accesorio comprado en la ranura (reemplaza al que estaba). false si no entra.
func equip_accessory(slot: String, id: String) -> bool:
	if not state.acc_owned.has(id) or not acc.fits(slot, id):
		return false
	for other: String in Accessories.SLOTS: # el mismo accesorio no puede estar en dos ranuras
		if str(state.acc_equipped.get(other, "")) == id:
			state.acc_equipped.erase(other)
	state.acc_equipped[slot] = id
	refresh_stats()
	return true


func unequip_accessory(slot: String) -> void:
	state.acc_equipped.erase(slot)
	refresh_stats()


# --- Reciclado -----------------------------------------------------------------------------

func recycle_gain() -> int:
	return Prestige.pellets_for(state.pops_run, Cfg.num(eco, "pellet_divisor"), Cfg.num(eco, "pellet_exponent"))


## Pellets que pide la fase siguiente ("Lámina más grande"); -1 si ya están todas abiertas.
func next_phase_cost() -> float:
	var lvl: int = state.perm_level("perm_sheet")
	if lvl >= upgrades.max_level("perm_sheet"):
		return -1.0
	return upgrades.next_cost("perm_sheet", lvl)


## true si reciclando ahora alcanza para abrir la fase siguiente.
func next_phase_ready() -> bool:
	var cost: float = next_phase_cost()
	return cost > 0.0 and can_recycle() and state.pellets + float(recycle_gain()) >= cost and phase_gate_ok()


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
	_keep_after_recycle(previous)
	grant_factory_gifts()
	if big.is_active(state.big): # reciclar con el pedido en curso lo cancela sin multa (vuelve en la próxima lámina)
		state.big["status"] = BigOrder.IDLE
		state.big["next_at"] = state.phase_sheets + 1
	combo.reset()
	streak = 0 # la racha es de la corrida: reciclar empieza de cero
	refresh_stats()
	new_sheet()
	_echoes = []
	return gained


## "Automatización de fábrica" deja la Recarga automática COMPRADA (nivel 1 visible en la hoja de
## pedidos): nada se activa sin figurar como comprado.
func grant_factory_gifts() -> void:
	if state.perm_level("perm_auto") >= 1 and state.level("global_reload") < 1:
		state.levels["global_reload"] = 1


## Lo que se aprende una vez y no se olvida (por ejemplo "Mantener apretado") sobrevive al reciclado.
func _keep_after_recycle(previous: Dictionary) -> void:
	for id: String in upgrades.order:
		var keep: bool = upgrades.def(id).get("keep_on_recycle", false)
		if keep and previous.has(id):
			var lv: int = previous[id]
			state.levels[id] = lv


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
	state.streak = streak
	state.encargo = encargo.to_dict() if encargo != null else {}
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
	grant_factory_gifts()
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
			sheet.armor = restored.armor
			sheet.material = restored.material
			sheet.reset_counts()
			var pat: Dictionary = db.sheet["patterns"]
			vein_cells = SheetPatterns.veins_of(sheet, pat)
			_roll_encargo() # sobre la lámina restaurada (no sobre la que se armó al azar)
			if sheet.popped_ratio() >= sheet.reload_threshold: # se guardó con la lámina terminada
				if auto_reload():
					reload_timer = Cfg.num(eco, "reload_delay_auto")
				else:
					awaiting_reload = true
	streak = state.streak
	var saved: Encargo = Encargo.from_dict(state.encargo)
	if saved != null:
		encargo = saved
	return true
