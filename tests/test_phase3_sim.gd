extends GutTest

const W: int = 14
const H: int = 12

var db: DataDB
var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	_make(1, 1.0, 1.0)


func _make(seed_value: int, lo: float, hi: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	sheet = SheetModel.new(W, H)
	grid = HexGrid.new(W, H, 0.5)
	for i: int in sheet.cell_count():
		sheet.pressure[i] = rng.randf_range(lo, hi)
		sheet.refresh_state(i)
	chain = ChainSolver.new(sheet, grid)
	chain.k = 0.5
	chain.budget_per_frame = 30


func _iron() -> ToolModel:
	var tm: ToolModel = ToolModel.new(sheet, grid)
	tm.shape = "rect"
	tm.radius = 2.5
	tm.heat_rate = 0.5
	tm.heat_cap = 1.4
	tm.heat_reach = 1.6
	return tm


func _boot() -> ToolModel:
	var tm: ToolModel = ToolModel.new(sheet, grid)
	tm.shape = "stomp"
	tm.radius = 3.0
	tm.cooldown = 4.0
	tm.wave_k = 0.5
	tm.wave_reach = 2.5
	return tm


func test_heat_inflates_nearby_up_to_cap_only() -> void:
	var iron: ToolModel = _iron()
	var center: Vector2 = grid.cell_to_world(grid.index(7, 6))
	var far: int = grid.index(0, 0)
	var near: int = grid.index(7, 6)
	for i: int in 200:
		iron.apply_heat(center, 0.05)
	assert_almost_eq(sheet.pressure[near], 1.4, 0.0001, "sube hasta el tope y no más")
	assert_gt(sheet.pressure[near], 1.39, "calentada: queda a un paso de tensarse antes de tocarla")
	assert_eq(sheet.pressure[far], 1.0, "lejos del aura no cambia")
	for i: int in sheet.cell_count():
		assert_true(sheet.pressure[i] <= 1.4 + 0.0001)


func test_heat_ignores_popped_cells() -> void:
	var iron: ToolModel = _iron()
	var idx: int = grid.index(7, 6)
	sheet.pop(idx)
	iron.apply_heat(grid.cell_to_world(idx), 1.0)
	assert_eq(sheet.state[idx], SheetModel.STATE_POPPED)


func test_heated_sheet_chain_never_creates_air() -> void:
	var iron: ToolModel = _iron()
	for i: int in 100:
		iron.apply_heat(grid.cell_to_world(grid.index(7, 6)), 0.05)
	chain.enqueue(grid.index(7, 6))
	var total: float = sheet.total_pressure()
	var guard: int = 0
	while not chain.is_idle() and guard < 400:
		chain.step()
		var now_total: float = sheet.total_pressure()
		assert_true(now_total <= total + 0.0001)
		total = now_total
		guard += 1


func test_stomp_wave_conserves_air_fuzz() -> void:
	for seed_value: int in 200:
		_make(seed_value, 0.6, 1.9)
		var boot: ToolModel = _boot()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var center: Vector2 = grid.cell_to_world(rng.randi() % sheet.cell_count())
		var before: float = sheet.total_pressure()
		var popped: PackedInt32Array = boot.stomp(center, chain.k)
		for idx: int in popped:
			chain.pop_now(idx)
		assert_true(sheet.total_pressure() <= before + 0.0001, "seed %d" % seed_value)


func test_stomp_pushes_pressure_outward() -> void:
	var boot: ToolModel = _boot()
	var center: Vector2 = grid.cell_to_world(grid.index(7, 6))
	var ring_cell: int = grid.world_to_cell(center + Vector2(boot.radius + 1.0, 0.0))
	var before: float = sheet.pressure[ring_cell]
	boot.stomp(center, 0.0)
	assert_gt(sheet.pressure[ring_cell], before)


func test_stomp_cooldown_recharges() -> void:
	var boot: ToolModel = _boot()
	var center: Vector2 = grid.cell_to_world(grid.index(7, 6))
	assert_gt(boot.stomp(center, 0.5).size(), 0)
	assert_false(boot.stomp_ready())
	assert_eq(boot.stomp(center + Vector2(5.0, 0.0), 0.5).size(), 0, "sin recarga no pisa")
	boot.tick_cooldown(3.9)
	assert_false(boot.stomp_ready())
	boot.tick_cooldown(0.2)
	assert_true(boot.stomp_ready())
	assert_gt(boot.stomp(center + Vector2(5.0, 0.0), 0.5).size(), 0)


func test_echo_reinflates_exactly_once() -> void:
	var sim: GameSim = GameSim.new(db, 3)
	var idx: int = sim.grid.index(3, 3)
	sim.sheet.type[idx] = GameSim.TYPE_ECHO
	sim.chain.clear_events()
	sim.chain.pop_now(idx)
	sim._collect_events(false)
	assert_eq(sim.sheet.state[idx], SheetModel.STATE_POPPED)
	for i: int in 50:
		sim.step(0.016, Vector2.ZERO, false)
	assert_eq(sim.sheet.state[idx], SheetModel.STATE_POPPED, "todavía no pasaron 2 s")
	var revived: int = 0
	for i: int in 100:
		sim.step(0.016, Vector2.ZERO, false)
		revived += sim.ev_revived.size()
	assert_eq(revived, 1)
	assert_ne(sim.sheet.state[idx], SheetModel.STATE_POPPED)
	assert_eq(sim.sheet.type[idx], 0, "vuelve como burbuja normal")
	sim.chain.clear_events()
	sim.chain.pop_now(idx)
	sim._collect_events(false)
	for i: int in 300:
		sim.step(0.016, Vector2.ZERO, false)
		assert_eq(sim.ev_revived.size(), 0, "no se infla una segunda vez")
	assert_eq(sim.sheet.state[idx], SheetModel.STATE_POPPED)


func test_hands_respect_rate_and_skip_popped() -> void:
	var hands: HandsModel = HandsModel.new(sheet, grid, 4)
	hands.set_count(3)
	hands.rate = 2.0
	var touches: int = 0
	for i: int in 600:
		touches += hands.step(1.0 / 60.0).size()
	assert_almost_eq(float(touches), 60.0, 3.0, "3 manitos x 2 toques/s x 10 s")
	for i: int in sheet.cell_count():
		if i % 10 != 0:
			sheet.pop(i)
	for i: int in 600:
		for idx: int in hands.step(1.0 / 60.0):
			assert_ne(sheet.state[idx], SheetModel.STATE_POPPED)
	for i: int in sheet.cell_count():
		sheet.pop(i)
	assert_eq(hands.step(1.0).size(), 0, "sin burbujas no toca nada")


func test_hands_zero_count_does_nothing() -> void:
	var hands: HandsModel = HandsModel.new(sheet, grid, 4)
	assert_eq(hands.step(10.0).size(), 0)


func test_auto_roller_sweeps_only_intact() -> void:
	var roller: AutoRoller = AutoRoller.new(sheet, grid)
	roller.enabled = true
	roller.speed = 6.0
	roller.half_width = 2.0
	var seen: Dictionary = {}
	for i: int in 3000:
		for idx: int in roller.step(1.0 / 60.0):
			assert_ne(sheet.state[idx], SheetModel.STATE_POPPED)
			seen[idx] = true
			sheet.pop(idx)
	assert_gt(seen.size(), sheet.cell_count() * 8 / 10, "barre casi toda la lámina")
	roller.enabled = false
	assert_eq(roller.step(1.0).size(), 0)


func test_offline_earnings_cap_efficiency_and_clock() -> void:
	var r: Dictionary = OfflineEarnings.compute(10000.0, 9000.0, 9000.0, 2.0, 1.0, 10.0, 0.5, 2.0)
	assert_eq(Cfg.num(r, "hands_pops"), 1000.0)
	assert_eq(Cfg.num(r, "roller_pops"), 500.0)
	assert_eq(Cfg.num(r, "pops"), 15000.0)
	var capped: Dictionary = OfflineEarnings.compute(1.0e6, 0.5e6, 0.5e6, 1.0, 0.0, 1.0, 0.5, 2.0)
	assert_eq(Cfg.num(capped, "seconds"), 7200.0, "tope de 2 horas")
	var back: Dictionary = OfflineEarnings.compute(5000.0, 9000.0, 9000.0, 2.0, 1.0, 10.0, 0.5, 2.0)
	assert_eq(Cfg.num(back, "pops"), 0.0, "el reloj atrasado no da nada")
	assert_true(Cfg.flag(back, "clock_cheat"))
	var rollback: Dictionary = OfflineEarnings.compute(9500.0, 9000.0, 20000.0, 2.0, 1.0, 10.0, 0.5, 2.0)
	assert_eq(Cfg.num(rollback, "pops"), 0.0, "si ya se vio una hora posterior tampoco")
	var first: Dictionary = OfflineEarnings.compute(9500.0, 0.0, 0.0, 2.0, 1.0, 10.0, 0.5, 2.0)
	assert_eq(Cfg.num(first, "pops"), 0.0, "sin guardado previo no hay ganancias")


func test_game_sim_offline_uses_automation() -> void:
	var sim: GameSim = GameSim.new(db, 2)
	sim.state.perm["perm_sheet"] = 2
	sim.state.levels["unlock_hands"] = 1
	sim.state.levels["hands_count"] = 4
	sim.refresh_stats()
	var data: Dictionary = sim.save_dict(1000000.0)
	var back: GameSim = GameSim.new(db, 3)
	assert_true(back.load_dict(data))
	var res: Dictionary = back.compute_offline(1000600.0)
	assert_gt(Cfg.num(res, "pops"), 0.0)
	var before: float = back.state.pops
	back.apply_offline(res, 1000600.0)
	assert_gt(back.state.pops, before)
	var cheat: Dictionary = back.compute_offline(1000100.0)
	assert_eq(Cfg.num(cheat, "pops"), 0.0)


func test_save_v4_roundtrip_and_v2_v3_migration() -> void:
	var sim: GameSim = GameSim.new(db, 6)
	sim.state.last_levels = {"finger_force": 7}
	var data: Dictionary = sim.save_dict(555.0)
	assert_eq(Cfg.integer(data, "version"), 4)
	var other: GameSim = GameSim.new(db, 8)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_true(other.load_dict(parsed))
	assert_eq(other.state.saved_at_unix, 555.0)
	assert_eq(Cfg.integer(other.state.last_levels, "finger_force"), 7)
	var v2: Dictionary = data.duplicate(true)
	v2["version"] = 2
	v2.erase("last_levels")
	v2.erase("saved_at_unix")
	v2.erase("max_unix_seen")
	v2.erase("offline_total")
	var migrated: Dictionary = GameState.migrate(v2)
	assert_false(migrated.is_empty())
	assert_eq(Cfg.integer(migrated, "version"), 4)
	assert_eq(Cfg.integer(migrated, "run_buys"), 0)
	assert_true(other.load_dict(v2))
	assert_eq(other.state.saved_at_unix, 0.0)
	var v3: Dictionary = data.duplicate(true)
	v3["version"] = 3
	v3.erase("run_buys")
	assert_true(other.load_dict(v3))
	assert_eq(other.state.run_buys, 0)


func test_memory_restores_part_of_previous_levels() -> void:
	var sim: GameSim = GameSim.new(db, 4)
	sim.state.perm["perm_memory"] = 2
	sim.state.perm["perm_bonus"] = 1
	sim.state.levels["finger_force"] = 20
	sim.state.pops_run = 5.0 * Cfg.num(db.economy, "pellet_divisor")
	sim.recycle()
	assert_eq(sim.state.level("finger_force"), 2, "10% de 20 niveles")
	assert_eq(Cfg.integer(sim.state.last_levels, "finger_force"), 20)


func test_phase_progression_to_four() -> void:
	var sim: GameSim = GameSim.new(db, 5)
	sim.state.perm["perm_sheet"] = 3
	sim.refresh_stats()
	sim.new_sheet()
	assert_eq(sim.phase(), 4)
	assert_eq(sim.sheet.width, 150)
	sim.state.levels["unlock_boot"] = 1
	sim.state.levels["unlock_iron"] = 1
	assert_true(sim.select_tool("boot"))
	assert_true(sim.select_tool("iron"))


func test_boot_in_game_sim_stomps_once_per_press() -> void:
	var sim: GameSim = GameSim.new(db, 5)
	sim.state.perm["perm_sheet"] = 3
	sim.state.levels["unlock_boot"] = 1
	sim.refresh_stats()
	sim.new_sheet()
	sim.select_tool("boot")
	var c: Vector2 = sim.center()
	sim.step(0.016, c, true)
	for i: int in 120:
		sim.step(0.016, c, false) # deja terminar la onda y la cadena
	var first: int = sim.sheet.count_popped()
	assert_gt(first, 5)
	sim.step(0.016, c + Vector2(6.0, 0.0), true)
	for i: int in 40:
		sim.step(0.016, c + Vector2(6.0, 0.0), true)
	assert_eq(sim.sheet.count_popped(), first, "mantener apretado no vuelve a pisar mientras recarga")
	assert_gt(sim.selected_tool().cooldown_left, 0.0)


func test_new_upgrade_text_limits() -> void:
	for u: Dictionary in db.upgrades:
		assert_lte(str(u["desc_es"]).length(), 60, str(u["id"]))
		assert_lte(str(u["desc_en"]).length(), 60, str(u["id"]))


func test_special_cap_grows_with_root_of_area() -> void:
	var sim: GameSim = GameSim.new(db, 12)
	sim.state.perm["perm_sheet"] = 3 # Estacionamiento: 22.500 celdas
	sim.state.levels["golden_chance"] = 10
	sim.refresh_stats()
	sim.new_sheet()
	var count: int = 0
	for i: int in sim.sheet.cell_count():
		if sim.sheet.type[i] != 0:
			count += 1
	var cap: int = roundi(Cfg.num(sim.eco, "special_cap_k") * sqrt(float(sim.sheet.cell_count())))
	assert_lte(count, cap)


func test_new_phase_discount_applies_to_first_buys_only() -> void:
	var sim: GameSim = GameSim.new(db, 13)
	sim.state.perm["perm_sheet"] = 1 # Piso
	sim.refresh_stats()
	var full: float = sim.upgrades.next_cost("finger_force", 1)
	assert_eq(sim.state.run_buys, 0)
	assert_lt(full, sim.upgrades.next_cost("finger_force", 1) * 1.0001)
	sim.state.pops = 1.0e12
	sim.buy("finger_force", 3)
	assert_eq(sim.state.run_buys, 3)
	assert_eq(sim.upgrades.discount, 1.0)
	assert_gt(sim.upgrades.next_cost("finger_force", 3), 0.0)
