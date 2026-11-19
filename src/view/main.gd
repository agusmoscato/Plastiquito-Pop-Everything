class_name PlastiquitoMain
extends Node3D
## Escena principal: junta el mundo 3D, GameSim (las reglas), el HUD y la entrada.
## Argumentos de usuario (después de "--"):  --demo-shot=<carpeta>  genera capturas de prueba y sale;
## --smoke=<carpeta> [--minutes=N] [--shot-every=S]  prueba de humo con un bot que juega (solo CI).

const RECYCLE_CRUMPLE_S: float = 0.9
const RECYCLE_ROLL_S: float = 1.2
const RECYCLE_EXIT_S: float = 0.6

var db: DataDB
var sim: GameSim
var world: ToyWorld
var tool_view: ToolView
var hud: Hud
var overlay: DebugOverlay
var pause_menu: PauseMenu
var title: TitleScreen
var automation: AutomationView
var echo_glow: EchoGlow
var _offline: Dictionary = {}
var _version_layer: CanvasLayer

var _cursor: Vector2 = Vector2.ZERO
var _prev_cursor: Vector2 = Vector2.ZERO
var _cursor_valid: bool = false
var _hitstop_bucket: int = 0
var _demo: bool = false
var _shots_taken: int = 0
var _debug: bool = false
var _was_holding: bool = false
var _press_cell: int = -1
var _fake_press: bool = false
var _night: float = 0.0 ## turno noche suavizado (0 día .. 1 noche)
var _burn_cooldown: float = 0.0 ## humo y chirrido de la plancha, como mucho cada 0,35 s

var _recycling: bool = false
var _recycle_t: float = 0.0
var _recycle_roll: MeshInstance3D
var _recycle_swapped: bool = false


func _ready() -> void:
	db = DataDB.new()
	if not db.load_all():
		push_error("main: data inválida: %s" % "; ".join(db.errors))
		return
	sim = GameSim.new(db, int(Time.get_ticks_usec() % 100000))
	if DisplayServer.get_name() != "headless":
		BubbleCursor.apply()
	if _has_demo_arg(): # las capturas y el bot de humo juegan con "Mantener apretado" ya comprado
		sim.state.levels["global_hold"] = 1
		sim.refresh_stats()
	if not _has_demo_arg():
		SaveSystem.sim = sim # las capturas de prueba no tocan el guardado
		SaveSystem.interval = Cfg.num(db.economy, "autosave_seconds")
		if SaveSystem.load_into(sim):
			_offline = sim.compute_offline(Time.get_unix_time_from_system())
	world = ToyWorld.new()
	world.name = "World"
	world.deferred_sheet = true
	add_child(world)
	world.attach(sim)
	tool_view = ToolView.new()
	tool_view.name = "Tool"
	add_child(tool_view)
	tool_view.configure(db.juice)
	tool_view.rig = world.camera_rig # la herramienta ocupa una fracción fija de la pantalla
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(sim, world.camera_rig.camera)
	hud.tool_selected.connect(_select_tool)
	hud.purchased.connect(_on_purchased)
	hud.recycle_confirmed.connect(_start_recycle)
	hud.chain_slammed.connect(_on_chain_slammed)
	hud.reload_requested.connect(request_reload)
	world.camera_rig.zoomed.connect(Playtest.log.zoomed)
	automation = AutomationView.new()
	automation.name = "Automation"
	add_child(automation)
	automation.bind(sim)
	automation.rig = world.camera_rig
	var fractions: Dictionary = db.juice["tool_screen_fraction"]
	automation.screen_fraction = Cfg.num(fractions, "hands")
	echo_glow = EchoGlow.new()
	echo_glow.name = "EchoGlow"
	add_child(echo_glow)
	echo_glow.bind(sim)
	hud.offline_ticket.collected.connect(_collect_offline)
	if not _offline.is_empty() and Cfg.num(_offline, "pops") > 0.0:
		hud.show_offline(_offline)
	_debug = PlaytestMode.debug_allowed(PlaytestMode.current_tags())
	if _debug: # en playtest/release no existen F3 ni las trampas de desarrollo
		overlay = DebugOverlay.new()
		overlay.world = world
		overlay.mass_pop_requested.connect(_mass_pop)
		overlay.cheat_pops_requested.connect(func() -> void: sim.state.pops += 1.0e6; sim.state.pops_run += 1.0e6)
		add_child(overlay)
	_add_vignette()
	_apply_graphics()
	Settings.graphics_changed.connect(_apply_graphics)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	if not _has_demo_arg(): # al abrir el juego, primero el menú de inicio (las capturas lo saltean)
		title = TitleScreen.new()
		title.has_save = SaveSystem.has_save()
		title.options_menu = pause_menu
		title.hide_while_open = [hud]
		add_child(title)
	_add_version_label()
	_refresh_tool_view()
	_announce_new_specials()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-shot="):
			_run_demo(arg.trim_prefix("--demo-shot="))
		elif arg.begins_with("--demo3="):
			_run_demo3(arg.trim_prefix("--demo3="))
		elif arg.begins_with("--demo-tools="):
			_run_demo_tools(arg.trim_prefix("--demo-tools="))
		elif arg.begins_with("--smoke="):
			_start_smoke(arg.trim_prefix("--smoke="))


