class_name PauseMenu
extends CanvasLayer
## Menú con Esc: una hoja de papel sobre el escritorio. Volumen general, sacudida, idioma,
## abrir carpeta de datos y salir. Mismo material que el resto del HUD (docs/UI_STYLE.md).

const W: float = 420.0
const H: float = 470.0

var _root: Control
var _shake_button: StampButton
var _lang_button: StampButton
var _slider: InkSlider
var _rows: Array = []
var _bottom: Array = []


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.draw.connect(_draw_menu)
	add_child(_root)
	_slider = InkSlider.new()
	_slider.setup(Settings.get_volume("Master"), Vector2(280.0, 36.0))
	_slider.value_changed.connect(func(v: float) -> void: Settings.set_volume("Master", v))
	_slider.released.connect(Settings.save_settings)
	_root.add_child(_slider)
	_shake_button = _button("", Vector2(W - 60.0, 44.0), UiKit.CARDBOARD_DARK, _toggle_shake)
	_lang_button = _button("", Vector2(W - 60.0, 44.0), UiKit.CARDBOARD_DARK, _toggle_language)
	var folder: StampButton = _button("ABRIR CARPETA DE DATOS", Vector2(W - 60.0, 44.0), UiKit.CARDBOARD_DARK, _open_data_folder)
	folder.font_size = 14
	var back: StampButton = _button("VOLVER AL JUEGO", Vector2(180.0, 50.0), UiKit.STAMP_RED, close)
	var quit_button: StampButton = _button("SALIR", Vector2(150.0, 50.0), UiKit.CARDBOARD_DARK, _quit)
	_rows = [_slider, _shake_button, _lang_button, folder]
	_bottom = [back, quit_button]
	_place(_rows, _bottom)
	_refresh_labels()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		_root.visible = true
		get_tree().paused = true
		_place(_rows, _bottom)
		_refresh_labels()


func close() -> void:
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size


func _button(text: String, size: Vector2, color: Color, action: Callable) -> StampButton:
	var b: StampButton = StampButton.new()
	b.setup(text, size, color)
	b.font_size = 16
	b.pressed.connect(action)
	_root.add_child(b)
	return b


func _place(rows: Array, bottom: Array) -> void:
	var vp: Vector2 = _vp()
	var left: float = (vp.x - W) * 0.5
	var top: float = (vp.y - H) * 0.5
	var ys: Array[float] = [150.0, 222.0, 278.0, 334.0]
	for i: int in rows.size():
		var c: Control = rows[i]
		var y: float = ys[i]
		c.position = Vector2(left + 30.0 if i > 0 else left + 70.0, top + y)
	var bx: float = left + 30.0
	for c: Control in bottom:
		c.position = Vector2(bx, top + H - 76.0)
		bx += c.size.x + 20.0


func _refresh_labels() -> void:
	_shake_button.text = "SACUDIDA DE CÁMARA: %s" % ("SÍ" if Settings.shake_enabled else "NO")
	_shake_button.toggled_on = Settings.shake_enabled
	_shake_button.font_size = 14
	_lang_button.text = "IDIOMA: %s" % Settings.language.to_upper()
	_lang_button.font_size = 14


func _toggle_shake() -> void:
	Settings.shake_enabled = not Settings.shake_enabled
	Settings.save_settings()
	_refresh_labels()


func _toggle_language() -> void:
	Settings.language = "en" if Settings.language == "es" else "es"
	Settings.save_settings()
	_refresh_labels()


func _open_data_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _quit() -> void:
	SaveSystem.save_now()
	Playtest.write_now()
	get_tree().quit()


func _draw_menu() -> void:
	var vp: Vector2 = _vp()
	_root.draw_rect(Rect2(Vector2.ZERO, vp * 2.0), Color(0.07, 0.04, 0.02, 0.6))
	var rect: Rect2 = Rect2(Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5), Vector2(W, H))
	UiKit.draw_sheet(_root, rect, UiKit.PAPER, "pause_sheet", 3.0, 1.8)
	UiKit.draw_tape(_root, rect.position + Vector2(30.0, 4.0), -0.5, 56.0, 18.0)
	UiKit.draw_tape(_root, Vector2(rect.end.x - 30.0, rect.position.y + 4.0), 0.5, 56.0, 18.0)
	UiKit.draw_text(_root, rect.position + Vector2(30.0, 64.0), "PAUSA" if Settings.language == "es" else "PAUSED", UiKit.font_title(), 30, UiKit.INK)
	UiKit.draw_text(_root, rect.position + Vector2(30.0, 104.0), "VOLUMEN GENERAL" if Settings.language == "es" else "MASTER VOLUME", UiKit.font_mono_bold(), 12, UiKit.INK_SOFT)
	var pct: String = "%d%%" % int(Settings.get_volume("Master") * 100.0)
	UiKit.draw_text(_root, rect.position + Vector2(W - 100.0, 104.0), pct, UiKit.font_mono_bold(), 14, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 70.0)
