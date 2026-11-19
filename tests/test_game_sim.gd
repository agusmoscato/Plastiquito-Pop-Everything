extends GutTest

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 7)


func _tool(id: String) -> ToolModel:
	var t: ToolModel = sim.tools[id]
	return t


func _int(d: Dictionary, key: String) -> int:
	var v: int = d[key]
	return v


func _flag(d: Dictionary, key: String) -> bool:
	var v: bool = d[key]
	return v


func test_new_game_state() -> void:
	assert_eq(sim.phase(), 1)
	assert_eq(sim.sheet.width, 8)
	assert_eq(sim.state.pops, 0.0)
	assert_true(sim.upgrades.tool_unlocked(sim.state, "finger"))
	assert_false(sim.upgrades.tool_unlocked(sim.state, "palm"))
	assert_false(sim.select_tool("palm"))


func test_pressing_pops_and_earns() -> void:
	_flat_sheet() # sin vetas: cuenta solo lo que revienta el dedo
	var c: Vector2 = sim.grid.cell_to_world(sim.grid.index(3, 3))
	for i: int in 30:
		sim.step(0.016, c, true)
	assert_gt(sim.state.pops, 0.0)
	assert_gt(sim.sheet.count_popped(), 0)
	assert_eq(_int(sim.state.tool_pops, "finger"), sim.sheet.count_popped())


func test_value_scales_with_pressure_squared() -> void:
	var c: int = sim.grid.index(4, 4)
	sim.sheet.pressure[c] = 2.0
	sim.sheet.refresh_state(c)
	sim.chain.clear_events()
	sim.chain.pop_now(c)
	sim._collect_events(false)
	var tense_value: float = sim.ev_value[0]
	var d: int = sim.grid.index(1, 1)
	sim._clear_events()
	sim.chain.clear_events()
	sim.chain.pop_now(d)
	sim._collect_events(false)
	assert_almost_eq(tense_value / sim.ev_value[0], 4.0, 0.001)


func test_golden_is_worth_ten_times() -> void:
	var a: int = sim.grid.index(2, 2)
	var b: int = sim.grid.index(6, 6)
	sim.sheet.type[a] = GameSim.TYPE_GOLDEN
	sim.sheet.pressure[a] = 1.0 # sin veta de aire debajo: misma presión en las dos
	sim.sheet.pressure[b] = 1.0
	sim.chain.pop_now(a)
	sim.chain.pop_now(b)
	sim._collect_events(false)
	assert_almost_eq(sim.ev_value[0] / sim.ev_value[1], 10.0, 0.001)


func test_buy_spends_and_levels_up() -> void:
	sim.state.pops = 1.0e6
	var r: Dictionary = sim.buy("finger_force", 1)
	assert_eq(_int(r, "bought"), 1)
	assert_eq(sim.state.level("finger_force"), 1)
	assert_almost_eq(sim.state.pops, 1.0e6 - sim.upgrades.next_cost("finger_force", 0), 0.001)
	var before_force: float = _tool("finger").force_per_second
	sim.buy("finger_force", 5)
	assert_gt(_tool("finger").force_per_second, before_force, "la compra cambia la herramienta real")
	assert_eq(_int(sim.buy("palm_force", 1), "bought"), 0, "requiere desbloquear la palma")


func test_buy_max_and_cannot_exceed_budget() -> void:
	sim.state.pops = sim.upgrades.next_cost("finger_force", 0) * 12.0
	var r: Dictionary = sim.buy("finger_force", -1)
	assert_gt(_int(r, "bought"), 1)
	assert_true(sim.state.pops >= 0.0)
	assert_false(sim.can_afford_next("finger_force") and sim.state.pops < sim.upgrades.next_cost("finger_force", sim.state.level("finger_force")))


func test_milestone_flag_at_25_levels() -> void:
	sim.state.pops = 1.0e15
	var r: Dictionary = sim.buy("finger_force", 24)
	assert_false(_flag(r, "milestone"))
	r = sim.buy("finger_force", 1)
	assert_true(_flag(r, "milestone"))
	assert_almost_eq(sim.upgrades.effect("finger_force", 25), (1.0 + 0.2 * 25.0) * 2.0, 0.01)


func test_unlock_palm_then_select() -> void:
	sim.state.pops = 1.0e6
	assert_false(sim.upgrades.is_available(sim.state, "unlock_palm"), "la palma no se ofrece al arrancar")
	sim.buy("global_hold", 1)
	sim.buy("unlock_palm", 1)
	assert_true(sim.select_tool("palm"))
	assert_eq(sim.selected_tool().shape, "circle")
	assert_gt(sim.selected_tool().radius, 1.0)


