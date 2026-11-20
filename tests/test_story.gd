extends GutTest

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 5)


func test_welcome_then_first_client_once() -> void:
	sim.step(0.1, Vector2.ZERO, false)
	assert_eq(sim.current_memo(), "welcome")
	sim.dismiss_memo()
	assert_eq(sim.current_memo(), "first_client")
	sim.dismiss_memo()
	sim.step(0.1, Vector2.ZERO, false)
	assert_eq(sim.current_memo(), "", "los memos de una vez no se repiten")


func test_welcome_uses_the_player_name_and_fallback() -> void:
	assert_string_contains(sim.story.memo_text("welcome", "es", "Juan"), "Hola, Juan.")
	assert_string_contains(sim.story.memo_text("welcome", "es", "Juan"), "Departamento de Reventones")
	assert_eq(sim.player_name("es"), "Empleado N° 4417", "sin nombre: empleado número")
	sim.state.employee_name = "Ana"
	assert_eq(sim.player_name("en"), "Ana")


func test_memos_are_short_and_bilingual() -> void:
	var memos: Dictionary = db.story["memos"]
	for id: String in memos:
		for lang: String in ["es", "en"]:
			var t: String = sim.story.memo_text(id, lang, "X", "Y")
			assert_ne(t, "", "%s/%s existe" % [id, lang])
			assert_lt(t.split("\n").size(), 4, "%s: 2-3 líneas como máximo" % id)


func test_rank_promotions_follow_recycles() -> void:
	assert_eq(sim.story.rank_name(sim.story.rank_index(0), "es"), "Pasante")
	assert_eq(sim.story.rank_name(sim.story.rank_index(2), "es"), "Reventador Junior")
	assert_eq(sim.story.rank_name(sim.story.rank_index(9), "es"), "Jefe de Cuadrilla")
	sim.step(0.1, Vector2.ZERO, false)
	sim.memo_queue.clear()
	sim.state.recycles = 2
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.memo_queue.has("promotion"))
	assert_string_contains(sim.memo_text_now("es"), "Reventador Junior") if sim.current_memo() == "promotion" else pass_test("hay otro memo antes")


func test_new_scenario_and_big_order_memos() -> void:
	sim.step(0.1, Vector2.ZERO, false)
	sim.memo_queue.clear()
	sim.state.perm["perm_sheet"] = 1
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.memo_queue.has("phase_2"))
	sim.memo_queue.clear()
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	sim.state.big["progress"] = 99999.0
	sim.step(0.1, Vector2.ZERO, false)
	assert_true(sim.memo_queue.has("big_done"))


func test_ending_telegram_stamp_and_freelance_mode() -> void:
	assert_false(sim.ending_pending)
	sim.trigger_ending()
	assert_true(sim.ending_pending, "el final se dispara desde el modo DEV")
	assert_true(sim.state.ending_done)
	assert_true(sim.state.freelance, "después del final: monotributista")
	assert_string_contains(sim.story.telegram_body("es"), "TOTALIDAD DEL STOCK")
	assert_eq(sim.story.telegram_header("es"), "TELEGRAMA COLACIONADO")
	assert_gt(sim.story.credits("es").size(), 2)
	var back: GameSim = GameSim.new(db, 1)
	assert_true(back.load_dict(sim.save_dict()))
	assert_true(back.state.freelance)
	assert_true(back.state.ending_done)


func test_normal_play_never_triggers_the_ending() -> void:
	for i: int in 200:
		sim.step(0.05, sim.center(), true)
	assert_false(sim.ending_pending, "en las builds de jugador solo termina el escenario 7")
