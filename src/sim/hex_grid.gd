class_name HexGrid
extends RefCounted
## Grilla hexagonal pointy-top en filas desplazadas "odd-r".
## Índice = r * width + q. Plano del mundo: XZ, representado como Vector2(x, z).
## La burbuja es un círculo de radio `bubble_radius`; las burbujas vecinas se tocan,
## así que la distancia entre centros contiguos de una fila es 2 * bubble_radius.

const SQRT3: float = 1.7320508075688772

## Deltas de vecinos (dq, dr) según paridad de la fila (odd-r).
const _NEIGHBORS_EVEN: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(-1, 1), Vector2i(0, 1),
]
const _NEIGHBORS_ODD: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1),
]

var width: int
var height: int
var bubble_radius: float
var spacing: float ## distancia entre centros en una fila (= 2 * radio)
var hex_size: float ## circunradio del hexágono
var row_step: float ## distancia en Z entre filas (= 1.5 * hex_size)


func _init(p_width: int = 1, p_height: int = 1, p_bubble_radius: float = 0.5) -> void:
	width = p_width
	height = p_height
	bubble_radius = p_bubble_radius
	spacing = 2.0 * p_bubble_radius
	hex_size = spacing / SQRT3
	row_step = 1.5 * hex_size


func cell_count() -> int:
	return width * height


# --- Índices y coordenadas -------------------------------------------------

func index(q: int, r: int) -> int:
	return r * width + q


@warning_ignore("integer_division")
func coords(idx: int) -> Vector2i:
	return Vector2i(idx % width, idx / width)


func in_bounds(q: int, r: int) -> bool:
	return q >= 0 and q < width and r >= 0 and r < height