func test_reload_waits_for_the_player_without_auto_reload() -> void:
	var total: int = sim.sheet.cell_count()
	for i: int in ceili(float(total) * 0.9):
		sim.sheet.pop(i)
	assert_true(sim.awaiting_reload, "sin la mejora la lámina terminada espera")
	var first: SheetModel = sim.sheet
	for i: int in 200:
		sim.step(0.016, Vector2.ZERO, false)
	assert_eq(sim.sheet, first, "no se recarga sola")
	assert_true(sim.request_reload())
	for i: int in 60:
		sim.step(0.016, Vector2.ZERO, false)
	assert_ne(sim.sheet, first)
	assert_eq(sim.sheet.count_popped(), 0)
	assert_false(sim.awaiting_reload)
	assert_false(sim.request_reload(), "la lámina nueva no se puede tirar")


func test_auto_reload_creates_new_sheet_after_90_percent() -> void:
	sim.state.levels["global_reload"] = 1
	sim.refresh_stats()
	var total: int = sim.sheet.cell_count()
	for i: int in ceili(float(total) * 0.9):
		sim.sheet.pop(i)
	assert_gt(sim.reload_timer, 0.0)
	var first: SheetModel = sim.sheet
	for i: int in 200:
		sim.step(0.016, Vector2.ZERO, false)
	assert_ne(sim.sheet, first)
	assert_eq(sim.sheet.count_popped(), 0)


func test_saved_finished_sheet_still_waits_for_reload() -> void:
	for i: int in ceili(float(sim.sheet.cell_count()) * 0.95):
		sim.sheet.pop(i)
	var data: Dictionary = sim.save_dict()
	var loaded: GameSim = GameSim.new(db, 7)
	assert_true(loaded.load_dict(data))
	assert_true(loaded.awaiting_reload, "al cargar una lámina terminada se puede tirar otra")


## Lámina pareja (sin vetas de aire): para medir herramientas sin cadenas de por medio.
func _flat_sheet() -> void:
	for i: int in sim.sheet.cell_count():
		sim.sheet.pressure[i] = 1.0
		sim.sheet.refresh_state(i)


func test_click_pops_one_and_hold_needs_the_upgrade() -> void:
	_flat_sheet()
	var c: Vector2 = sim.grid.cell_to_world(sim.grid.index(4, 4))
	var c2: Vector2 = sim.grid.cell_to_world(sim.grid.index(5, 4))
	sim.step(1.0 / 60.0, c, true)
	assert_eq(sim.sheet.state[sim.grid.index(4, 4)], SheetModel.STATE_POPPED, "un clic revienta la burbuja")
	var popped_before: int = sim.sheet.count_popped()
	for i: int in 60: # mantiene apretado y arrastra a la vecina
		sim.step(1.0 / 60.0, c.lerp(c2, float(i) / 59.0), true)
	assert_ne(sim.sheet.state[sim.grid.index(5, 4)], SheetModel.STATE_POPPED, "sin la mejora, arrastrar no revienta")
	assert_eq(sim.sheet.count_popped(), popped_before)
	sim.step(1.0 / 60.0, c2, false)
	sim.step(1.0 / 60.0, c2, true)
	assert_eq(sim.sheet.state[sim.grid.index(5, 4)], SheetModel.STATE_POPPED, "otro clic, otra burbuja")
	sim.state.pops = 1000.0
	assert_eq(_int(sim.buy("global_hold", 1), "bought"), 1)
	assert_lt(sim.upgrades.next_cost("global_hold", 0), 100.0, "mantener apretado es barato")
	var c3: Vector2 = sim.grid.cell_to_world(sim.grid.index(2, 2))
	var c4: Vector2 = sim.grid.cell_to_world(sim.grid.index(2, 6))
	sim.step(1.0 / 60.0, c3, false)
	var before_drag: int = sim.sheet.count_popped()
	for i: int in 60:
		sim.step(1.0 / 60.0, c3.lerp(c4, float(i) / 59.0), true)
	assert_gt(sim.sheet.count_popped(), before_drag + 2, "con la mejora, arrastrar revienta varias")


func test_hold_survives_recycle() -> void:
	sim.state.levels["global_hold"] = 1
	sim.state.pops_run = 1.0e8
	assert_gt(sim.recycle(), 0)
	assert_eq(sim.state.level("global_hold"), 1, "lo aprendido no se olvida")
	assert_true(sim.hold_unlocked())


