class_name TitleScreen
extends CanvasLayer
## Menú de inicio: el juego no arranca de una al abrirlo. Una hoja de papel sobre el escritorio
## (mismo material que el HUD) con el título, una tira de burbujas dibujadas que se pueden reventar
## mientras uno decide, y los botones: Jugar / Continuar, Nueva partida (pide confirmación),
## Opciones (abre el menú de opciones) y Salir. El juego queda pausado detrás hasta elegir.

signal started

const W: float = 560.0
const H: float = 600.0
const BUBBLES: int = 7
const BUBBLE_R: float = 26.0

var has_save: bool = false
var options_menu: PauseMenu

var _root: Control
var _play: StampButton
var _new: StampButton
var _options: StampButton
var _quit: StampButton
var _confirm_new: float = 0.0 ## segundos que queda activa la confirmación de "Nueva partida"
var _t: float = 0.0
var _pop: PackedFloat32Array = PackedFloat32Array() ## 0 entera, 0..1 reventando, >=1 reventada
var _regrow: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.draw.connect(_draw_title)
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_play = _button(_txt("CONTINUAR", "CONTINUE") if has_save else _txt("JUGAR", "PLAY"), Vector2(300.0, 64.0), UiKit.STAMP_RED, _start)
	_play.font_size = 26
	_play.filled = true
	_new = _button(_txt("NUEVA PARTIDA", "NEW GAME"), Vector2(300.0, 46.0), UiKit.CARDBOARD_DARK, _new_game)
	_new.visible = has_save
	_options = _button(_txt("OPCIONES", "OPTIONS"), Vector2(300.0, 46.0), UiKit.CARDBOARD_DARK, _open_options)
	_quit = _button(_txt("SALIR", "QUIT"), Vector2(300.0, 46.0), UiKit.CARDBOARD_DARK, _quit_game)
	_pop.resize(BUBBLES)
	_regrow.resize(BUBBLES)
	_place()
	if options_menu != null:
		options_menu.suppressed = true
	get_tree().paused = true


func is_open() -> bool:
	return _root.visible


func _txt(es: String, en: String) -> String:
	return es if Settings.language == "es" else en


func _button(text: String, size: Vector2, color: Color, action: Callable) -> StampButton:
	var b: StampButton = StampButton.new()
	b.setup(text, size, color)
	b.font_size = 18
	b.pressed.connect(action)
	_root.add_child(b)
	return b


func _card() -> Rect2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5), Vector2(W, H))


func _place() -> void:
	var r: Rect2 = _card()
	var y: float = r.position.y + 300.0
	for b: StampButton in [_play, _new, _options, _quit]:
		if not b.visible:
			continue
		b.position = Vector2(r.position.x + (W - b.size.x) * 0.5, y)
		y += b.size.y + 14.0


## Centro de la burbuja i de la tira (en pantalla).
func bubble_center(i: int) -> Vector2:
	var r: Rect2 = _card()
	var gap: float = (W - 80.0) / float(BUBBLES - 1)
	return Vector2(r.position.x + 40.0 + gap * float(i), r.position.y + 228.0)


## Índice de la burbuja bajo `p`, o -1.
func bubble_at(p: Vector2) -> int:
	for i: int in BUBBLES:
		if p.distance_to(bubble_center(i)) <= BUBBLE_R and _pop[i] <= 0.0:
			return i
	return -1


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pop_bubble(bubble_at(mb.position))


## Revienta una burbuja de la tira (con el sonido del juego). Vuelve a inflarse sola.
func pop_bubble(i: int) -> void:
	if i < 0 or i >= BUBBLES or _pop[i] > 0.0:
		return
	_pop[i] = 0.001
	_regrow[i] = 2.5
	PopAudio.report_frame(1, 1.0, 0.016)


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_t += delta
	_confirm_new = maxf(0.0, _confirm_new - delta)
	if _confirm_new <= 0.0 and has_save:
		_new.text = _txt("NUEVA PARTIDA", "NEW GAME")
	for i: int in BUBBLES:
		if _pop[i] > 0.0:
			_pop[i] = minf(_pop[i] + delta * 6.0, 1.0)
			_regrow[i] -= delta
			if _regrow[i] <= 0.0:
				_pop[i] = 0.0
	_place()
	_root.queue_redraw()