func _has_demo_arg() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-shot=") or arg.begins_with("--demo3=") or arg.begins_with("--demo-tools=") or arg.begins_with("--smoke="):
			return true
	return false


func is_recycling() -> bool:
	return _recycling


func _start_smoke(dir: String) -> void:
	var mins: float = 3.0
	var every: float = 15.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			mins = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--shot-every="):
			every = float(arg.trim_prefix("--shot-every="))
	var bot: SmokeBot = SmokeBot.new()
	bot.name = "SmokeBot"
	bot.setup(self, dir, mins, every)
	add_child(bot)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo:
			_on_key(key.keycode)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _over_roll(world.camera_rig.screen_to_plane(mb.position)):
			request_reload()


## true si hay que tirar una lámina nueva y `p` (plano XZ) cae sobre el rollo gigante.
func _over_roll(p: Vector2) -> bool:
	return sim.awaiting_reload and p.is_finite() and ScenarioProps.roll_rect.has_point(p)


## F9: oculta o muestra TODA la interfaz (HUD, versión y overlay), para grabar clips.
func _toggle_ui() -> void:
	var show: bool = not hud.visible
	hud.visible = show
	if _version_layer != null:
		_version_layer.visible = show
	if overlay != null and not show:
		overlay.visible = false


func _on_key(code: int) -> void:
	if code == KEY_F3 and overlay != null:
		overlay.toggle()
	elif code == KEY_F9:
		_toggle_ui()
	elif code == KEY_F12:
		save_screenshot()
	elif code == KEY_1:
		_select_tool("finger")
	elif code == KEY_2:
		_select_tool("palm")
	elif code == KEY_3:
		_select_tool("rolling_pin")
	elif code == KEY_4:
		_select_tool("iron")
	elif code == KEY_5:
		_select_tool("boot")
	elif code == KEY_TAB:
		if hud.is_modal_open():
			hud.close_recycle_panel()
		else:
			hud.open_recycle_panel()
	elif code == KEY_B:
		hud.bubble_log.visible = not hud.bubble_log.visible
	elif code == KEY_R or code == KEY_SPACE:
		request_reload()


func _apply_graphics() -> void:
	if not _has_demo_arg(): # las capturas de CI siempre en calidad alta
		GraphicsQuality.apply(world, Settings.graphics)


## Tira una lámina nueva del rollo (botón, tecla R / espacio o clic en el rollo gigante).
func request_reload() -> void:
	if _recycling or not sim.request_reload():
		return
	PopAudio.play_crinkle()
	world.scenario.tug_roll()


func _process(delta: float) -> void:
	if sim == null:
		return
	if _recycling:
		_update_recycle(delta)
		hud.on_sim_step(delta)
		return
	_update_cursor()
	world.camera_rig.follow(_cursor, _cursor_valid and tool_view.visible, delta)
	var holding: bool = _is_holding()
	_track_press(holding)
	var dir: Vector2 = _cursor - _prev_cursor
	var pointer: Vector2 = _cursor if _cursor_valid else _prev_cursor
	sim.step(delta, pointer, holding and _cursor_valid)
	_prev_cursor = _cursor
	if dir.length_squared() > 0.0001:
		tool_view.set_drag_direction(dir)
	_after_step(holding, delta)


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


# --- Entrada ------------------------------------------------------------------------------------------

