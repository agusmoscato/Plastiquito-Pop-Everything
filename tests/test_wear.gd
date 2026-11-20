extends GutTest

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 11)
	sim.state.pops = 1.0e12
	for id: String in ["global_hold", "unlock_palm", "unlock_pin", "unlock_iron", "unlock_boot"]:
		sim.state.levels[id] = 1
	sim.refresh_stats()


func _drive(tool_id: String, seconds: float) -> void:
	sim.select_tool(tool_id)
	var c: Vector2 = sim.center()
	var t: float = 0.0
	while t < seconds:
		var p: Vector2 = c + Vector2(sin(t * 3.0) * 6.0, cos(t * 2.0) * 6.0)
		if sim.awaiting_reload or sim.sheet.popped_ratio() > 0.5:
			sim.new_sheet() # lámina fresca: que siempre haya algo bajo la herramienta
		sim.step(0.033, p, true)
		t += 0.033


func test_hands_and_roller_never_tire() -> void:
	assert_false(sim.wear.has("hands"), "las manitos no tienen medidor")
	assert_eq(sim.wear_fraction("hands"), 0.0)


func test_iron_overheats_and_locks() -> void:
	_drive("iron", 30.0)
	assert_true(sim.tool_locked("iron"), "la plancha se recalienta y se traba")


func test_iron_cools_down_when_resting() -> void:
	_drive("iron", 30.0)
	assert_true(sim.tool_locked("iron"))
	sim.select_tool("finger")
	for i: int in 400:
		sim.step(0.033, sim.center(), false)
	assert_false(sim.tool_locked("iron"), "descansando se enfría y vuelve")
	assert_lt(sim.wear_fraction("iron"), 0.35)


func test_locked_tool_does_not_pop() -> void:
	_drive("iron", 30.0)
	var before: float = sim.state.pops
	sim.step(0.033, sim.center(), true)
	assert_eq(sim.state.pops, before, "trabada no reviente nada")


func test_boot_stomps_are_limited() -> void:
	sim.select_tool("boot")
	var c: Vector2 = sim.center()
	var stomps: int = 0
	for i: int in 400:
		var before: int = sim.state.tool_pops.get("boot", 0)
		sim.step(0.1, c, i % 2 == 0)
		var after: int = sim.state.tool_pops.get("boot", 0)
		if after > before:
			stomps += 1
	assert_true(sim.tool_locked("boot") or stomps <= 12, "la bota no pisotea sin límite")
	assert_gt(sim.wear_fraction("boot"), 0.0)


func test_upgrades_raise_capacity_but_never_remove_the_limit() -> void:
	var base: float = sim.wear["iron"].capacity
	sim.state.levels["iron_speed"] = 6
	sim.refresh_stats()
	var better: float = sim.wear["iron"].capacity
	assert_gt(better, base)
	assert_gt(better, 0.0)
	assert_true(sim.wear["iron"].tires())


func test_wear_model_basic() -> void:
	var w: WearModel = WearModel.new()
	w.configure(10.0, 1.0, 2.0, 0.5)
	for i: int in 20:
		w.use(1.0)
		w.tick(1.0)
	assert_true(w.locked)
	w.tick(1.0)
	assert_true(w.locked, "todavía muy caliente")
	for i: int in 3:
		w.tick(1.0)
	assert_false(w.locked)


func _material_sim(phase: int, mat: int) -> GameSim:
	var s: GameSim = GameSim.new(db, 5)
	s.state.perm["perm_sheet"] = phase - 1
	s.state.levels["global_hold"] = 1
	for id: String in ["unlock_palm", "unlock_pin", "unlock_iron", "unlock_boot"]:
		s.state.levels[id] = 1
	s.refresh_stats()
	s.new_sheet()
	for i: int in s.sheet.cell_count():
		s.sheet.pressure[i] = 1.0
		s.sheet.refresh_state(i)
		s.sheet.material[i] = mat
		s.sheet.armor[i] = 0
	return s


func _pops_with(tool_id: String, mat: int, seconds: float) -> int:
	var s: GameSim = _material_sim(4, mat)
	s.select_tool(tool_id)
	var c: Vector2 = s.center()
	var t: float = 0.0
	while t < seconds:
		s.step(0.033, c + Vector2(sin(t * 3.0) * 8.0, cos(t * 2.0) * 8.0), true)
		t += 0.033
	return s.sheet.count_popped()


func test_iron_cannot_press_thermal_film() -> void:
	assert_eq(_pops_with("iron", SheetModel.MAT_THERMAL, 4.0), 0, "la plancha no derrite el film térmico")
	assert_gt(_pops_with("boot", SheetModel.MAT_THERMAL, 4.0), 0, "la bota sí")


func test_boot_beats_everyone_on_heavy_bubbles() -> void:
	var boot: int = _pops_with("boot", SheetModel.MAT_HEAVY, 6.0)
	for id: String in ["finger", "palm", "rolling_pin"]:
		assert_gt(boot, 2 * _pops_with(id, SheetModel.MAT_HEAVY, 6.0), "la bota rinde el doble en pesadas que " + id)


func test_iron_softens_cold_bubbles() -> void:
	var s: GameSim = _material_sim(2, SheetModel.MAT_COLD)
	s.select_tool("iron")
	var c: Vector2 = s.center()
	for i: int in 60:
		s.step(0.033, c + Vector2(float(i) * 0.4 - 12.0, 0.0), true)
	var warmed: int = 0
	for m: int in s.sheet.material:
		if m == SheetModel.MAT_NORMAL:
			warmed += 1
	assert_gt(warmed, 0, "al pasar, la plancha ablanda burbujas frías")


func test_materials_appear_by_scenario_and_are_saved() -> void:
	var f: GameSim = GameSim.new(db, 3)
	f.state.perm["perm_sheet"] = 1
	f.refresh_stats()
	f.new_sheet()
	var cold: int = 0
	for m: int in f.sheet.material:
		if m == SheetModel.MAT_COLD:
			cold += 1
	assert_gt(cold, 0, "el Piso trae burbujas frías")
	var t: GameSim = GameSim.new(db, 3)
	for m: int in t.sheet.material:
		assert_eq(m, 0, "la Mesa no trae materiales")
	var back: SheetModel = SheetModel.new()
	assert_true(back.from_dict(f.sheet.to_dict()))
	assert_eq(back.material, f.sheet.material)
