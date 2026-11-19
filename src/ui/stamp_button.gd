class_name StampButton
extends Control
## Botón de sello de goma o etiqueta de cartón. Se hunde un poco al apretarlo.

signal pressed

var text: String = ""
var sub_text: String = ""
var color: Color = UiKit.STAMP_RED
var filled: bool = false ## true: sello relleno (tinta llena)
var toggled_on: bool = false
var font_size: int = 16
var disabled: bool = false
var seed_id: String = ""
var text_bottom: bool = false ## el texto va abajo (deja arriba lugar para un ícono)
var badge: int = 0 ## > 0: un círculo rojo con el número (cosas listas para sellar en esa pestaña)

var _down: bool = false
var _hover: bool = false
var _punch: float = 0.0


func setup(p_text: String, p_size: Vector2, p_color: Color = UiKit.STAMP_RED) -> void:
	text = p_text
	custom_minimum_size = p_size
	size = p_size
	color = p_color
	seed_id = p_text
	pivot_offset = p_size * 0.5
	rotation = UiKit.tilt(p_text)
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material()
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false; _down = false)


func _process(delta: float) -> void:
	_punch = maxf(0.0, _punch - delta * 4.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not disabled:
				_down = true
				accept_event()
			elif not mb.pressed and _down:
				_down = false
				_punch = 1.0
				pressed.emit()
				accept_event()


func _draw() -> void:
	var off: Vector2 = Vector2(0.0, 2.0 if _down else (-1.0 if _hover and not disabled else 0.0))
	var rect: Rect2 = Rect2(off + Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
	var base: Color = UiKit.PAPER if not toggled_on else color.lerp(UiKit.PAPER, 0.15)
	if disabled:
		base = UiKit.PAPER_SHADE
	UiKit.draw_sheet(self, rect, base, seed_id, 0.0 if _down else 1.0, 1.0)
	var ink: Color = UiKit.INK_SOFT if disabled else (UiKit.PAPER if toggled_on else color)
	draw_rect(rect.grow(-3.0), ink, false, 2.0)
	var font: Font = UiKit.font_title()
	var fs: int = font_size
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var ty: float = rect.position.y + rect.size.y * 0.5 + ts.y * 0.32
	if sub_text != "":
		ty -= 6.0
	if text_bottom:
		ty = rect.end.y - 9.0
	draw_string(font, Vector2(rect.position.x + (rect.size.x - ts.x) * 0.5, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, ink)
	if sub_text != "":
		UiKit.draw_text(self, Vector2(rect.position.x, ty + 15.0), sub_text, UiKit.font_mono(), 11, ink, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if badge > 0:
		_draw_badge(Vector2(rect.end.x - 4.0, rect.position.y + 4.0))


## Sello rojo redondo con la cantidad, en la esquina (late suave para que se note sin gritar).
func _draw_badge(at: Vector2) -> void:
	var r: float = 11.0 + 1.2 * sin(Time.get_ticks_msec() * 0.006)
	draw_circle(at + Vector2(1.5, 2.0), r, Color(0, 0, 0, 0.25))
	draw_circle(at, r, UiKit.STAMP_RED)
	draw_arc(at, r - 2.0, 0.0, TAU, 24, UiKit.PAPER, 1.5, true)
	var label: String = str(badge) if badge < 10 else "9+"
	UiKit.draw_text(self, at + Vector2(-r, 5.0), label, UiKit.font_mono_bold(), 13, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
