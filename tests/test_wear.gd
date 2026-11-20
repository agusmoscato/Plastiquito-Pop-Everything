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
