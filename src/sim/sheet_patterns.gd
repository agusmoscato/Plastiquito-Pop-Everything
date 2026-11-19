class_name SheetPatterns
extends RefCounted
## Diseño de cada lámina (DESIGN, sesión 5): la fábrica no infla todas las burbujas igual. Cada lámina
## trae "vetas de aire": grupos de burbujas casi llenas (tensas) con forma de línea, anillo, racimo,
## zigzag o cruz. Reventar una burbuja de la veta encadena la veta entera: hay que mirar la lámina y
## elegir dónde apretar, en vez de cliquear al azar. Desde el Galpón aparece el doble film (burbujas
## que la herramienta tiene que aplastar dos veces; las cadenas las revientan igual).
## Todo número sale de data/sheet.json ("patterns"). Lógica pura.

const SHAPES: Array[String] = ["line", "ring", "cluster", "zigzag", "cross"]
## Las 6 direcciones del hexágono en el plano (para trazar líneas).
const DIRS: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.5, 0.866), Vector2(-0.5, 0.866),
	Vector2(-1.0, 0.0), Vector2(-0.5, -0.866), Vector2(0.5, -0.866)]


## Aplica las vetas y el doble film a una lámina nueva. Devuelve las celdas de veta.
static func apply(sheet: SheetModel, grid: HexGrid, rng: RandomNumberGenerator, phase: int, cfg: Dictionary) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var i: int = clampi(phase, 1, 4) - 1
	var per100: Array = cfg["veins_per_100_cells"]
	var density: float = per100[mini(i, per100.size() - 1)]
	var cells: int = sheet.cell_count()
	var count: int = maxi(1, roundi(float(cells) / 100.0 * density))
	var length: int = clampi(roundi(3.0 + sqrt(float(cells)) * Cfg.num(cfg, "vein_length_k")), 4, Cfg.integer(cfg, "vein_length_max"))
	var pmin: float = Cfg.num(cfg, "vein_pressure_min")
	var pmax: float = Cfg.num(cfg, "vein_pressure_max")
	var taken: Dictionary = {}
	for k: int in count:
		var shape: String = SHAPES[rng.randi() % SHAPES.size()]
		var start: int = rng.randi() % cells
		for idx: int in shape_cells(grid, shape, start, length, rng):
			if taken.has(idx):
				continue
			taken[idx] = true
			sheet.pressure[idx] = rng.randf_range(pmin, pmax)
			sheet.refresh_state(idx)
			out.append(idx)
	_apply_armor(sheet, rng, i, cfg, taken)
	return out


## Celdas de una forma alrededor de `start`, de `length` burbujas de largo (o radio parecido).
static func shape_cells(grid: HexGrid, shape: String, start: int, length: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var c: Vector2 = grid.cell_to_world(start)
	var dir: Vector2 = DIRS[rng.randi() % DIRS.size()]
	match shape:
		"ring":
			var r: float = grid.spacing * maxf(1.6, float(length) / 4.0)
			return _ring(grid, c, r)
		"cluster":
			return grid.cells_in_circle(c, grid.spacing * maxf(1.1, float(length) / 6.0))
		"zigzag":
			return _zigzag(grid, c, dir, length)
		"cross":
			var a: PackedInt32Array = _line(grid, c - dir * grid.spacing * float(length) * 0.5, dir, length)
			var other: Vector2 = DIRS[(DIRS.find(dir) + 2) % DIRS.size()]
			a.append_array(_line(grid, c - other * grid.spacing * float(length) * 0.5, other, length))
			return a
	return _line(grid, c, dir, length)


static func _line(grid: HexGrid, from: Vector2, dir: Vector2, length: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for s: int in length:
		var idx: int = grid.world_to_cell(from + dir * grid.spacing * float(s))
		if idx >= 0 and not out.has(idx):
			out.append(idx)
	return out


static func _zigzag(grid: HexGrid, from: Vector2, dir: Vector2, length: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var a: Vector2 = dir.rotated(PI / 6.0)
	var b: Vector2 = dir.rotated(-PI / 6.0)
	var p: Vector2 = from
	for s: int in length:
		var idx: int = grid.world_to_cell(p)
		if idx >= 0 and not out.has(idx):
			out.append(idx)
		@warning_ignore("integer_division")
		p += (a if (s / 3) % 2 == 0 else b) * grid.spacing
	return out


static func _ring(grid: HexGrid, c: Vector2, r: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for idx: int in grid.cells_in_circle(c, r + grid.spacing * 0.5):
		if grid.cell_to_world(idx).distance_to(c) >= r - grid.spacing * 0.5:
			out.append(idx)
	return out


## Doble film: una fracción de las burbujas que no son veta (desde el Galpón).
static func _apply_armor(sheet: SheetModel, rng: RandomNumberGenerator, i: int, cfg: Dictionary, skip: Dictionary) -> void:
	var fr: Array = cfg["armor_fraction"]
	var f: float = fr[mini(i, fr.size() - 1)]
	if f <= 0.0:
		return
	for idx: int in sheet.cell_count():
		if not skip.has(idx) and rng.randf() < f:
			sheet.armor[idx] = 1
