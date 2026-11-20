extends GutTest

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 3)


func test_catalog_has_twelve_to_sixteen_accessories_with_every_slot() -> void:
	var n: int = sim.acc.ids().size()
	assert_true(n >= 12 and n <= 16, "entre 12 y 16 accesorios (hay %d)" % n)
	var kinds: Dictionary = {}
	for id: String in sim.acc.ids():
		kinds[sim.acc.slot_kind(id)] = true
	for k: String in ["ring", "bracelet", "watch", "glove"]:
		assert_true(kinds.has(k), "hay accesorios de " + k)


func test_buy_needs_pellets_and_equips_in_a_free_slot() -> void:
	assert_false(sim.buy_accessory("ring_alpaca"), "sin Pellets no se compra")
	sim.state.pellets = 100.0
	assert_true(sim.buy_accessory("ring_alpaca"))
	assert_eq(sim.state.pellets, 97.0)
	assert_eq(str(sim.state.acc_equipped["ring0"]), "ring_alpaca")
	assert_false(sim.buy_accessory("ring_alpaca"), "no se compra dos veces")


func test_only_three_rings_fit_and_equip_replaces() -> void:
	sim.state.pellets = 1000.0
	for id: String in ["ring_alpaca", "ring_sello", "ring_turquesa", "ring_cobre"]:
		assert_true(sim.buy_accessory(id))
	assert_false(sim.state.acc_equipped.has("ring3"))
	assert_eq(sim.state.acc_equipped.size(), 3, "tres anillos equipados, el cuarto queda en el cajón")
	assert_true(sim.equip_accessory("ring0", "ring_cobre"))
	assert_eq(str(sim.state.acc_equipped["ring0"]), "ring_cobre")
	assert_false(sim.equip_accessory("bracelet", "ring_alpaca"), "un anillo no entra en la pulsera")


func test_accessories_survive_recycling_and_saving() -> void:
	sim.state.pellets = 100.0
	sim.buy_accessory("glove_cocina")
	sim.state.pops_run = 1.0e12
	sim.state.pops = 1.0e12
	sim.recycle()
	assert_true(sim.state.acc_owned.has("glove_cocina"), "no se pierde al reciclar")
	assert_eq(str(sim.state.acc_equipped["glove"]), "glove_cocina")
	var back: GameSim = GameSim.new(db, 4)
	assert_true(back.load_dict(sim.save_dict()))
	assert_eq(str(back.state.acc_equipped["glove"]), "glove_cocina")


func test_old_saves_migrate_without_accessories() -> void:
	var s: Dictionary = GameState.new().to_dict()
	s["version"] = 5
	s.erase("acc_owned")
	s.erase("acc_equipped")
	var st: GameState = GameState.new()
	assert_true(st.from_dict(s))
	assert_true(st.acc_owned.is_empty())


func _cap(id: String) -> float:
	var w: WearModel = sim.wear[id]
	return w.capacity


func _drain(id: String) -> float:
	var w: WearModel = sim.wear[id]
	return w.drain_per_second


func _force(id: String) -> float:
	var t: ToolModel = sim.tools[id]
	return t.force_per_second


func test_oven_mitt_makes_the_iron_last_longer() -> void:
	var base: float = _cap("iron")
	sim.state.pellets = 100.0
	sim.buy_accessory("glove_cocina")
	assert_almost_eq(_cap("iron"), base * 1.3, 0.001)


func test_alpaca_ring_slows_iron_heating() -> void:
	var base: float = _drain("iron")
	sim.state.pellets = 100.0
	sim.buy_accessory("ring_alpaca")
	assert_almost_eq(_drain("iron"), base * 0.8, 0.001)


func test_red_thread_adds_one_streak_and_watch_adds_deadline() -> void:
	var cap: int = sim.streak_cap()
	sim.state.pellets = 100.0
	sim.buy_accessory("bracelet_hilo")
	sim.buy_accessory("watch_abuela")
	assert_eq(sim.streak_cap(), cap + 1)
	assert_almost_eq(sim.big_order_time_mult(), 1.15, 0.0001)


func test_wool_glove_adds_finger_and_palm_force() -> void:
	var base: float = _force("finger")
	sim.state.pellets = 100.0
	sim.buy_accessory("glove_lana")
	assert_almost_eq(_force("finger"), base * 1.25, 0.001)