func _is_holding() -> bool:
	if _demo:
		return _fake_press
	if hud.is_modal_open() or pause_menu.is_open():
		return false
	if get_viewport().gui_get_hovered_control() != null:
		return false
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _update_cursor() -> void:
	if _demo:
		tool_view.visible = true
		return
	var screen: Vector2 = get_viewport().get_mouse_position()
	var p: Vector2 = world.camera_rig.screen_to_plane(screen)
	_cursor_valid = p.is_finite()
	if _cursor_valid:
		_cursor = p
	var over_sheet: bool = _cursor_valid and world.grid.world_to_cell(_cursor) >= 0
	var over_ui: bool = get_viewport().gui_get_hovered_control() != null or hud.is_modal_open()
	if _over_roll(_cursor): # lámina terminada: sobre el rollo se ve el puntero para tirar de él
		over_ui = true
	if over_sheet and not over_ui:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tool_view.visible = over_sheet and not over_ui
	if _cursor_valid:
		tool_view.set_cursor(_cursor)
	var reach: float = maxf(tool_view.radius, world.grid.spacing * 0.55) # el dedo alcanza una burbuja
	world.sheet_view.set_hover(_cursor, reach if tool_view.visible else 0.0)


func _track_press(holding: bool) -> void:
	var log: SessionLog = Playtest.log
	var cell: int = world.grid.world_to_cell(_cursor) if _cursor_valid else -1
	if holding and not _was_holding:
		log.press_started()
		_press_cell = cell
	elif holding and cell != _press_cell and cell >= 0:
		log.press_moved_to_new_cell(Playtest.now_s())
	elif not holding and _was_holding:
		log.press_ended()
	_was_holding = holding
	tool_view.set_pressing(holding)


func _select_tool(id: String) -> void:
	if _recycling:
		return
	if sim.select_tool(id):
		_refresh_tool_view()
		world.tool_model = sim.selected_tool()
		hud.shop.select_tab(id) # la hoja de pedidos muestra las mejoras de la herramienta en la mano


## La herramienta del mundo refleja las mejoras: tamaño, velocidad y color por hito.
func _refresh_tool_view() -> void:
	var tm: ToolModel = sim.selected_tool()
	var id: String = sim.state.selected_tool
	var tier: int = 0
	var every: int = Cfg.integer(sim.eco, "milestone_every")
	for up_id: String in sim.upgrades.ids_for_tool(id):
		@warning_ignore("integer_division")
		tier = maxi(tier, sim.state.level(up_id) / every)
	tool_view.set_tool(id, tm.radius, mini(tier, 3), tm.drag_entry_fraction, tm.force_per_second / 6.0)


func _collect_offline() -> void:
	sim.apply_offline(_offline, Time.get_unix_time_from_system())
	_offline = {}
	PopAudio.play_ui("stamp")


func _on_purchased(id: String, count: int, _milestone: bool) -> void:
	Playtest.log.purchase(count)
	_refresh_tool_view()
	world.tool_model = sim.selected_tool()
	var d: Dictionary = sim.upgrades.def(id)
	if str(d["kind"]) == "unlock" and str(d["tool"]) != "":
		_select_tool(str(d["tool"]))


# --- Después de cada paso de la sim ----------------------------------------------------------------------

