extends GutTest

var db: DataDB
var up: Upgrades


func before_each() -> void:
	db = DataDB.new()
	db.load_all()
	up = Upgrades.new(db)


func test_tilt_is_deterministic_and_within_range() -> void:
	for id: String in up.order:
		var a: float = UiKit.tilt(id)
		assert_eq(a, UiKit.tilt(id), "la inclinación no cambia entre llamadas: %s" % id)
		assert_true(absf(a) <= deg_to_rad(1.5) + 0.0001, id)
	assert_ne(UiKit.tilt("finger_force"), UiKit.tilt("palm_size"), "no todas iguales")


func test_paper_polygon_deterministic() -> void:
	var r: Rect2 = Rect2(0.0, 0.0, 200.0, 80.0)
	assert_eq(UiKit.paper_polygon(r, "x"), UiKit.paper_polygon(r, "x"))
	assert_ne(UiKit.paper_polygon(r, "x"), UiKit.paper_polygon(r, "y"))


func test_effect_text_by_kind() -> void:
	assert_eq(up.effect_text("finger_force", 0, "en"), "x1.00")
	assert_eq(up.effect_text("finger_force", 5, "es"), "x2,00")
	assert_eq(up.effect_text("finger_size", 2, "en"), "+2.0")
	assert_eq(up.effect_text("global_special", 4, "en"), "+2.0%")
	assert_eq(up.effect_text("global_tense", 2, "en"), "1.44")
	assert_eq(up.effect_text("perm_bonus", 3, "en"), "+15%")
	assert_eq(up.effect_text("perm_sheet", 0, "en"), "Table")
	assert_eq(up.effect_text("perm_sheet", 1, "es"), "Piso")


func test_names_and_descriptions_in_both_languages() -> void:
	for id: String in up.order:
		assert_ne(up.name_of(id, "es"), "", id)
		assert_ne(up.name_of(id, "en"), "", id)
		assert_lte(up.desc_of(id, "es").length(), 60, id)


func test_save_file_roundtrip_and_missing() -> void:
	var path: String = "user://test_save_system.json"
	var sim: GameSim = GameSim.new(db, 5)
	sim.state.pops = 4321.0
	sim.state.levels["finger_force"] = 3
	assert_true(SaveSystem.write_file(path, sim.save_dict()))
	var back: Dictionary = SaveSystem.read_file(path)
	var other: GameSim = GameSim.new(db, 9)
	assert_true(other.load_dict(back))
	assert_eq(other.state.pops, 4321.0)
	assert_eq(other.state.level("finger_force"), 3)
	DirAccess.remove_absolute(path)
	assert_true(SaveSystem.read_file(path).is_empty())


func test_tx_has_both_languages_for_every_key() -> void:
	for key: Variant in Tx.T:
		var entry: Dictionary = Tx.T[key]
		assert_true(entry.has("es") and entry.has("en"), str(key))


func test_chain_stamp_goes_above_origin_inside_free_area() -> void:
	var free: Rect2 = Rect2(Vector2(10, 150), Vector2(1100, 600))
	var c: Vector2 = ChainStamp.stamp_center(Vector2(500, 600), Vector2(300, 76), free, Vector2.ZERO)
	assert_lt(c.y + 38.0, 600.0 - ChainStamp.LIFT + 0.1, "el sello queda arriba de la ola")
	var top: Vector2 = ChainStamp.stamp_center(Vector2(500, 160), Vector2(300, 76), free, Vector2.ZERO)
	assert_gt(top.y - 38.0, 149.0, "no se sale de la zona libre")
	var right: Vector2 = ChainStamp.stamp_center(Vector2(1200, 600), Vector2(300, 76), free, Vector2.ZERO)
	assert_lt(right.x + 150.0, free.end.x + 0.1, "no se mete en la hoja de pedidos")
	assert_eq(ChainStamp.stamp_center(Vector2(-1, -1), Vector2(300, 76), free, Vector2(7, 7)), Vector2(7, 7))


func test_chain_stamp_is_small_and_never_over_a_panel() -> void:
	var play_w: float = 1920.0 - 452.0
	var max_w: float = play_w * ChainStamp.MAX_PLAY_FRACTION
	for raw: float in [1.0, 1.8, 2.75]:
		var w: float = ChainStamp.BASE_W * ChainStamp.capped_scale(raw, max_w)
		assert_lte(w, play_w * 0.35 + 0.01, "el sello no pasa el 35 % del área de juego")
	var free: Rect2 = Rect2(Vector2(10, 150), Vector2(1430, 800))
	var panel: Rect2 = Rect2(Vector2(20, 150), Vector2(420, 260)) # p. ej. la orden de trabajo arriba a la izquierda
	var panels: Array[Rect2] = [panel]
	var stamp: Vector2 = Vector2(max_w, 120.0)
	for origin: Vector2 in [Vector2(200, 420), Vector2(150, 300), Vector2(700, 500), Vector2(-1, -1)]:
		var c: Vector2 = ChainStamp.place(origin, stamp, free, panels, Vector2(200, 250))
		var r: Rect2 = Rect2(c - stamp * 0.5, stamp)
		assert_false(r.intersects(panel), "el sello no tapa el panel (origen %s)" % str(origin))


