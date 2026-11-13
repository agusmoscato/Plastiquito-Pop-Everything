extends GutTest

const TMP_DIR: String = "user://test_data_db"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)


func after_each() -> void:
	for f: String in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))


func _write(file: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(TMP_DIR.path_join(file), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _copy_real(file: String) -> void:
	_write(file, FileAccess.get_file_as_string("res://data".path_join(file)))


func _copy_others(except: Array[String]) -> void:
	for f: String in ["phases.json", "tools.json", "bubbles.json", "sheet.json", "juice.json", "audio.json"]:
		if not except.has(f):
			_copy_real(f)


func test_real_data_loads_without_errors() -> void:
	var db: DataDB = DataDB.new()
	var ok: bool = db.load_all()
	assert_true(ok, "errores: %s" % str(db.errors))
	assert_eq(db.phases.size(), 7)
	assert_eq(db.tools.size(), 8)
	assert_eq(db.bubbles.size(), 7)
	assert_eq(str(db.get_tool("steamroller")["shape"]), "segment")
	assert_eq(int(db.get_phase("orbit")["sheet_end"]["width"]), 1000)
	assert_true(db.get_tool("nope").is_empty())


func test_missing_field_gives_clear_error() -> void:
	_copy_others(["tools.json"])
	_write("tools.json", '{"version":1,"tools":[{"id":"finger","number":1,"name_es":"Dedo","shape":"cell","unlock_phase":1,"balance":{}}]}')
	var db: DataDB = DataDB.new()
	assert_false(db.load_all(TMP_DIR))
	assert_eq(db.errors.size(), 1)
	assert_string_contains(db.errors[0], "tools.json")
	assert_string_contains(db.errors[0], "finger")
	assert_string_contains(db.errors[0], "name_en")


func test_missing_file_and_bad_json() -> void:
	_copy_others(["tools.json", "bubbles.json"])
	_write("tools.json", "{ esto no es json")
	var db: DataDB = DataDB.new()
	assert_false(db.load_all(TMP_DIR))
	var joined: String = "\n".join(db.errors)
	assert_string_contains(joined, "tools.json: JSON inválido")
	assert_string_contains(joined, "bubbles.json: el archivo no existe")


func test_unknown_unlock_phase_and_shape() -> void:
	_copy_others(["tools.json"])
	_write("tools.json", '{"version":1,"tools":[{"id":"x","number":1,"name_es":"X","name_en":"X","shape":"blob","unlock_phase":99,"balance":{}}]}')
	var db: DataDB = DataDB.new()
	assert_false(db.load_all(TMP_DIR))
	var joined: String = "\n".join(db.errors)
	assert_string_contains(joined, "forma desconocida")
	assert_string_contains(joined, "unlock_phase 99")


func test_sheet_config_loaded_and_missing_field_detected() -> void:
	var db: DataDB = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	assert_eq(float(db.sheet["reload_threshold"]), 0.9)
	assert_eq(int(db.audio["voices"]), 24)
	assert_true(db.juice.has("hitstop_ms"))
	_copy_others(["sheet.json"])
	_write("sheet.json", '{"version":1,"sheet":{"default_width":20}}')
	var bad: DataDB = DataDB.new()
	assert_false(bad.load_all(TMP_DIR))
	assert_string_contains("
".join(bad.errors), "sheet.json[sheet]: falta el campo")
