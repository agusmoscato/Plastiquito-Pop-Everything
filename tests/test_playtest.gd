extends GutTest


func test_version_read_from_project_godot() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	var v: String = AppInfo.parse_version(text)
	assert_eq(v, "0.1.0")
	assert_eq(AppInfo.version(), v, "ProjectSettings y el archivo coinciden")


func test_parse_version_missing() -> void:
	assert_eq(AppInfo.parse_version("[application]\nconfig/name=\"x\"\n"), "")
	assert_eq(AppInfo.parse_version("config/version=\"2.3.4-beta\""), "2.3.4-beta")


func test_debug_overlay_not_allowed_in_playtest() -> void:
	assert_false(PlaytestMode.debug_allowed(PackedStringArray(["playtest"])))
	assert_false(PlaytestMode.debug_allowed(PackedStringArray(["release"])))
	assert_false(PlaytestMode.debug_allowed(PackedStringArray(["debug", "playtest"])))
	assert_true(PlaytestMode.debug_allowed(PackedStringArray(["debug", "editor"])))
	assert_true(PlaytestMode.debug_allowed(PackedStringArray()))
	assert_true(PlaytestMode.is_playtest(PackedStringArray(["playtest"])))


func test_clicks_vs_drags() -> void:
	var log: SessionLog = SessionLog.new()
	log.press_started()
	log.press_ended()
	log.press_started()
	log.press_ended()
	log.press_started()
	log.press_moved_to_new_cell(7.5)
	log.press_moved_to_new_cell(8.0)
	log.press_ended()
	assert_eq(log.clicks, 2)
	assert_eq(log.drags, 1, "un arrastre cuenta una vez aunque cruce muchas celdas")
	assert_eq(log.first_drag_s, 7.5)


func test_first_drag_is_kept() -> void:
	var log: SessionLog = SessionLog.new()
	for t: float in [3.0, 9.0]:
		log.press_started()
		log.press_moved_to_new_cell(t)
		log.press_ended()
	assert_eq(log.first_drag_s, 3.0)
	assert_eq(log.drags, 2)


func test_move_without_press_is_ignored() -> void:
	var log: SessionLog = SessionLog.new()
	log.press_moved_to_new_cell(1.0)
	log.press_ended()
	assert_eq(log.drags + log.clicks, 0)
	assert_eq(log.first_drag_s, -1.0)


func test_max_streak_and_totals() -> void:
	var log: SessionLog = SessionLog.new()
	log.pops(3, 3)
	log.pops(5, 8)
	log.pops(1, 1)
	assert_eq(log.total_pops, 9)
	assert_eq(log.max_streak, 8)


func test_csv_format() -> void:
	var log: SessionLog = SessionLog.new()
	log.version = "0.1.0"
	log.started_at = "2026-11-13T10:00:00"
	log.press_started()
	log.press_ended()
	log.pops(4, 4)
	log.volume_changed(0.5, 12.34)
	log.volume_changed(0.9, 30.0)
	log.zoomed()
	log.sheet_reloaded()
	var lines: PackedStringArray = log.to_csv(125.0).strip_edges().split("\n")
	assert_eq(lines[0], "campo,valor")
	assert_eq(lines.size(), 16)
	assert_true(lines.has("version,0.1.0"))
	assert_true(lines.has("duracion_s,125.0"))
	assert_true(lines.has("reventones_totales,4"))
	assert_true(lines.has("segundo_primer_arrastre,"))
	assert_true(lines.has("clics_sueltos,1"))
	assert_true(lines.has("arrastres,0"))
	assert_true(lines.has("cambios_volumen,0.50@12.3;0.90@30.0"))
	assert_true(lines.has("usos_rueda_zoom,1"))
	assert_true(lines.has("recargas_lamina,1"))
	assert_true(lines.has("racha_maxima,4"))
	for line: String in lines:
		assert_eq(line.count(","), 1, line)


func test_csv_counts_press_in_progress() -> void:
	var log: SessionLog = SessionLog.new()
	log.press_started()
	log.press_moved_to_new_cell(2.0)
	assert_true(log.to_csv(3.0).contains("arrastres,1"))