func test_specials_only_after_first_recycle() -> void:
	var fresh: GameSim = GameSim.new(db, 3)
	fresh.stats["chance_golden"] = 0.5
	fresh.new_sheet()
	for t: int in fresh.sheet.type:
		assert_eq(t, 0, "antes del primer reciclado no hay especiales")
	assert_false(fresh.special_unlocked(GameSim.TYPE_GOLDEN))
	fresh.state.recycles = 1
	assert_true(fresh.special_unlocked(GameSim.TYPE_GOLDEN))
	assert_false(fresh.special_unlocked(GameSim.TYPE_BOMB), "la bomba llega en el Piso")
	assert_false(fresh.special_unlocked(GameSim.TYPE_ECHO))


func test_chain_event_reported_when_it_ends() -> void:
	sim.sheet.type[sim.grid.index(4, 4)] = GameSim.TYPE_BOMB
	sim.chain.pop_now(sim.grid.index(4, 4))
	var ended: int = 0
	for i: int in 200:
		sim.step(0.016, Vector2.ZERO, false)
		if sim.ev_chain_ended_count > 0:
			ended = sim.ev_chain_ended_count
			break
	assert_gt(ended, 10)
	assert_eq(sim.state.max_chain, ended)


func test_recycle_flow_and_permanent_upgrades() -> void:
	assert_false(sim.can_recycle())
	assert_eq(sim.recycle(), 0)
	sim.state.pops_run = 4.0 * Cfg.num(db.economy, "pellet_divisor")
	sim.state.pops = 1234.0
	sim.state.levels["finger_force"] = 3
	assert_eq(sim.recycle_gain(), 2)
	var sheets_before: SheetModel = sim.sheet
	assert_eq(sim.recycle(), 2)
	assert_eq(sim.state.pellets, 2.0)
	assert_eq(sim.state.pops, 0.0)
	assert_eq(sim.state.level("finger_force"), 0, "las mejoras normales se pierden")
	assert_eq(sim.state.recycles, 1)
	assert_ne(sim.sheet, sheets_before)
	assert_eq(_int(sim.buy("perm_sheet", 1), "bought"), 1)
	assert_eq(sim.phase(), 2)
	sim.state.pellets += 5.0
	sim.new_sheet()
	assert_eq(sim.sheet.width, 20, "el Piso arranca con una lámina como la última de la Mesa")
	assert_eq(_int(sim.buy("perm_finger", 1), "bought"), 1)
	assert_eq(sim.state.level("finger_force"), 0)
	assert_gt(_tool("finger").force_per_second, 6.0, "el dedo arranca mejorado")


func test_save_roundtrip_identical() -> void:
	sim.state.pops = 12345.0
	sim.state.levels["finger_force"] = 4
	sim.state.perm["perm_bonus"] = 2
	sim.state.discover(1)
	sim.sheet.pop(5)
	var data: Dictionary = sim.save_dict()
	var json_text: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary)
	var parsed_dict: Dictionary = parsed
	var other: GameSim = GameSim.new(db, 99)
	assert_true(other.load_dict(parsed_dict))
	assert_eq(other.state.pops, 12345.0)
	assert_eq(other.state.level("finger_force"), 4)
	assert_eq(other.state.perm_level("perm_bonus"), 2)
	assert_true(other.state.is_discovered(1))
	assert_eq(other.sheet.state, sim.sheet.state)
	assert_eq(other.sheet.type, sim.sheet.type)
	assert_eq(other.save_dict(), sim.save_dict())


func test_migrate_from_phase1_save() -> void:
	var old: SheetModel = SheetModel.new(8, 8)
	old.pop(3)
	var v1: Dictionary = old.to_dict()
	assert_eq(_int(v1, "version"), 1)
	var migrated: Dictionary = GameState.migrate(v1)
	assert_false(migrated.is_empty())
	assert_eq(_int(migrated, "version"), GameState.SAVE_VERSION)
	assert_true(sim.load_dict(v1))
	assert_eq(sim.state.pops, 0.0)
	assert_eq(sim.sheet.state[3], SheetModel.STATE_POPPED)


func test_invalid_saves_rejected() -> void:
	assert_false(sim.load_dict({}))
	assert_false(sim.load_dict({"version": 99}))
	assert_true(GameState.migrate({"version": 2, "pops": 1}).is_empty())


func test_specials_generated_and_discovered_once() -> void:
	var rich: GameSim = GameSim.new(db, 3)
	rich.state.recycles = 1
	rich.stats["chance_golden"] = 0.5
	rich.new_sheet()
	var golden: int = 0
	for t: int in rich.sheet.type:
		if t == GameSim.TYPE_GOLDEN:
			golden += 1
	assert_gt(golden, 10)
	assert_true(rich.state.is_discovered(GameSim.TYPE_GOLDEN))
	rich._clear_events()
	rich.new_sheet()
	assert_eq(rich.ev_new_specials.size(), 0, "ya conocida: no vuelve a avisar")


