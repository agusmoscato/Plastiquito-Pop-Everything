extends Node3D
## Escena principal del juguete: junta el mundo, el dedo, el overlay de debug y la entrada.
## Argumentos de usuario (después de "--"):  --demo-shot=<carpeta>  genera capturas de prueba y sale.

var world: ToyWorld
var tool_view: ToolView
var overlay: DebugOverlay

var _cursor: Vector2 = Vector2.ZERO
var _prev_cursor: Vector2 = Vector2.ZERO
var _cursor_valid: bool = false
var _hitstop_bucket: int = 0
var _demo: bool = false


func _ready() -> void:
	world = ToyWorld.new()
	world.name = "World"
	add_child(world)
	tool_view = ToolView.new()
	tool_view.name = "Finger"
	add_child(tool_view)
	tool_view.configure(world.db.juice)
	overlay = DebugOverlay.new()
	overlay.world = world
	overlay.size_selected.connect(_on_size_selected)
	overlay.mass_pop_requested.connect(_mass_pop)
	add_child(overlay)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-shot="):
			_run_demo(arg.trim_prefix("--demo-shot="))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo:
			if key.keycode == KEY_F3:
				overlay.toggle()
			elif key.keycode == KEY_F12:
				save_screenshot()


func _process(delta: float) -> void:
	_update_cursor()
	var holding: bool = _is_holding()
	var touched: PackedInt32Array = PackedInt32Array()
	if holding and _cursor_valid:
		touched = world.tool_model.cells_along(_prev_cursor, _cursor)
	var popped: PackedInt32Array = world.tool_model.step(touched, delta)
	_after_step(popped, holding, delta)
	_prev_cursor = _cursor


func save_screenshot() -> String:
	var dir: String = "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%s/plastiquito_%s_%d.png" % [dir, stamp, Time.get_ticks_msec() % 1000]
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(path)
	print("captura: ", ProjectSettings.globalize_path(path))
	return path


func _is_holding() -> bool:
	if get_viewport().gui_get_hovered_control() != null:
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _update_cursor() -> void:
	var screen: Vector2 = get_viewport().get_mouse_position()
	var p: Vector2 = world.camera_rig.screen_to_plane(screen)
	_cursor_valid = p.is_finite()
	if _cursor_valid:
		_cursor = p
	var over_sheet: bool = _cursor_valid and world.grid.world_to_cell(_cursor) >= 0
	var over_ui: bool = get_viewport().gui_get_hovered_control() != null
	if over_sheet and not over_ui:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tool_view.visible = _demo or (over_sheet and not over_ui)
	if _cursor_valid and not _demo:
		tool_view.set_cursor(_cursor)


## Reacciona a lo que pasó este frame: audio, partículas, rebote, hitstop y sacudida.
func _after_step(popped: PackedInt32Array, holding: bool, delta: float) -> void:
	tool_view.set_pressing(holding and _cursor_valid)
	PopAudio.report_frame(popped.size(), 1.0, delta)
	if world.tool_model.new_pressed > 0:
		PopAudio.play_squish()
	if popped.is_empty():
		return
	tool_view.bounce(minf(float(popped.size()), 4.0) * 0.5)
	Juice.pops_at(_positions(popped))
	Juice.add_pop_trauma(popped.size())
	_check_streak_hitstop()


func _check_streak_hitstop() -> void:
	var every: int = Cfg.integer(world.db.juice, "hitstop_every_streak")
	@warning_ignore("integer_division")
	var bucket: int = PopAudio.streak() / every
	if bucket > _hitstop_bucket:
		Juice.hitstop(Cfg.integer(world.db.juice, "hitstop_ms"))
	_hitstop_bucket = bucket


func _positions(cells: PackedInt32Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for idx: int in cells:
		var p: Vector2 = world.grid.cell_to_world(idx)
		out.append(Vector3(p.x, 0.25, p.y))
	return out


func _mass_pop() -> void:
	var center: Vector2 = world.sheet_view.center()
	if _cursor_valid:
		center = _cursor
	var cells: PackedInt32Array = world.grid.cells_in_circle(center, Cfg.num(world.db.juice, "mass_pop_radius"))
	var popped: PackedInt32Array = world.tool_model.pop_cells(cells)
	PopAudio.report_frame(popped.size(), 1.0, 0.016)
	Juice.pops_at(_positions(popped))
	Juice.add_pop_trauma(popped.size())
	Juice.hitstop(Cfg.integer(world.db.juice, "hitstop_ms"))


func _on_size_selected(w: int, h: int) -> void:
	world.set_sheet_size(w, h)
	tool_view.configure(world.db.juice)


# --- Modo demo para capturas automáticas -------------------------------------------------

func _run_demo(dir: String) -> void:
	_demo = true
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	_shot(dir, "01_intacta")
	var c: Vector2 = world.sheet_view.center()
	var around: PackedInt32Array = world.grid.cells_in_circle(c + Vector2(-3.0, 1.0), 2.6)
	world.tool_model.pop_cells(around)
	var pressing: PackedInt32Array = world.grid.cells_in_circle(c + Vector2(4.0, 0.0), 0.6)
	for k: int in 3:
		world.tool_model.step(pressing, 0.05)
	tool_view.set_cursor(c + Vector2(4.0, 0.0))
	tool_view.set_pressing(true)
	await get_tree().create_timer(0.6).timeout
	_shot(dir, "02_reventadas_y_apretando")
	world.camera_rig.set_zoom(7.0)
	world.camera_rig.position = Vector3(c.x - 3.0, 0.0, c.y + 1.0)
	await get_tree().create_timer(0.8).timeout
	_shot(dir, "03_cerca")
	quit_after_demo()


func _shot(dir: String, name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [dir, name])
	print("demo: ", name)


func quit_after_demo() -> void:
	get_tree().quit()
