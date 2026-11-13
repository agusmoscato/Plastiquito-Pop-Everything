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
	assert_eq(up.effect_text("perm_sheet", 1, "es"), "Piso 40x40")


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