func test_all_upgrade_descriptions_short() -> void:
	for u: Dictionary in db.upgrades:
		assert_lte(str(u["desc_es"]).length(), 60, str(u["id"]))
		assert_lte(str(u["desc_en"]).length(), 60, str(u["id"]))
		assert_false(str(u["desc_es"]).contains("!!"), str(u["id"]))


func test_sheets_come_with_air_veins_that_chain() -> void:
	assert_gt(sim.vein_cells.size(), 3, "la lámina trae vetas de aire")
	for idx: int in sim.vein_cells:
		assert_eq(sim.sheet.state[idx], SheetModel.STATE_TENSE, "las vetas se ven tensas")
	var line: SheetModel = SheetModel.new(12, 12)
	var g: HexGrid = HexGrid.new(12, 12, 0.5)
	var cells: PackedInt32Array = PackedInt32Array()
	for x: int in range(2, 10):
		cells.append(g.index(x, 6))
		line.pressure[g.index(x, 6)] = 1.9
	var ch: ChainSolver = ChainSolver.new(line, g)
	ch.k = 0.5
	ch.pop_now(cells[0])
	for i: int in 40:
		ch.step()
	var popped: int = 0
	for idx: int in cells:
		if line.state[idx] == SheetModel.STATE_POPPED:
			popped += 1
	assert_eq(popped, cells.size(), "reventar la punta encadena la veta entera")
	assert_lt(line.count_popped(), cells.size() + 3, "y no se desparrama por la lámina")


func test_armor_needs_two_presses_but_chains_pop_it() -> void:
	sim.state.levels["global_hold"] = 1
	sim.refresh_stats()
	var idx: int = sim.grid.index(4, 4)
	sim.sheet.pressure[idx] = 1.0
	sim.sheet.armor[idx] = 1
	var p: Vector2 = sim.grid.cell_to_world(idx)
	var i: int = 0
	while sim.sheet.armor[idx] == 1 and i < 120:
		sim.step(1.0 / 60.0, p, true)
		i += 1
	assert_eq(sim.sheet.state[idx], SheetModel.STATE_INTACT, "la primera aplastada rompe solo el doble film")
	for k: int in 120:
		sim.step(1.0 / 60.0, p, true)
	assert_eq(sim.sheet.state[idx], SheetModel.STATE_POPPED, "la segunda la revienta")
	var other: int = sim.grid.index(1, 1)
	sim.sheet.armor[other] = 1
	sim.chain.pop_now(other)
	assert_eq(sim.sheet.state[other], SheetModel.STATE_POPPED, "una cadena la revienta igual")
	var data: Dictionary = sim.sheet.to_dict()
	var back: SheetModel = SheetModel.new()
	assert_true(back.from_dict(data))
	assert_eq(back.armor[other], 1, "el doble film se guarda")


func test_armor_only_from_the_warehouse() -> void:
	for t: int in sim.sheet.armor:
		assert_eq(t, 0, "en la Mesa no hay doble film")
	var w: GameSim = GameSim.new(db, 9)
	w.state.perm["perm_sheet"] = 2
	w.refresh_stats()
	w.new_sheet()
	var hard: int = 0
	for t: int in w.sheet.armor:
		hard += t
	assert_gt(hard, 0, "en el Galpón aparece")


func test_encargo_pays_and_builds_a_streak() -> void:
	sim.encargo = Encargo.new()
	sim.encargo.kind = "chain"
	sim.encargo.target = 3
	var before: float = sim.state.pops
	sim.chain_count = 5
	sim._track_encargo()
	assert_true(sim.ev_encargo_done)
	assert_gt(sim.state.pops, before, "paga un bono")
	assert_eq(sim.streak, 1)
	assert_gt(sim.streak_mult(), 1.0, "la racha sube el valor de los Pops")
	sim.encargo = Encargo.new()
	sim.encargo.kind = "combo"
	sim.encargo.target = 4
	sim._sheet_finished = true
	sim._track_encargo()
	assert_true(sim.ev_encargo_failed)
	assert_eq(sim.streak, 0, "terminar la lámina sin cumplirlo corta la racha")


func test_encargo_targets_grow_with_phase() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var cfg: Dictionary = db.economy["encargos"]
	var small: int = 0
	var big: int = 0
	for i: int in 30:
		rng.seed = i
		var a: Encargo = Encargo.roll(rng, 1, 64, 0, 0, cfg)
		rng.seed = i
		var b: Encargo = Encargo.roll(rng, 4, 110 * 110, 0, 0, cfg)
		if a.kind == "chain" and b.kind == "chain":
			small = a.target
			big = b.target
	assert_gt(big, small, "más fase y más lámina, cadena más larga")
