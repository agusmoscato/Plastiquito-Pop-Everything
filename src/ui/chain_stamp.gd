class_name ChainStamp
extends Control
## "CADENA xN": un sello que crece mientras la cadena sigue y golpea al terminar con el total
## ganado. Es el momento más satisfactorio del juego, así que tiene peso.

signal slammed(count: int)

var count: int = 0
var growing: bool = false
var total_text: String = ""
var banner: String = "" ## anuncio (por ejemplo "¡LÁMINA LISTA!") en lugar de "CADENA xN"
var anchor: Vector2 = Vector2(-1.0, -1.0) ## origen de la cadena en pantalla (el sello va arriba)
var free_rect: Rect2 = Rect2() ## zona libre de paneles donde puede ir el sello
var blocked: Array[Rect2] = [] ## paneles del HUD: el sello nunca va encima
var max_width: float = 0.0 ## ancho máximo del sello (35 % del área de juego); 0 = sin tope
const ALPHA: float = 0.85 ## mientras dura: deja ver la ola por debajo
const BASE_W: float = 300.0 ## ancho del sello a escala 1
const MAX_PLAY_FRACTION: float = 0.35 ## el sello ocupa como mucho este ancho del área de juego
const LIFT: float = 95.0 ## distancia mínima entre el origen de la cadena y el borde de abajo del sello

var _slam: float = 0.0
var _hold: float = 0.0
var _fade: float = 0.0
var _shake: Vector2 = Vector2.ZERO


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	material = UiKit.paper_material()


func chain_progress(n: int) -> void:
	banner = ""
	count = n
	growing = true
	_hold = 0.0
	_fade = 1.0


## Sello de anuncio con el mismo golpe que el de la cadena (lámina terminada).
func announce(text: String) -> void:
	banner = text
	count = 2
	growing = false
	total_text = ""
	_slam = 1.0
	_hold = 1.1
	_fade = 1.0


func chain_ended(n: int, total: float) -> void:
	banner = ""
	count = n
	growing = false
	total_text = "+" + NumberFormat.pops(total, Settings.language)
	_slam = 1.0
	_hold = 1.6
	_fade = 1.0
	slammed.emit(n)


func _process(delta: float) -> void:
	_slam = maxf(0.0, _slam - delta * 3.0)
	if not growing:
		_hold = maxf(0.0, _hold - delta)
		if _hold <= 0.0:
			_fade = maxf(0.0, _fade - delta * 2.5)
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (_slam * 7.0 + (1.5 if growing else 0.0))
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.01 or count < 2:
		return
	var scale_f: float = capped_scale(1.0 + minf(float(count) / 60.0, 1.2) + _slam * 0.55, max_width)
	var w: float = BASE_W * scale_f
	var h: float = 76.0 * scale_f
	var block: Vector2 = Vector2(w, h + (44.0 * minf(scale_f, 1.8) if not growing else 0.0)) # sello + total abajo
	var block_c: Vector2 = place(anchor, block, free_rect, blocked, Vector2(size.x * 0.5 - 150.0, 250.0))
	var center: Vector2 = block_c - Vector2(0.0, (block.y - h) * 0.5) + _shake
	var r: Rect2 = Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var label: String = banner if banner != "" else "%s x%d" % [Tx.t("chain"), count]
	UiKit.draw_stamp(self, r, label, UiKit.STAMP_RED, int(30.0 * scale_f), -0.09, _fade * ALPHA)
	if not growing and total_text != "":
		var font: Font = UiKit.font_mono_bold()
		var fs: int = int(26.0 * minf(scale_f, 1.8))
		var ts: Vector2 = font.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		var pos: Vector2 = Vector2(center.x - ts.x * 0.5, r.end.y + 34.0)
		draw_string(font, pos + Vector2(2.0, 2.0), total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.PAPER.r, UiKit.PAPER.g, UiKit.PAPER.b, _fade))
		draw_string(font, pos, total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, _fade))


## Centro del sello: arriba del origen de la cadena (para no tapar la ola), dentro de la zona libre.
## Sin origen conocido usa `fallback`.
static func stamp_center(origin: Vector2, stamp_size: Vector2, free: Rect2, fallback: Vector2) -> Vector2:
	if origin.x < 0.0 or free.size == Vector2.ZERO:
		return fallback
	var c: Vector2 = origin - Vector2(0.0, LIFT + stamp_size.y * 0.5)
	var half: Vector2 = stamp_size * 0.5
	c.x = clampf(c.x, free.position.x + half.x, maxf(free.position.x + half.x, free.end.x - half.x))
	c.y = clampf(c.y, free.position.y + half.y, maxf(free.position.y + half.y, free.end.y - half.y))
	return c


## Escala del sello con tope: el ancho nunca pasa `max_w` (0 = sin tope).
static func capped_scale(scale_f: float, max_w: float) -> float:
	if max_w <= 0.0:
		return scale_f
	return minf(scale_f, max_w / BASE_W)


## Como stamp_center, pero si el sello cae sobre un panel prueba otras posiciones dentro de la zona
## libre (abajo del origen, después las esquinas y el centro) y se queda con la que menos tapa.
static func place(origin: Vector2, stamp_size: Vector2, free: Rect2, panels: Array[Rect2], fallback: Vector2) -> Vector2:
	var first: Vector2 = stamp_center(origin, stamp_size, free, fallback)
	if free.size == Vector2.ZERO:
		return first
	var half: Vector2 = stamp_size * 0.5
	var below: Vector2 = stamp_center(origin + Vector2(0.0, 2.0 * LIFT + stamp_size.y), stamp_size, free, fallback)
	var lo: Vector2 = free.position + half
	var hi: Vector2 = Vector2(maxf(lo.x, free.end.x - half.x), maxf(lo.y, free.end.y - half.y))
	var options: Array[Vector2] = [first, below, Vector2(first.x, lo.y), Vector2(first.x, hi.y),
			Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), Vector2(hi.x, hi.y), (lo + hi) * 0.5]
	var best: Vector2 = first
	var best_overlap: float = INF
	for c: Vector2 in options:
		var overlap: float = overlap_area(Rect2(c - half, stamp_size), panels)
		if overlap < best_overlap - 0.5:
			best = c
			best_overlap = overlap
	return best


static func overlap_area(r: Rect2, panels: Array[Rect2]) -> float:
	var total: float = 0.0
	for p: Rect2 in panels:
		var i: Rect2 = r.intersection(p)
		total += i.get_area()
	return total
