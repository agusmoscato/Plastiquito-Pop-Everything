class_name PauseMenu
extends CanvasLayer
## Menú mínimo con Esc: volumen general, sacudida sí/no, abrir carpeta de datos y salir.

var _root: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.05, 0.1, 0.55)
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(340.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_volume_row())
	var shake: CheckBox = CheckBox.new()
	shake.text = "Sacudida de cámara"
	shake.button_pressed = Settings.shake_enabled
	shake.toggled.connect(func(on: bool) -> void: Settings.shake_enabled = on; Settings.save_settings())
	box.add_child(shake)
	box.add_child(_button("Abrir carpeta de datos", _open_data_folder))
	box.add_child(_button("Volver al juego", close))
	box.add_child(_button("Salir", _quit))
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		_root.visible = true
		get_tree().paused = true


func close() -> void:
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


func _open_data_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _quit() -> void:
	Playtest.write_now()
	get_tree().quit()


func _button(text: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(action)
	return b


func _volume_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = Label.new()
	l.text = "Volumen"
	row.add_child(l)
	var sl: HSlider = HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = Settings.get_volume("Master")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(200.0, 0.0)
	sl.value_changed.connect(func(v: float) -> void: Settings.set_volume("Master", v))
	sl.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	row.add_child(sl)
	return row
