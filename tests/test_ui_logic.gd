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


func test_flyers_cap_and_panels() -> void:
	var f: FlyingNumbers = FlyingNumbers.new()
	f.blocked = [Rect2(Vector2(0, 0), Vector2(200, 100))]
	for i: int in 30:
		f.spawn(Vector2(400 + i * 10, 400), 1.0)
	assert_eq(f.pending(), FlyingNumbers.MAX_ITEMS, "nunca más de 12 en pantalla")
	assert_false(Rect2(Vector2(0, 0), Vector2(200, 100)).has_point(f.outside_panels(Vector2(50, 50))), "no nace dentro de un panel")
	f.free()


func test_paper_polygon_never_self_intersects_on_tiny_sheets() -> void:
	for h: float in [0.5, 1.0, 2.0, 3.0, 6.0]:
		var poly: PackedVector2Array = UiKit.paper_polygon(Rect2(Vector2.ZERO, Vector2(300.0, h)), "ticket")
		var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
		assert_gt(tris.size(), 0, "alto %.1f: el polígono se puede triangular" % h)