func _start() -> void:
	PopAudio.play_ui("stamp")
	_root.visible = false
	if options_menu != null:
		options_menu.suppressed = false
	get_tree().paused = false
	started.emit()


## Borra la partida guardada: pide un segundo clic dentro de 3 s.
func _new_game() -> void:
	if _confirm_new <= 0.0:
		_confirm_new = 3.0
		_new.text = _txt("¿SEGURO? TOCÁ DE NUEVO", "SURE? CLICK AGAIN")
		return
	SaveSystem.wipe()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _open_options() -> void:
	if options_menu != null:
		options_menu.open_options()


func _quit_game() -> void:
	SaveSystem.save_now()
	PopAudio.quit_clean()


func _draw_title() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_root.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.10, 0.06, 0.03, 0.55))
	var r: Rect2 = _card()
	UiKit.draw_sheet(_root, r, UiKit.PAPER, "title_sheet", 4.0, 2.0)
	UiKit.draw_tape(_root, r.position + Vector2(44.0, 6.0), -0.45, 70.0, 20.0)
	UiKit.draw_tape(_root, Vector2(r.end.x - 44.0, r.position.y + 6.0), 0.45, 70.0, 20.0)
	var bob: float = sin(_t * 1.6) * 3.0
	var title_rect: Rect2 = Rect2(r.position + Vector2(40.0, 52.0 + bob), Vector2(W - 80.0, 92.0))
	UiKit.draw_stamp(_root, title_rect, "PLASTIQUITO", UiKit.STAMP_RED, 54, -0.04, 1.0)
	UiKit.draw_text(_root, r.position + Vector2(0.0, 178.0), "POP EVERYTHING", UiKit.font_mono_bold(), 18, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, W)
	for i: int in BUBBLES:
		_draw_bubble(bubble_center(i), _pop[i], i)
	UiKit.draw_text(_root, r.position + Vector2(0.0, 278.0), _txt("reventá alguna mientras decidís", "pop a few while you decide"), UiKit.font_text(), 13, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, W)
	UiKit.draw_text(_root, Vector2(16.0, vp.y - 18.0), "v" + AppInfo.version(), UiKit.font_mono(), 12, Color(1, 1, 1, 0.6))


## Burbuja dibujada: domo celeste con brillo; al reventar se achata y queda arrugada.
func _draw_bubble(c: Vector2, pop: float, i: int) -> void:
	var breathe: float = 1.0 + 0.025 * sin(_t * 2.2 + float(i))
	if pop <= 0.0:
		_root.draw_circle(c + Vector2(2.0, 4.0), BUBBLE_R * breathe, Color(0.1, 0.06, 0.02, 0.18))
		_root.draw_circle(c, BUBBLE_R * breathe, Color(UiKit.BUBBLE_BLUE.r, UiKit.BUBBLE_BLUE.g, UiKit.BUBBLE_BLUE.b, 0.85))
		_root.draw_arc(c, BUBBLE_R * breathe, 0.0, TAU, 40, UiKit.INK, 2.0, true)
		_root.draw_circle(c + Vector2(-8.0, -9.0), 6.0, Color(1, 1, 1, 0.9))
		return
	var k: float = clampf(pop, 0.0, 1.0)
	var rad: float = BUBBLE_R * (1.0 + 0.25 * sin(k * PI))
	var flat: Color = Color(UiKit.PAPER_SHADE.r, UiKit.PAPER_SHADE.g, UiKit.PAPER_SHADE.b, 0.9)
	_root.draw_circle(c, rad * 0.9, flat)
	_root.draw_arc(c, rad * 0.9, 0.0, TAU, 40, UiKit.INK_SOFT, 1.5, true)
	if k < 1.0: # el aire que sale: un aro que se abre
		_root.draw_arc(c, rad * (1.0 + k), 0.0, TAU, 40, Color(1, 1, 1, 1.0 - k), 3.0, true)
