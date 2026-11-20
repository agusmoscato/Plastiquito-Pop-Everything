extends GutTest

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 9)


func _bought(id: String) -> int:
	var r: Dictionary = sim.buy(id, 1)
	var n: int = r["bought"]
	return n


func test_every_scenario_with_a_next_one_has_a_big_order() -> void:
	for ph: int in [1, 2, 3, 4]:
		assert_true(sim.big.has_order(ph), "el escenario %d trae su pedido grande" % ph)


func test_order_appears_halfway_after_enough_sheets() -> void:
	sim.step(0.1, Vector2.ZERO, false)
	assert_false(sim.big.is_active(sim.state.big), "al arrancar todavía no")
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.big.is_active(sim.state.big))
	assert_true(sim.ev_big_started)
	assert_gt(Cfg.num(sim.state.big, "left"), 60.0)


func test_met_order_pays_once_and_multiplies_value() -> void:
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	var before_mult: float = Cfg.num(sim.stats, "value_mult")
	var pellets: float = sim.state.pellets
	sim.state.big["progress"] = 99999.0
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.ev_big_done)
	assert_true(sim.state.big_done.has("1"))
	assert_gt(sim.state.pellets, pellets, "recompensa en Pellets")
	assert_almost_eq(Cfg.num(sim.stats, "value_mult"), before_mult * 1.15, 0.0001)
	sim.step(0.1, Vector2.ZERO, false)
	assert_false(sim.big.is_active(sim.state.big), "no vuelve a aparecer")


func test_expired_order_fines_and_comes_back_easier() -> void:
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	var first_target: int = sim.big.target(sim.state.big)
	sim.state.pops = 1000.0
	sim.state.big["left"] = 0.05
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.ev_big_failed)
	assert_lt(sim.state.pops, 1000.0, "multa en Pops")
	assert_false(sim.state.big_done.has("1"))
	assert_false(sim.big.is_active(sim.state.big))
	assert_lt(sim.big.target(sim.state.big), first_target, "vuelve más fácil")
	assert_eq(Cfg.integer(sim.state.big, "next_at"), 4 + 3, "vuelve a las 3 láminas")


func test_order_kinds_progress_correctly() -> void:
	var st: Dictionary = BigOrder.fresh(2, 4)
	st["progress"] = 0.0
	sim.big.observe(st, {"chain": 50.0, "tool": "palm"})
	assert_eq(Cfg.num(st, "progress"), 0.0, "una cadena con la palma no cuenta")
	sim.big.observe(st, {"chain": 50.0, "tool": "finger"})
	assert_true(sim.big.is_met(st))
	var tp: Dictionary = BigOrder.fresh(3, 4)
	sim.big.observe(tp, {"material": {"thermal": 7.0}})
	sim.big.observe(tp, {"material": {"thermal": 5.0, "cold": 40.0}})
	assert_eq(Cfg.num(tp, "progress"), 12.0)
	var hv: Dictionary = BigOrder.fresh(4, 4)
	sim.big.observe(hv, {"heavy_stomp": 2.0})
	sim.big.observe(hv, {"heavy_stomp": 3.0})
	assert_true(sim.big.is_met(hv), "3 gigantes con una sola pisada")


func test_next_scenario_needs_big_order_tool_and_rate() -> void:
	sim.state.pellets = 1000.0
	var reqs: Array[Dictionary] = sim.phase_requirements()
	assert_eq(reqs.size(), 3, "tres requisitos visibles")
	assert_false(sim.phase_gate_ok())
	assert_eq(_bought("perm_sheet"), 0, "sin requisitos no se abre el escenario")
	sim.state.big_done["1"] = true
	sim.state.latched["1:tool"] = true
	assert_false(sim.phase_gate_ok(), "falta el ritmo")
	sim.state.latched["1:rate"] = true
	assert_true(sim.phase_gate_ok())
	assert_eq(_bought("perm_sheet"), 1)
	assert_eq(sim.phase(), 2)
	assert_eq(sim.state.phase_sheets, 0)


func test_tool_requirement_latches_and_survives_recycling() -> void:
	sim.state.levels["finger_force"] = 16
	for i: int in 40:
		sim.step(0.05, Vector2.ZERO, false)
	assert_true(sim.state.latched.has("1:tool"))
	sim.state.pops_run = 1.0e12
	sim.recycle()
	assert_true(sim.state.latched.has("1:tool"), "lo demostrado no se pierde al reciclar")


func test_big_state_is_saved() -> void:
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	var back: GameSim = GameSim.new(db, 2)
	assert_true(back.load_dict(sim.save_dict()))
	assert_true(back.big.is_active(back.state.big))
	assert_eq(back.state.phase_sheets, 4)