func _after_step(_holding: bool, delta: float) -> void:
	if sim.ev_reloaded:
		_celebrate_sheet()
		world.rebind_game_sheet(true)
		PopAudio.play_crinkle()
		Playtest.log.sheet_reloaded()
		_announce_new_specials()
	var n: int = sim.ev_idx.size()
	var max_p: float = 1.0
	for p: float in sim.ev_pressure:
		max_p = maxf(max_p, p)
	PopAudio.report_frame(n, max_p, delta)
	_update_night(delta)
	world.scenario.roll_glow = sim.awaiting_reload
	if sim.ev_squish:
		PopAudio.play_squish()
	_burn_cooldown = maxf(0.0, _burn_cooldown - delta)
	if not sim.ev_burned.is_empty() and _burn_cooldown <= 0.0: # la plancha quieta derrite el plástico
		_burn_cooldown = 0.35
		var bp: Vector2 = sim.grid.cell_to_world(sim.ev_burned[sim.ev_burned.size() >> 1])
		if Juice.fx != null:
			Juice.fx.smoke_at(Vector3(bp.x, 0.3, bp.y))
		PopAudio.play_ui("screech", randf_range(0.94, 1.06), -6.0)
	if not sim.ev_cracked.is_empty(): # doble film: cruje la capa de afuera y la burbuja queda entera
		PopAudio.play_ui("tic", randf_range(1.5, 1.7), -3.0)
		var cp: Vector2 = sim.grid.cell_to_world(sim.ev_cracked[0])
		if Juice.fx != null:
			Juice.fx.smoke_at(Vector3(cp.x, 0.35, cp.y))
	if not sim.ev_revived.is_empty(): # un Eco se vuelve a inflar: entra aire
		PopAudio.play_ui("air", randf_range(0.95, 1.08), -4.0)
	hud.on_sim_step(delta)
	if n == 0:
		return
	Playtest.log.pops(n, PopAudio.streak())
	Playtest.log.tool_pops(sim.state.selected_tool, sim.ev_tool_pops)
	if sim.ev_tool_pops > 0:
		tool_view.bounce(minf(float(sim.ev_tool_pops), 4.0) * 0.5)
	if sim.state.selected_tool == "boot" and sim.ev_tool_pops > 0 and Juice.fx != null:
		Juice.fx.stomp_at(Vector3(_cursor.x, 0.2, _cursor.y), sim.selected_tool().radius)
	_pop_fx()
	Juice.add_pop_trauma(n * 3 if sim.state.selected_tool == "boot" and sim.ev_tool_pops > 0 else n)
	_check_hitstop()
	if sim.ev_chain_ended_count >= Cfg.integer(sim.eco, "chain_stamp_min"):
		Playtest.log.chain(sim.ev_chain_ended_count)


## TURNO NOCHE: entra en ~2 s y vuelve al día en ~0,7 s cuando se toca de nuevo.
## Lámina terminada: sello, sonido de hito y destellos dorados sobre la lámina (el cierre de cada ciclo).
func _celebrate_sheet() -> void:
	hud.chain_stamp.announce(Tx.t("sheet_done"))
	PopAudio.play_ui("milestone", 1.0, -3.0)
	Juice.add_pop_trauma(12)
	var c: Vector2 = sim.center()
	var e: Vector2 = world.sheet_view.extents() * 0.35
	for k: int in 5:
		var a: float = TAU * float(k) / 5.0
		Juice.special_at(Vector3(c.x + cos(a) * e.x, 0.5, c.y + sin(a) * e.y), 1)


func _update_night(delta: float) -> void:
	var on: bool = sim.night_shift()
	_night = move_toward(_night, 1.0 if on else 0.0, delta * (0.5 if on else 1.4))
	world.scenario.set_night(_night * _night * (3.0 - 2.0 * _night))
	automation.night = _night


func _pop_fx() -> void:
	var positions: PackedVector3Array = PackedVector3Array()
	for i: int in sim.ev_idx.size():
		var p: Vector2 = sim.grid.cell_to_world(sim.ev_idx[i])
		var t: int = sim.ev_type[i]
		if t != 0:
			Juice.special_at(Vector3(p.x, 0.4, p.y), t)
			PopAudio.play_special(t)
		elif positions.size() < 40:
			positions.append(Vector3(p.x, 0.25, p.y))
	Juice.pops_at(positions)


func _check_hitstop() -> void:
	var every: int = Cfg.integer(db.juice, "hitstop_every_streak")
	@warning_ignore("integer_division")
	var bucket: int = PopAudio.streak() / every
	if bucket > _hitstop_bucket:
		Juice.hitstop(Cfg.integer(db.juice, "hitstop_ms"))
	_hitstop_bucket = bucket


func _on_chain_slammed(count: int) -> void:
	Juice.add_pop_trauma(count)
	@warning_ignore("integer_division")
	Juice.hitstop(clampi(30 + count / 2, 30, 60))


func _announce_new_specials() -> void:
	for t: int in sim.ev_new_specials:
		world.specials_view.mark_new(t, Tx.t("new"))
	sim.ev_new_specials = []


func _mass_pop() -> void:
	var center: Vector2 = world.sheet_view.center()
	if _cursor_valid:
		center = _cursor
	var cells: PackedInt32Array = world.grid.cells_in_circle(center, Cfg.num(db.juice, "mass_pop_radius"))
	sim.chain.clear_events()
	for idx: int in cells:
		sim.chain.pop_now(idx)
	sim._collect_events(false)
	_pop_fx()
	PopAudio.report_frame(sim.ev_idx.size(), 1.0, 0.016)
	Juice.add_pop_trauma(sim.ev_idx.size())
	Juice.hitstop(Cfg.integer(db.juice, "hitstop_ms"))


