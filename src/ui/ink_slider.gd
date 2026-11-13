class_name InkSlider
extends Control
## Deslizador de volumen: una línea de tinta con una cinta de embalar como perilla.

signal value_changed(value: float)
signal released

var value: float = 0.8

var _dragging: bool = false


func setup(p_value: float, p_size: Vector2) -> void:
	value = p_value
	custom_minimum_size = p_size
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_set_from_x(mb.position.x)
			else:
				released.emit()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		_set_from_x(mm.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	value = clampf((x - 14.0) / (size.x - 28.0), 0.0, 1.0)
	value_changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var y: float = size.y * 0.5
	var x0: float = 14.0
	var x1: float = size.x - 14.0
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.25), 3.0)
	draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, value), y), UiKit.INK, 3.0)
	for i: int in 11:
		var tx: float = lerpf(x0, x1, float(i) / 10.0)
		draw_line(Vector2(tx, y + 6.0), Vector2(tx, y + 11.0), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.5), 1.0)
	UiKit.draw_tape(self, Vector2(lerpf(x0, x1, value), y), 0.25, 26.0, 20.0)
