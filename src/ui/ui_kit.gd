class_name UiKit
extends RefCounted
## Materiales del HUD (docs/UI_STYLE.md): cartón kraft, papel, cinta, sellos de goma, tinta.
## Todo se dibuja por código; este archivo concentra la paleta, las fuentes y los dibujos base.

const KRAFT: Color = Color("#C8A27A")
const KRAFT_DARK: Color = Color("#8E6B47")
const CARDBOARD_DARK: Color = Color("#5A4330")
const PAPER: Color = Color("#F4EFE6")
const PAPER_SHADE: Color = Color("#DDD4C2")
const INK: Color = Color("#1E1B18")
const INK_SOFT: Color = Color(0.118, 0.106, 0.094, 0.62)
const STAMP_RED: Color = Color("#C8322B")
const TAPE: Color = Color(0.62, 0.43, 0.23, 0.62)
const BUBBLE_BLUE: Color = Color("#8FD0F2")
const SHADOW: Color = Color(0.1, 0.06, 0.02, 0.35)

static var _paper_material: ShaderMaterial
static var _fonts: Dictionary = {}


# --- Fuentes (OFL, assets/fonts) -----------------------------------------------------------

static func font_title() -> Font:
	return _font("title", "res://assets/fonts/BowlbyOne-Regular.ttf", 0)


static func font_text() -> Font:
	return _font("text", "res://assets/fonts/Archivo.ttf", 500)


static func font_text_bold() -> Font:
	return _font("text_bold", "res://assets/fonts/Archivo.ttf", 750)


static func font_mono() -> Font:
	return _font("mono", "res://assets/fonts/SpaceMono-Regular.ttf", 0)


static func font_mono_bold() -> Font:
	return _font("mono_bold", "res://assets/fonts/SpaceMono-Bold.ttf", 0)


static func _font(key: String, path: String, weight: int) -> Font:
	if _fonts.has(key):
		var cached: Font = _fonts[key]
		return cached
	var base: FontFile = load(path) as FontFile
	var out: Font = base
	if weight > 0 and base != null:
		var v: FontVariation = FontVariation.new()
		v.base_font = base
		v.variation_opentype = {"wght": weight}
		out = v
	if out == null:
		out = ThemeDB.fallback_font
	_fonts[key] = out
	return out


## Material con el grano de cartón (shaders/paper.gdshader). Se asigna a Controls con _draw().
static func paper_material(corrugated: float = 0.0) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/paper.gdshader") as Shader
	m.set_shader_parameter("corrugated", corrugated)
	return m


# --- Determinismo --------------------------------------------------------------------------

## Valor estable 0..1 a partir de un texto (la inclinación de cada etiqueta no cambia por frame).
static func hash01(text: String, salt: int = 0) -> float:
	var h: int = hash(text) + salt * 7919
	return float(absi(h) % 10000) / 10000.0


## Inclinación fija por id, entre -1,5° y +1,5° (en radianes).
static func tilt(id: String) -> float:
	return deg_to_rad(lerpf(-1.5, 1.5, hash01(id)))


# --- Dibujo base ---------------------------------------------------------------------------

## Polígono de papel con bordes levemente irregulares (determinístico por `seed_text`).
static func paper_polygon(rect: Rect2, seed_text: String, jitter: float = 1.4) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var step: float = 22.0
	var idx: int = 0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for c: int in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var n: int = maxi(1, int(a.distance_to(b) / step))
		for i: int in n:
			var p: Vector2 = a.lerp(b, float(i) / float(n))
			var jx: float = (hash01(seed_text, idx * 2) - 0.5) * 2.0 * jitter
			var jy: float = (hash01(seed_text, idx * 2 + 1) - 0.5) * 2.0 * jitter
			if i == 0:
				jx *= 0.4
				jy *= 0.4
			pts.append(p + Vector2(jx, jy))
			idx += 1
	return pts