func neighbors(idx: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var c: Vector2i = coords(idx)
	var deltas: Array[Vector2i] = _NEIGHBORS_ODD if (c.y & 1) == 1 else _NEIGHBORS_EVEN
	for d: Vector2i in deltas:
		var nq: int = c.x + d.x
		var nr: int = c.y + d.y
		if in_bounds(nq, nr):
			out.append(index(nq, nr))
	return out


# --- Mundo <-> celda ---------------------------------------------------------

func cell_to_world(idx: int) -> Vector2:
	var c: Vector2i = coords(idx)
	return Vector2(spacing * (float(c.x) + 0.5 * float(c.y & 1)), row_step * float(c.y))


## Devuelve el índice de la celda bajo `pos` o -1 si cae fuera de la grilla.
func world_to_cell(pos: Vector2) -> int:
	var qf: float = (SQRT3 / 3.0 * pos.x - pos.y / 3.0) / hex_size
	var rf: float = (2.0 / 3.0 * pos.y) / hex_size
	var axial: Vector2i = _cube_round(qf, rf)
	var row: int = axial.y
	var col: int = axial.x + ((row - (row & 1)) >> 1)
	if not in_bounds(col, row):
		return -1
	return index(col, row)


func _cube_round(qf: float, rf: float) -> Vector2i:
	var xf: float = qf
	var zf: float = rf
	var yf: float = -xf - zf
	var rx: float = roundf(xf)
	var ry: float = roundf(yf)
	var rz: float = roundf(zf)
	var dx: float = absf(rx - xf)
	var dy: float = absf(ry - yf)
	var dz: float = absf(rz - zf)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


# --- Formas de golpe -----------------------------------------------------------
# Todas devuelven las celdas cuyo CENTRO queda dentro de la forma, recorriendo
# solo las filas y columnas del área afectada.

func cells_in_circle(center: Vector2, radius: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if radius < 0.0:
		return out
	for r: int in _row_range(center.y - radius, center.y + radius):
		var span: Vector2 = _disc_span(center, radius, float(r) * row_step)
		_append_span(out, r, span.x, span.y)
	return out


## Cápsula de ancho 2*half_width alrededor del segmento a-b (palo, aplanadora).
func cells_in_segment(a: Vector2, b: Vector2, half_width: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if half_width < 0.0:
		return out
	var dir: Vector2 = b - a
	var normal: Vector2 = Vector2(0.0, 1.0)
	if dir.length_squared() > 0.0:
		normal = Vector2(-dir.y, dir.x).normalized()
	var off: Vector2 = normal * half_width
	var body: PackedVector2Array = PackedVector2Array([a + off, b + off, b - off, a - off])
	var min_z: float = minf(a.y, b.y) - half_width
	var max_z: float = maxf(a.y, b.y) + half_width
	for r: int in _row_range(min_z, max_z):
		var z: float = float(r) * row_step
		var span: Vector2 = _span_union(_polygon_span(body, z), _disc_span(a, half_width, z))
		span = _span_union(span, _disc_span(b, half_width, z))
		_append_span(out, r, span.x, span.y)
	return out


## Rectángulo rotado `rotation` radianes alrededor de su centro (plancha, prensa).
func cells_in_rect(center: Vector2, size: Vector2, rotation: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if size.x < 0.0 or size.y < 0.0:
		return out
	var hx: Vector2 = Vector2.RIGHT.rotated(rotation) * (size.x * 0.5)
	var hy: Vector2 = Vector2.DOWN.rotated(rotation) * (size.y * 0.5)
	var poly: PackedVector2Array = PackedVector2Array([
		center + hx + hy, center + hx - hy, center - hx - hy, center - hx + hy,
	])
	var min_z: float = poly[0].y
	var max_z: float = poly[0].y
	for p: Vector2 in poly:
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	for r: int in _row_range(min_z, max_z):
		var span: Vector2 = _polygon_span(poly, float(r) * row_step)
		_append_span(out, r, span.x, span.y)
	return out


# --- Helpers de formas ---------------------------------------------------------

const _EMPTY_SPAN: Vector2 = Vector2(1.0, -1.0) ## lo > hi = vacío


func _row_range(min_z: float, max_z: float) -> Array[int]:
	var first: int = maxi(0, ceili(min_z / row_step))
	var last: int = mini(height - 1, floori(max_z / row_step))
	var rows: Array[int] = []
	for r: int in range(first, last + 1):
		rows.append(r)
	return rows


func _disc_span(center: Vector2, radius: float, z: float) -> Vector2:
	var dz: float = z - center.y
	var rem: float = radius * radius - dz * dz
	if rem < 0.0:
		return _EMPTY_SPAN
	var half: float = sqrt(rem)
	return Vector2(center.x - half, center.x + half)


## Intervalo en X de un polígono convexo a la altura z.
func _polygon_span(poly: PackedVector2Array, z: float) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	var n: int = poly.size()
	for i: int in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		if (p.y - z) * (q.y - z) > 0.0:
			continue
		if is_equal_approx(p.y, q.y):
			lo = minf(lo, minf(p.x, q.x))
			hi = maxf(hi, maxf(p.x, q.x))
			continue
		var x: float = p.x + (z - p.y) / (q.y - p.y) * (q.x - p.x)
		lo = minf(lo, x)
		hi = maxf(hi, x)
	if lo > hi:
		return _EMPTY_SPAN
	return Vector2(lo, hi)


func _span_union(a: Vector2, b: Vector2) -> Vector2:
	if a.x > a.y:
		return b
	if b.x > b.y:
		return a
	return Vector2(minf(a.x, b.x), maxf(a.y, b.y))


## Agrega las celdas de la fila r cuyo centro en X cae dentro de [lo, hi].
func _append_span(out: PackedInt32Array, r: int, lo: float, hi: float) -> void:
	if lo > hi:
		return
	var shift: float = 0.5 * float(r & 1)
	var first: int = maxi(0, ceili(lo / spacing - shift))
	var last: int = mini(width - 1, floori(hi / spacing - shift))
	for q: int in range(first, last + 1):
		out.append(index(q, r))