# --- Reciclado: la lámina se arruga, se enrolla y se va al reciclaje ---------------------------------------

func _start_recycle() -> void:
	if _recycling or not sim.can_recycle():
		return
	hud.close_recycle_panel()
	_recycling = true
	_recycle_t = 0.0
	_recycle_swapped = false
	tool_view.visible = false
	world.specials_view.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	PopAudio.play_ui("recycle")
	_recycle_roll = _make_roll()
	add_child(_recycle_roll)


func _make_roll() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = world.sheet_view.extents().x
	cyl.radial_segments = 28
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.rim_enabled = true
	m.rim = 0.7
	cyl.material = m
	mi.mesh = cyl
	mi.visible = false
	return mi


func _update_recycle(delta: float) -> void:
	_recycle_t += delta
	var sv: SheetView = world.sheet_view
	var ext: Vector2 = sv.extents()
	var c: Vector2 = sv.center()
	var t1: float = RECYCLE_CRUMPLE_S
	var t2: float = t1 + RECYCLE_ROLL_S
	var t3: float = t2 + RECYCLE_EXIT_S
	if _recycle_t < t1:
		sv.set_recycle_progress(_recycle_t / t1, -1.0e9)
	elif _recycle_t < t2:
		var k: float = (_recycle_t - t1) / RECYCLE_ROLL_S
		var roll_z: float = lerpf(-1.5, ext.y + 2.0, k)
		sv.set_recycle_progress(1.0, roll_z)
		_place_roll(c.x, roll_z, 0.3 + 0.9 * k, 0.0)
	elif _recycle_t < t3:
		var k2: float = (_recycle_t - t2) / RECYCLE_EXIT_S
		sv.set_recycle_progress(1.0, ext.y + 4.0)
		_place_roll(c.x + k2 * k2 * (ext.x + 12.0), ext.y + 2.0, 1.2 * (1.0 - k2 * 0.6), k2)
	elif not _recycle_swapped:
		_recycle_swapped = true
		_finish_recycle()
	if _recycle_swapped and _recycle_t > t3 + 0.3:
		_recycling = false


func _place_roll(x: float, z: float, radius: float, drop: float) -> void:
	_recycle_roll.visible = true
	var cyl: CylinderMesh = _recycle_roll.mesh as CylinderMesh
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	_recycle_roll.position = Vector3(x, radius - drop * 1.5, z)
	_recycle_roll.rotation = Vector3(0.0, 0.0, PI * 0.5)


func _finish_recycle() -> void:
	if is_instance_valid(_recycle_roll):
		_recycle_roll.queue_free()
	var gained: int = sim.recycle()
	world.sheet_view.clear_recycle_effect()
	world.rebind_game_sheet(true, 3.5, 3.5) # cámara y escenario cambian juntos durante 3,5 s
	world.tool_model = sim.selected_tool()
	_refresh_tool_view()
	_announce_new_specials()
	hud.pops_panel.odometer.set_target(0.0)
	Playtest.log.recycled(sim.state.first_recycle_s / 60.0)
	print("reciclado: +%d pellets" % gained)
	SaveSystem.save_now()


## Viñeta sutil sobre el mundo y debajo del HUD.
func _add_vignette() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 0
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/vignette.gdshader") as Shader
	rect.material = m
	layer.add_child(rect)
	add_child(layer)