## Hoja de papel (o cartón) con sombra proyectada abajo a la derecha.
static func draw_sheet(ci: CanvasItem, rect: Rect2, color: Color, seed_text: String, lift: float = 0.0, jitter: float = 1.4) -> void:
	var poly: PackedVector2Array = paper_polygon(rect, seed_text, jitter)
	var shadow_off: Vector2 = Vector2(3.0 + lift, 4.0 + lift * 1.5)
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in poly:
		shadow.append(p + shadow_off)
	ci.draw_colored_polygon(shadow, Color(SHADOW.r, SHADOW.g, SHADOW.b, SHADOW.a + lift * 0.02))
	ci.draw_colored_polygon(poly, color)
	var edge: PackedVector2Array = poly.duplicate()
	edge.append(poly[0])
	ci.draw_polyline(edge, color.darkened(0.22), 1.0, true)


## Pedacito de cinta de embalar (marrón translúcido) con puntas en zigzag.
static func draw_tape(ci: CanvasItem, center: Vector2, angle: float, length: float = 46.0, width: float = 16.0) -> void:
	var half: Vector2 = Vector2(length * 0.5, width * 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	var zig: float = 3.0
	pts.append(Vector2(-half.x, -half.y))
	pts.append(Vector2(half.x, -half.y))
	for i: int in range(1, 4): # borde derecho en zigzag (puntas cortadas)
		pts.append(Vector2(half.x - (zig if i % 2 == 1 else 0.0), -half.y + width * float(i) / 4.0))
	pts.append(Vector2(half.x, half.y))
	pts.append(Vector2(-half.x, half.y))
	for i: int in range(3, 0, -1):
		pts.append(Vector2(-half.x + (zig if i % 2 == 1 else 0.0), -half.y + width * float(i) / 4.0))
	var xf: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		xf.append(center + p.rotated(angle))
	ci.draw_colored_polygon(xf, TAPE)
	var shine: PackedVector2Array = PackedVector2Array([
		center + Vector2(-half.x * 0.7, -half.y * 0.2).rotated(angle),
		center + Vector2(half.x * 0.7, -half.y * 0.2).rotated(angle),
	])
	ci.draw_polyline(shine, Color(1.0, 0.95, 0.85, 0.25), 1.5)


## Texto con sombra de tinta corrida opcional.
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, font: Font, size: int, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(font, pos, text, align, width, size, color)


## Sello de goma: borde doble, texto en Bowlby, color tinta roja con desgaste (puntitos faltantes).
static func draw_stamp(ci: CanvasItem, rect: Rect2, text: String, color: Color = STAMP_RED, size: int = 20, angle: float = -0.07, alpha: float = 1.0) -> void:
	ci.draw_set_transform(rect.get_center(), angle, Vector2.ONE)
	var r: Rect2 = Rect2(-rect.size * 0.5, rect.size)
	var c: Color = Color(color.r, color.g, color.b, color.a * alpha)
	ci.draw_rect(r, c, false, 3.0)
	ci.draw_rect(r.grow(-5.0), c, false, 1.5)
	var font: Font = font_title()
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	ci.draw_string(font, Vector2(-ts.x * 0.5, ts.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)
	# Desgaste de la tinta: puntos de papel que se asoman.
	for i: int in 18:
		var px: float = lerpf(r.position.x, r.end.x, hash01(text, i * 3))
		var py: float = lerpf(r.position.y, r.end.y, hash01(text, i * 3 + 1))
		ci.draw_circle(Vector2(px, py), 0.8 + hash01(text, i * 3 + 2) * 1.2, Color(PAPER.r, PAPER.g, PAPER.b, 0.55 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Barra de progreso de tinta sobre una línea de cuaderno.
static func draw_ink_bar(ci: CanvasItem, rect: Rect2, ratio: float, color: Color = INK) -> void:
	ci.draw_rect(rect, Color(INK.r, INK.g, INK.b, 0.12))
	var fill: Rect2 = Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y))
	ci.draw_rect(fill, color)
	ci.draw_rect(rect, Color(INK.r, INK.g, INK.b, 0.55), false, 1.0)
	for i: int in range(1, 10):
		var x: float = rect.position.x + rect.size.x * float(i) / 10.0
		ci.draw_line(Vector2(x, rect.end.y - 3.0), Vector2(x, rect.end.y), Color(INK.r, INK.g, INK.b, 0.5), 1.0)
