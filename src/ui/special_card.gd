class_name SpecialCard
extends Control
## Presentación de lo nuevo: la primera vez que aparece una especial (dorada, bomba, línea, eco), una veta
## de aire o el doble film, una tarjeta de papel dice qué es y qué hace, y una flecha de marcador señala
## una en la lámina. La tarjeta espera a que el jugador la pruebe (o se va sola a los 25 s). Cada cosa se
## presenta una sola vez por PC (Settings.introduced), aunque la partida venga de una versión vieja.

const VEIN: int = -1
const ARMOR: int = -2
const MAX_WAIT_S: float = 25.0
const THANKS_S: float = 1.6

var _type: int = 0
var _t: float = 0.0
var _thanks: float = 0.0
var pointer: Vector2 = Vector2.INF ## dónde está una en pantalla (lo actualiza el HUD)


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	material = UiKit.paper_material()


static func key_of(t: int) -> String:
	match t:
		VEIN:
			return "vein"
		ARMOR:
			return "armor"
	for d: Dictionary in BubbleLog.TYPES:
		var id: int = d["id"]
		if id == t:
			return str(d["key"])
	return ""


## Empieza la presentación de `t` (si no hay otra en curso).
func start_intro(t: int) -> bool:
	if is_busy() or key_of(t) == "":
		return false
	_type = t
	_t = MAX_WAIT_S
	_thanks = 0.0
	return true


## El jugador la probó: la tarjeta festeja un momento y se va.
func tried(t: int) -> void:
	if t == _type and _t > 0.0:
		_t = 0.0
		_thanks = THANKS_S


func is_busy() -> bool:
	return _t > 0.0 or _thanks > 0.0


func current_type() -> int:
	return _type if is_busy() else 0


## Compatibilidad: el aviso viejo de "burbuja nueva" ahora es una presentación.
func show_type(t: int) -> void:
	start_intro(t)


func _process(delta: float) -> void:
	_t = maxf(0.0, _t - delta)
	_thanks = maxf(0.0, _thanks - delta)
	visible = is_busy()
	if visible:
		queue_redraw()


func _card_rect() -> Rect2:
	var w: float = 500.0
	var play_w: float = size.x - 452.0
	return Rect2(Vector2((play_w - w) * 0.5 + 40.0, 96.0), Vector2(w, 112.0))


func _draw() -> void:
	var key: String = key_of(_type)
	var rect: Rect2 = _card_rect()
	var a: float = 1.0 if _thanks <= 0.0 else clampf(_thanks / 0.4, 0.0, 1.0)
	var age: float = MAX_WAIT_S - _t
	rect.position.y += (1.0 - clampf(age * 3.0, 0.0, 1.0)) * -30.0 if _thanks <= 0.0 else 0.0
	modulate = Color(1, 1, 1, a)
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "special_card", 2.0, 1.4)
	UiKit.draw_tape(self, Vector2(rect.position.x + 30.0, rect.position.y + 4.0), -0.5, 44.0, 14.0)
	UiKit.draw_tape(self, Vector2(rect.end.x - 30.0, rect.position.y + 4.0), 0.5, 44.0, 14.0)
	var dot: Vector2 = rect.position + Vector2(46.0, 58.0)
	draw_circle(dot, 22.0, color_of(_type))
	draw_arc(dot, 22.0, 0.0, TAU, 32, UiKit.INK, 2.0, true)
	draw_circle(dot + Vector2(-7.0, -8.0), 5.0, Color(1, 1, 1, 0.85))
	var x: float = 84.0
	var head: String = Tx.t("intro_new") if _type < 0 else Tx.t("new_special")
	UiKit.draw_text(self, rect.position + Vector2(x, 30.0), head, UiKit.font_mono_bold(), 11, UiKit.STAMP_RED)
	UiKit.draw_text(self, rect.position + Vector2(x, 54.0), Tx.t(key).to_upper(), UiKit.font_title(), 20, UiKit.INK)
	UiKit.draw_text(self, rect.position + Vector2(x, 76.0), Tx.t(key + "_d"), UiKit.font_text(), 13, UiKit.INK)
	var foot: String = Tx.t("intro_thanks") if _thanks > 0.0 else Tx.t("intro_try")
	UiKit.draw_text(self, rect.position + Vector2(x, 98.0), foot, UiKit.font_text_bold(), 12, UiKit.STAMP_RED if _thanks > 0.0 else UiKit.INK_SOFT)
	if _thanks <= 0.0 and pointer.is_finite():
		_draw_arrow(Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y + 4.0), pointer)


## Flecha de marcador desde la tarjeta hasta la burbuja (con una curva y el temblor del pulso).
func _draw_arrow(from: Vector2, to: Vector2) -> void:
	var wob: float = sin(Time.get_ticks_msec() * 0.01) * 4.0
	var end: Vector2 = to + (from - to).normalized() * 26.0 # no tapa la burbuja
	var ctrl: Vector2 = (from + end) * 0.5 + Vector2(60.0 + wob, 0.0)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		pts.append(from.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t))
	var ink: Color = Color(UiKit.STAMP_RED.r, UiKit.STAMP_RED.g, UiKit.STAMP_RED.b, 0.9)
	draw_polyline(pts, ink, 5.0, true)
	var dir: Vector2 = (pts[16] - pts[14]).normalized()
	draw_polyline(PackedVector2Array([pts[16] - dir.rotated(0.5) * 22.0, pts[16], pts[16] - dir.rotated(-0.5) * 22.0]), ink, 5.0, true)
	var pulse: float = 22.0 + 4.0 * sin(Time.get_ticks_msec() * 0.008)
	draw_arc(to, pulse, 0.0, TAU, 32, ink, 3.0, true)


## Color de cada cosa para la tarjeta.
static func color_of(t: int) -> Color:
	match t:
		VEIN:
			return Color("#F2A65A")
		ARMOR:
			return Color("#EEF1F3")
	return SpecialsView.color_of(t)