func test_every_tool_and_upgrade_category_has_a_prerendered_icon() -> void:
	for id: String in ["finger", "palm", "rolling_pin", "iron", "boot", "hands", "auto_roller", "bubble"]:
		assert_true(ResourceLoader.exists(ToolIcon.DIR + ToolIcon.icon_name(id, "") + ".png"), id)
	for v: String in ["size", "force", "speed", "count", "smart", "automation", "auto_reload", "value", "global_bonus",
			"special_chance", "golden_chance", "tense", "chain_k", "memory", "sheet_size", "sheet_growth", "pin_start"]:
		assert_true(ResourceLoader.exists(ToolIcon.DIR + ToolIcon.icon_name("finger", v) + ".png"), v)
	assert_eq(ToolIcon.icon_name("iron", "special"), "iron", "las demás mejoras usan el ícono de su herramienta")


func test_flyers_cap_and_panels() -> void:
	var f: FlyingNumbers = FlyingNumbers.new()
	f.blocked = [Rect2(Vector2(0, 0), Vector2(200, 100))]
	for i: int in 30:
		f.spawn(Vector2(400 + i * 100, 400), 1.0)
	assert_eq(f.pending(), FlyingNumbers.MAX_ITEMS, "nunca más de 12 en pantalla")
	assert_false(Rect2(Vector2(0, 0), Vector2(200, 100)).has_point(f.outside_panels(Vector2(50, 50))), "no nace dentro de un panel")
	f.free()


func test_flyers_merge_instead_of_stacking() -> void:
	var f: FlyingNumbers = FlyingNumbers.new()
	f.spawn(Vector2(500, 400), 3.0)
	f.spawn(Vector2(520, 410), 4.0)
	f.spawn(Vector2(900, 400), 1.0)
	assert_eq(f.pending(), 2, "dos reventones juntos dan un solo número")
	f.free()


func test_paper_polygon_never_self_intersects_on_tiny_sheets() -> void:
	for h: float in [0.5, 1.0, 2.0, 3.0, 6.0]:
		var poly: PackedVector2Array = UiKit.paper_polygon(Rect2(Vector2.ZERO, Vector2(300.0, h)), "ticket")
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		assert_gt(tris.size(), 0, "alto %.1f: el polígono se puede triangular" % h)


func test_first_hint_only_at_the_start() -> void:
	assert_true(FirstHint.wanted(0.0))
	assert_false(FirstHint.wanted(50.0), "después de los primeros reventones ya no aparece")
	assert_true(Tx.T.has("hint_1") and Tx.T.has("hint_2"))


func test_shop_reveals_only_what_is_close() -> void:
	var s: GameState = GameState.new()
	assert_true(up.is_revealed(s, "global_hold"), "lo primero se ve desde el arranque")
	assert_false(up.is_revealed(s, "unlock_palm"), "la palma no se ofrece al arrancar")
	assert_false(up.is_revealed(s, "finger_size"), "lo caro todavía no aparece")
	s.levels["global_hold"] = 1
	s.pops_run = up.next_cost("unlock_palm", 0) * 0.31
	assert_true(up.is_revealed(s, "unlock_palm"), "aparece cuando se acerca")
	s.pops_run = 0.0
	s.levels["finger_size"] = 1
	assert_true(up.is_revealed(s, "finger_size"), "lo ya comprado siempre se ve")


func test_work_order_guides_the_start() -> void:
	var sim: GameSim = GameSim.new(db, 1)
	assert_eq(WorkOrder.current_goal(sim), "hold")
	sim.state.levels["global_hold"] = 1
	sim.refresh_stats()
	assert_eq(WorkOrder.current_goal(sim), "reload")
	sim.state.levels["global_reload"] = 1
	sim.refresh_stats()
	assert_eq(WorkOrder.current_goal(sim), "palm")
	sim.state.levels["unlock_palm"] = 1
	assert_eq(WorkOrder.current_goal(sim), "recycle", "después, el primer reciclado y para qué sirve")
	for goal: String in ["hold", "reload", "palm", "recycle", "pin", "iron", "hands", "boot", "pellet"]:
		assert_ne(Tx.t("why_" + goal), "why_" + goal, "cada meta explica para qué sirve: %s" % goal)


func test_bubble_cursor_is_a_round_bubble() -> void:
	var img: Image = BubbleCursor.image(BubbleCursor.SIZE)
	var mid: int = BubbleCursor.SIZE >> 1
	assert_eq(img.get_pixel(0, 0).a, 0.0, "las esquinas son transparentes")
	assert_gt(img.get_pixel(mid + 4, mid + 4).a, 0.5, "el centro se ve")
	assert_lt(img.get_pixel(mid, 1).v, 0.3, "contorno de tinta")
