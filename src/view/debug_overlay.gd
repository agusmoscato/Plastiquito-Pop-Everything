class_name DebugOverlay
extends CanvasLayer
## Overlay de debug (F3): estadísticas, tamaño de lámina, pop masivo y ajustes rápidos.

signal cheat_pops_requested
signal mass_pop_requested

var world: ToyWorld
var panel: PanelContainer

var _label: Label
var _accum: float = 0.0


func _ready() -> void:
	layer = 50
	panel = PanelContainer.new()
	panel.position = Vector2(10.0, 10.0)
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(300.0, 0.0)
	box.add_child(_label)
	var cheat: Button = Button.new()
	cheat.text = "+1M Pops (trampa)"
	cheat.pressed.connect(func() -> void: cheat_pops_requested.emit())
	box.add_child(cheat)
	var mass: Button = Button.new()
	mass.text = "Pop masivo (radio 15)"
	mass.pressed.connect(func() -> void: mass_pop_requested.emit())
	box.add_child(mass)
	box.add_child(_check("Sacudida de cámara", Settings.shake_enabled, func(on: bool) -> void: Settings.shake_enabled = on; Settings.save_settings()))
	box.add_child(_check("Reducir movimiento", Settings.reduce_motion, func(on: bool) -> void: Settings.reduce_motion = on; Settings.save_settings()))
	box.add_child(_volume_slider())
	visible = false


func toggle() -> void:
	visible = not visible


func _process(delta: float) -> void:
	if not visible or world == null or world.sheet == null:
		return
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	var s: SheetModel = world.sheet
	_label.text = "fps: %d   frame: %.2f ms\nburbujas: %d   intactas: %d\nreventado: %.1f%%\nvoces activas: %d   racha: %d\ndraw calls: %d   bloques: %d" % [
		Engine.get_frames_per_second(), delta * 1000.0, s.cell_count(), s.count_intact() + s.count_tense(),
		s.popped_ratio() * 100.0, PopAudio.active_voices(), PopAudio.streak(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		world.sheet_view.chunk_count()]


func _check(text: String, value: bool, on_toggled: Callable) -> CheckBox:
	var c: CheckBox = CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.toggled.connect(on_toggled)
	return c


func _volume_slider() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = Label.new()
	l.text = "Volumen"
	row.add_child(l)
	var sl: HSlider = HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = Settings.get_volume("Master")
	sl.custom_minimum_size = Vector2(180.0, 0.0)
	sl.value_changed.connect(func(v: float) -> void: Settings.set_volume("Master", v); Settings.save_settings())
	row.add_child(sl)
	return row
