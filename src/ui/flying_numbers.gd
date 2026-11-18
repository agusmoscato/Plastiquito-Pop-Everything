class_name FlyingNumbers
extends Control
## Cada "+N" vuela desde la burbuja reventada hasta el contador por una curva y se suma al llegar.
## Reglas de legibilidad (jornada B2): como mucho MAX_ITEMS en pantalla (los que sobran se suman al
## más cercano), una cadena entera es un solo "+N", texto con contorno, y nunca se dibujan dentro
## de un panel del HUD (pasan "por detrás" del panel y se suman al llegar).

signal arrived(value: float)

const MAX_ITEMS: int = 12
const OUTLINE: int = 5
const MERGE_PX: float = 80.0 ## un "+N" que sale a menos de esto de otro recién nacido se suma a ese
const MERGE_S: float = 0.3
const POP_IN_S: float = 0.12 ## al nacer el número crece de golpe y se asienta

var target: Vector2 = Vector2(150.0, 80.0)
var blocked: Array[Rect2] = [] ## paneles del HUD: ahí no se dibuja ningún "+N"

var _items: Array[Dictionary] = []


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Agrega un "+valor" que sale de `from` (pantalla). Con el tope lleno se suma al más cercano.
func spawn(from: Vector2, value: float) -> void:
	var near: int = merge_target(_items, from, MERGE_PX, MERGE_S)
	if near >= 0: # no se apilan dos números en el mismo lugar: el reciente crece
		var it: Dictionary = _items[near]
		var prev_v: float = it["value"]
		it["value"] = prev_v + value
		it["bump"] = 1.0
		return
	if _items.size() >= MAX_ITEMS:
		var nearest: Dictionary = _items[0]
		var best: float = INF
		for it: Dictionary in _items:
			var it_from: Vector2 = it["from"]
			var d: float = it_from.distance_squared_to(from)
			if d < best:
				best = d
				nearest = it
		var prev: float = nearest["value"]
		nearest["value"] = prev + value
		return
	var dur: float = randf_range(0.55, 0.8)
	var side: float = randf_range(-90.0, 90.0)
	var start: Vector2 = outside_panels(from)
	_items.append({"from": start, "value": value, "t": 0.0, "dur": dur, "bump": 0.0, "ctrl": start.lerp(target, 0.35) + Vector2(side, -randf_range(60.0, 140.0))})


## Índice del número recién nacido (menos de `max_age` s) más cercano a `from` dentro de `radius`, o -1.
static func merge_target(items: Array[Dictionary], from: Vector2, radius: float, max_age: float) -> int:
	var best: int = -1
	var best_d: float = radius * radius
	for i: int in items.size():
		var it: Dictionary = items[i]
		var age: float = it["t"]
		if age > max_age:
			continue
		var it_from: Vector2 = it["from"]
		var d: float = it_from.distance_squared_to(from)
		if d <= best_d:
			best_d = d
			best = i
	return best


func pending() -> int:
	return _items.size()


## Si el punto cae dentro de un panel, lo corre al borde más cercano de ese panel (afuera).
func outside_panels(p: Vector2) -> Vector2:
	for r: Rect2 in blocked:
		if not r.has_point(p):
			continue
		var opts: Array[Vector2] = [Vector2(r.position.x - 8.0, p.y), Vector2(r.end.x + 8.0, p.y), Vector2(p.x, r.position.y - 8.0), Vector2(p.x, r.end.y + 24.0)]
		var best: Vector2 = opts[0]
		for o: Vector2 in opts:
			if o.distance_squared_to(p) < best.distance_squared_to(p):
				best = o
		return best
	return p


func _inside_panel(p: Vector2) -> bool:
	for r: Rect2 in blocked:
		if r.grow(4.0).has_point(p):
			return true
	return false


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for it: Dictionary in _items:
		var t: float = it["t"]
		var dur: float = it["dur"]
		t += delta
		if t >= dur:
			var v: float = it["value"]
			arrived.emit(v)
			continue
		it["t"] = t
		var bump: float = it.get("bump", 0.0)
		it["bump"] = maxf(0.0, bump - delta * 6.0)
		keep.append(it)
	_items = keep
	queue_redraw()


func _draw() -> void:
	var font: Font = UiKit.font_mono_bold()
	for it: Dictionary in _items:
		var t: float = it["t"]
		var dur: float = it["dur"]
		var k: float = t / dur
		var e: float = k * k * (3.0 - 2.0 * k)
		var a: Vector2 = it["from"]
		var c: Vector2 = it["ctrl"]
		var p: Vector2 = a.lerp(c, e).lerp(c.lerp(target, e), e)
		if _inside_panel(p):
			continue
		var v: float = it["value"]
		var pop_in: float = clampf(1.0 - t / POP_IN_S, 0.0, 1.0)
		var bump: float = it.get("bump", 0.0)
		var grow: float = 1.0 + 0.45 * pop_in * pop_in + 0.25 * bump
		var fs: int = clampi(int((14.0 + log(maxf(v, 1.0)) / log(10.0) * 3.0) * grow), 14, 44)
		var text: String = "+" + NumberFormat.pops(v, Settings.language)
		var alpha: float = clampf((1.0 - k) * 2.2, 0.0, 1.0)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, OUTLINE, Color(UiKit.PAPER.r, UiKit.PAPER.g, UiKit.PAPER.b, alpha))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, alpha))
