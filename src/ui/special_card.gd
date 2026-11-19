class_name SpecialCard
extends Control
## La primera vez que aparece una burbuja especial, una tarjeta de papel arriba de la lámina dice
## cuál es y qué hace (antes aparecían doradas y bombas sin que el jugador supiera para qué).
## Si aparecen varias juntas, se muestran de a una.

const SHOW_S: float = 6.5

var _queue: Array[int] = []
var _type: int = 0
var _t: float = 0.0


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	material = UiKit.paper_material()


func show_type(t: int) -> void:
	if t == _type and _t > 0.0 or _queue.has(t):
		return
	_queue.append(t)


func current_type() -> int:
	return _type if _t > 0.0 else 0


static func key_of(t: int) -> String:
	for d: Dictionary in BubbleLog.TYPES:
		var id: int = d["id"]
		if id == t:
			return str(d["key"])
	return ""


func _process(delta: float) -> void:
	if _t <= 0.0 and not _queue.is_empty():
		_type = _queue.pop_front()
		_t = SHOW_S
	_t = maxf(0.0, _t - delta)
	visible = _t > 0.0 and key_of(_type) != ""
	if visible:
		queue_redraw()


func _draw() -> void:
	var key: String = key_of(_type)
	var w: float = 470.0
	var play_w: float = size.x - 452.0
	var a: float = clampf(_t * 2.0, 0.0, 1.0) * clampf((SHOW_S - _t) * 4.0, 0.0, 1.0)
	var drop: float = (1.0 - clampf((SHOW_S - _t) * 3.0, 0.0, 1.0)) * -30.0 # entra cayendo un poco
	var rect: Rect2 = Rect2(Vector2((play_w - w) * 0.5, 104.0 + drop), Vector2(w, 104.0))
	modulate = Color(1, 1, 1, a)
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "special_card", 2.0, 1.4)
	UiKit.draw_tape(self, Vector2(rect.position.x + 30.0, rect.position.y + 4.0), -0.5, 44.0, 14.0)
	UiKit.draw_tape(self, Vector2(rect.end.x - 30.0, rect.position.y + 4.0), 0.5, 44.0, 14.0)
	var dot: Vector2 = rect.position + Vector2(46.0, 56.0)
	draw_circle(dot, 22.0, SpecialsView.color_of(_type))
	draw_arc(dot, 22.0, 0.0, TAU, 32, UiKit.INK, 2.0, true)
	draw_circle(dot + Vector2(-7.0, -8.0), 5.0, Color(1, 1, 1, 0.85))
	var x: float = 84.0
	UiKit.draw_text(self, rect.position + Vector2(x, 30.0), Tx.t("new_special"), UiKit.font_mono_bold(), 11, UiKit.STAMP_RED)
	UiKit.draw_text(self, rect.position + Vector2(x, 54.0), Tx.t(key).to_upper(), UiKit.font_title(), 20, UiKit.INK)
	UiKit.draw_text(self, rect.position + Vector2(x, 76.0), Tx.t(key + "_d"), UiKit.font_text(), 13, UiKit.INK)
	UiKit.draw_text(self, rect.position + Vector2(x, 94.0), Tx.t("special_more"), UiKit.font_text(), 11, UiKit.INK_SOFT)