func _add_version_label() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	var label: Label = Label.new()
	label.text = "v%s %s" % [AppInfo.version(), "playtest" if Playtest.enabled else "dev"]
	label.modulate = Color(1.0, 1.0, 1.0, 0.4)
	label.add_theme_font_size_override("font_size", 13)
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.position = Vector2(-470.0, -8.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	add_child(layer)
	_version_layer = layer


# --- Modo demo para capturas automáticas ---------------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(dir: String, shot_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [dir, shot_name])
	print("demo: ", shot_name)
	_shots_taken += 1
	if _shots_taken >= _shot_limit():
		PopAudio.quit_clean()


## Tope de capturas por tanda (--shot-limit=N); sin el argumento no hay tope.
func _shot_limit() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-limit="):
			return maxi(1, int(arg.trim_prefix("--shot-limit=")))
	return 1 << 30


## Simula una pasada del cursor `seconds` segundos sobre la lámina.
func _demo_swipe(from: Vector2, to: Vector2, seconds: float) -> void:
	var steps: int = int(seconds * 60.0)
	_fake_press = true
	for i: int in steps:
		_cursor = from.lerp(to, float(i) / float(steps))
		_cursor_valid = true
		tool_view.set_cursor(_cursor)
		await get_tree().process_frame
	_fake_press = false


func _run_demo(dir: String) -> void:
	_demo = true
	DirAccess.make_dir_recursive_absolute(dir)
	var menu: TitleScreen = TitleScreen.new() # el menú de inicio, para revisarlo en las capturas
	menu.options_menu = pause_menu
	add_child(menu)
	await _wait(1.0)
	menu.pop_bubble(2)
	menu.pop_bubble(5)
	await _wait(0.08)
	_shot(dir, "00_menu")
	menu._start()
	menu.queue_free()
	await _wait(1.2)
	_shot(dir, "01_inicio")
	sim.state.pops = 4000.0
	var c: Vector2 = sim.center()
	await _demo_swipe(c + Vector2(-2.0, -1.0), c + Vector2(2.0, 1.0), 0.7)
	sim.buy("finger_force", 2)
	sim.buy("global_value", 1)
	await _wait(0.8)
	_shot(dir, "02_hud_tienda")
	sim.state.pops = 60000.0
	sim.buy("unlock_palm", 1)
	_select_tool("palm")
	for i: int in 8:
		@warning_ignore("integer_division")
		sim.sheet.pressure[sim.grid.index(2 + i % 4, 2 + i / 4)] = 1.75
	await _demo_swipe(c, c + Vector2(0.5, 0.0), 0.9)
	await _wait(0.4)
	_shot(dir, "03_palma")
	_demo_chain()
	await _wait(0.45)
	_shot(dir, "04_cadena")
	await _wait(2.2)
	_shot(dir, "05_cadena_fin")
	for i: int in sim.sheet.cell_count(): # lámina terminada sin recarga automática: hay que tirar del rollo
		if sim.sheet.popped_ratio() >= 0.93:
			break
		sim.sheet.pop(i)
	await _wait(0.9)
	_shot(dir, "05b_tirar_lamina")
	request_reload()
	await _wait(1.4)
	sim.state.pops_run = 2.5 * Cfg.num(db.economy, "pellet_divisor") * 1.6
	sim.state.pops = 12345.0
	hud.open_recycle_panel()
	await _wait(0.8)
	_shot(dir, "06_reciclado_panel")
	hud.close_recycle_panel()
	_start_recycle()
	await _wait(1.5)
	_shot(dir, "07_reciclado_arruga")
	await _wait(1.0)
	_shot(dir, "08_reciclado_rollo")
	await _wait(3.2)
	_shot(dir, "09_reciclado_nueva")
	pause_menu.toggle()
	await _wait(0.4)
	_shot(dir, "10_pausa")
	get_tree().paused = false
	PopAudio.quit_clean()


func _demo_chain() -> void:
	@warning_ignore("integer_division")
	var mid: int = sim.grid.index(sim.sheet.width / 2, sim.sheet.height / 2)
	for i: int in sim.sheet.cell_count():
		if sim.sheet.state[(mid + i) % sim.sheet.cell_count()] != SheetModel.STATE_POPPED:
			mid = (mid + i) % sim.sheet.cell_count()
			break
	sim.sheet.type[mid] = GameSim.TYPE_BOMB
	sim.chain.clear_events()
	sim.chain.pop_now(mid)
	sim._collect_events(false)
	sim._track_chain()
	_pop_fx()
	hud.on_sim_step(0.016)


## Capturas de la Fase 3: escenarios, plancha, manitos, bota, rodillo, tablero de corcho y bienvenida.
func _demo3_phase(phase: int, pops: float) -> void:
	sim.state.perm["perm_sheet"] = phase - 1
	sim.state.pops = pops
	sim.state.pellets = 40.0
	for id: String in ["unlock_palm", "unlock_pin", "unlock_iron", "unlock_hands", "unlock_boot", "unlock_roller"]:
		sim.state.levels[id] = 1
	sim.state.levels["hands_count"] = 6
	sim.state.levels["finger_force"] = 4
	sim.state.levels["iron_size"] = 2
	sim.state.levels["boot_force"] = 30
	sim.refresh_stats()
	sim.new_sheet()
	world.rebind_game_sheet(false, 0.0, 0.0)
	automation.bind(sim)
	_refresh_tool_view()


func _run_demo3(dir: String) -> void:
	_demo = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(1.0)
	_demo3_phase(3, 5.0e7)
	sim.select_tool("iron")
	_refresh_tool_view()
	hud.shop.select_tab("iron")
	var c: Vector2 = sim.center()
	tool_view.snap_to(c)
	for i: int in 60:
		_cursor = c + Vector2(float(i) * 0.05 - 1.5, 0.0)
		_cursor_valid = true
		tool_view.set_cursor(_cursor)
		tool_view.set_drag_direction(Vector2(1.0, 0.0))
		sim.step(0.016, _cursor, false)
		await get_tree().process_frame
	await _wait(1.0)
	_shot(dir, "30_galpon_plancha_manitos")
	hud.shop.select_tab("finger")
	await _wait(0.3)
	_shot(dir, "31_tienda_iconos")
	_demo3_phase(4, 5.0e8)
	sim.select_tool("boot")
	_refresh_tool_view()
	hud.shop.select_tab("boot")
	await _wait(1.0)
	sim.step(0.016, sim.center(), true)
	sim.step(0.016, sim.center(), true)
	await _wait(0.5)
	_shot(dir, "32_estacionamiento_bota")
	hud.shop.select_tab("auto_roller")
	await _wait(0.4)
	_shot(dir, "33_estacionamiento_rodillo")
	sim.state.pops_run = 300.0 * Cfg.num(db.economy, "pellet_divisor") * 100.0
	hud.open_recycle_panel()
	await _wait(0.8)
	_shot(dir, "34_tablero_corcho")
	hud.close_recycle_panel()
	hud.show_offline({"efficiency": 0.5, "seconds": 7200.0, "hands_pops": 21000.0, "roller_pops": 27213.0, "pops": 4.8e9})
	await _wait(2.6)
	_shot(dir, "35_bienvenida")
	hud.offline_ticket.visible = false
	for ph: int in [1, 2, 3, 4]:
		_demo3_phase(ph, 1.0e6)
		sim.select_tool("finger" if ph < 3 else "iron")
		_refresh_tool_view()
		await _wait(1.2)
		_shot(dir, "36_escenario_%d" % ph)
	PopAudio.quit_clean()


## Capturas de las herramientas 3D: cada una sobre la lámina, suelta y apretando.
## Primer plano de la mano apretando (revisión de materiales y contorno): la cámara se acerca y la
## mano conserva su tamaño de mundo (sin la regla de fracción de pantalla mientras dura la foto).
func _closeup_shot(dir: String) -> void:
	var keep_rig: CameraRig = tool_view.rig
	tool_view.rig = null
	automation.visible = false
	hud.visible = false
	world.camera_rig.focus(_cursor + Vector2(1.0, 0.2), 6.0)
	await _wait(0.4)
	_shot(dir, "tool_finger_primer_plano")
	tool_view.rig = keep_rig
	automation.visible = true
	hud.visible = true
	world.camera_rig.fit_to(world.sheet_view.center(), world.sheet_view.extents())


func _run_demo_tools(dir: String) -> void:
	_demo = true
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(1.0)
	var plan: Dictionary[String, int] = {"finger": 1, "palm": 1, "rolling_pin": 2, "iron": 3, "boot": 4}
	for id: String in plan:
		_demo3_phase(plan[id], 5.0e8)
		sim.select_tool(id)
		_refresh_tool_view()
		var c: Vector2 = sim.center()
		tool_view.snap_to(c)
		for i: int in 40:
			_cursor = c + Vector2(float(i) * 0.04 - 0.8, 0.0)
			_cursor_valid = true
			tool_view.set_cursor(_cursor)
			tool_view.set_drag_direction(Vector2(1.0, 0.0))
			tool_view.set_pressing(false)
			await get_tree().process_frame
		await _wait(0.5)
		_shot(dir, "tool_%s_suelto" % id)
		tool_view.set_pressing(true)
		await _wait(0.35)
		_shot(dir, "tool_%s_apretando" % id)
		if id == "finger":
			await _closeup_shot(dir)
		tool_view.set_pressing(false)
	PopAudio.quit_clean()
