class_name SmokeBot
extends Node
## Prueba de humo: juega el juego real con eventos de entrada verdaderos (mouse y teclado).
## Aprieta, arrastra, compra haciendo clic en la hoja de pedidos, cambia de herramienta, recicla
## y salta de fase con el modo DEV. Saca una captura cada `shot_every` segundos y al final imprime
## "SMOKE OK" con un resumen. Se activa con  -- --smoke=<carpeta> [--minutes=N] [--shot-every=S].
## Corre en CI (GitHub Actions con xvfb); nunca en la PC del dueño.

const TOOL_KEYS: Dictionary[String, int] = {"finger": KEY_1, "palm": KEY_2, "rolling_pin": KEY_3, "iron": KEY_4, "boot": KEY_5}

var main: PlastiquitoMain
var dir: String = ""
var minutes: float = 3.0
var shot_every: float = 15.0

var _t: float = 0.0
var _shot_t: float = 0.0
var _shots: int = 0
var _down: bool = false
var _mouse: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _counts: Dictionary[String, int] = {"taps": 0, "drags": 0, "buys": 0, "tool_switches": 0, "recycles": 0, "phase_jumps": 0}
var _finished: bool = false


func setup(p_main: PlastiquitoMain, p_dir: String, p_minutes: float, p_shot_every: float) -> void:
	main = p_main
	dir = p_dir
	minutes = p_minutes
	shot_every = p_shot_every
	_rng.seed = 7
	DirAccess.make_dir_recursive_absolute(dir)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_run()


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_shot_t += delta
	if _shot_t >= shot_every:
		_shot_t = 0.0
		_shoot("t%03d_fase%d" % [int(_t), main.sim.phase()])


## Bucle principal del bot: elige una acción, la hace y sigue hasta cumplir los minutos.
func _run() -> void:
	await _frames(30)
	_shoot("t000_inicio")
	var jump_every: float = minutes * 60.0 / 4.0
	var next_jump: float = jump_every
	while _t < minutes * 60.0:
		if main.is_recycling():
			await _frames(5)
			continue
		if main.sim.awaiting_reload: # lámina terminada: tira una nueva del rollo (tecla R)
			await _frames(20)
			_key(KEY_R)
			await _frames(5)
			continue
		if _t >= next_jump and main.sim.phase() < 4:
			next_jump += jump_every
			await _dev_phase_jump()
			continue
		await _random_action()
	_finish()


func _random_action() -> void:
	var r: float = _rng.randf()
	if r < 0.30:
		await _tap_burst()
	elif r < 0.55:
		await _drag()
	elif r < 0.80:
		await _buy_something()
	elif r < 0.92:
		await _switch_tool()
	else:
		await _maybe_recycle()


# --- Acciones --------------------------------------------------------------------------------

func _tap_burst() -> void:
	for i: int in _rng.randi_range(3, 8):
		var p: Vector2 = _random_sheet_point()
		_mouse_to_world(p)
		await _frames(2)
		_button(true)
		await _frames(_rng.randi_range(2, 12))
		_button(false)
		await _frames(2)
		_counts["taps"] += 1


func _drag() -> void:
	var a: Vector2 = _random_sheet_point()
	var b: Vector2 = _random_sheet_point()
	_mouse_to_world(a)
	await _frames(2)
	_button(true)
	var steps: int = _rng.randi_range(20, 60)
	for i: int in steps:
		_mouse_to_world(a.lerp(b, float(i + 1) / float(steps)))
		await _frames(1)
	_button(false)
	_counts["drags"] += 1


## Compra la mejora pagable más barata haciendo clic en su pestaña y en su etiqueta.
func _buy_something() -> void:
	var best: String = ""
	var best_cost: float = INF
	for id: String in main.hud.shop.tag_ids():
		if not main.sim.can_afford_next(id):
			continue
		var cost: float = main.sim.upgrades.next_cost(id, main.sim.state.level(id))
		if cost < best_cost:
			best_cost = cost
			best = id
	if best == "":
		return
	var shop: ShopSheet = main.hud.shop
	var tab: StampButton = shop._tabs.get(shop.tab_of(best))
	if tab != null and tab.is_visible_in_tree():
		await _click_control(tab)
	var tag: UpgradeTag = shop.tag_for(best)
	shop._scroll.ensure_control_visible(tag)
	await _frames(3)
	var before: int = main.sim.state.level(best)
	if tag.is_visible_in_tree():
		await _click_control(tag)
	if main.sim.state.level(best) > before:
		_counts["buys"] += 1


func _switch_tool() -> void:
	var ids: Array = TOOL_KEYS.keys()
	var id: String = ids[_rng.randi_range(0, ids.size() - 1)]
	if not main.sim.upgrades.tool_unlocked(main.sim.state, id):
		return
	_key(TOOL_KEYS[id])
	await _frames(4)
	_counts["tool_switches"] += 1


func _maybe_recycle() -> void:
	if not main.sim.can_recycle():
		return
	await _recycle_via_panel()


## Abre el centro de reciclado con Tab y aprieta el botón de reciclar.
func _recycle_via_panel() -> void:
	_key(KEY_TAB)
	await _frames(20)
	_shoot("t%03d_reciclado_panel" % int(_t))
	var btn: StampButton = main.hud.recycle_panel._recycle_button
	if btn != null and btn.is_visible_in_tree():
		await _click_control(btn)
	await _frames(10)
	if not main.is_recycling(): # el botón no respondió: cierra el panel y sigue
		main.hud.close_recycle_panel()
		return
	_counts["recycles"] += 1
	await _frames(40)
	_shoot("t%03d_reciclando" % int(_t))
	while main.is_recycling():
		await _frames(5)


## Modo DEV: suma Pellets y Pops de la corrida, compra "Lámina más grande" y recicla a la fase siguiente.
func _dev_phase_jump() -> void:
	var sim: GameSim = main.sim
	var level: int = sim.state.perm_level("perm_sheet")
	sim.state.pellets += sim.upgrades.next_cost("perm_sheet", level)
	sim.buy("perm_sheet", 1)
	sim.state.pops_run = maxf(sim.state.pops_run, 4.0 * Cfg.num(sim.eco, "pellet_divisor"))
	_counts["phase_jumps"] += 1
	print("smoke: salto de fase DEV (lámina más grande nivel %d)" % sim.state.perm_level("perm_sheet"))
	await _recycle_via_panel()
	sim.state.pops += 50.0 * sim.upgrades.next_cost("finger_force", 0) # para que haya qué comprar
	await _frames(30)
	_shoot("t%03d_fase%d_llegada" % [int(_t), sim.phase()])


# --- Entrada real ----------------------------------------------------------------------------

func _random_sheet_point() -> Vector2:
	var c: Vector2 = main.sim.center()
	var ext: Vector2 = main.world.sheet_view.extents()
	return c + Vector2(_rng.randf_range(-0.42, 0.42) * ext.x, _rng.randf_range(-0.42, 0.42) * ext.y)


func _mouse_to_world(p: Vector2) -> void:
	var cam: Camera3D = main.world.camera_rig.camera
	_mouse_to_screen(cam.unproject_position(Vector3(p.x, 0.0, p.y)))


func _mouse_to_screen(sp: Vector2) -> void:
	Input.warp_mouse(sp)
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.position = sp
	ev.global_position = sp
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _down else 0
	_mouse = sp
	_send(ev)


func _button(pressed: bool) -> void:
	_down = pressed
	var sp: Vector2 = _mouse
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = sp
	ev.global_position = sp
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_send(ev)


## Clic real en el centro del control. Sin pantalla, el evento se le entrega directo al control
## (con --headless Godot no reparte la entrada y el estiramiento de pantalla no tiene tamaño real).
func _click_control(ctrl: Control) -> void:
	if not _headless():
		_mouse_to_screen(ctrl.get_global_rect().get_center())
		await _frames(2)
		_button(true)
		await _frames(2)
		_button(false)
		await _frames(2)
		return
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = ctrl.size * 0.5
		ctrl._gui_input(ev)
		await _frames(2)


func _key(code: int) -> void:
	if _headless(): # sin pantalla, la tecla va directo al manejador del juego
		main._on_key(code)
		return
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pressed
		_send(ev)


## Con ventana (CI) el sistema reparte el evento. Sin pantalla (--headless) Input lo acumula y nadie
## lo procesa: se vacía la cola (actualiza el estado del mouse) y se lo entrega al viewport a mano.
func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	if not _headless():
		return
	Input.flush_buffered_events()
	get_viewport().push_input(ev, true)


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


# --- Capturas y cierre ---------------------------------------------------------------------------

func _shoot(shot_name: String) -> void:
	print("PERF %s fase=%d nodos=%d objetos=%d mem_mb=%.1f draw_calls=%d fps=%.0f" % [shot_name, main.sim.phase(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_FPS)])
	if _headless(): # sin render (PC del dueño): solo la lógica
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [dir, shot_name])
	_shots += 1
	print("smoke: captura ", shot_name)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_shoot("t%03d_final" % int(_t))
	var s: GameState = main.sim.state
	print("SMOKE OK | %.0f s | fase %d | pops %.0f | capturas %d | %s" % [_t, main.sim.phase(), s.pops, _shots, JSON.stringify(_counts)])
	PopAudio.quit_clean()
