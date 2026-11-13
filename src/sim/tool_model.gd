class_name ToolModel
extends RefCounted
## Herramienta que aplasta burbujas. Formas: "single" (dedo), "circle" (palma), "segment"
## (palo de amasar: una franja perpendicular al arrastre). Lógica pura.
## Cada frame se llama a step() con las celdas tocadas: suma fuerza * delta de aplastamiento
## y, al aplastar, pasa aire a las vecinas libres. Al llegar a la resistencia la burbuja
## queda "reventada" en el resultado; el reparto de aire del reventón lo hace ChainSolver.
## Las celdas que dejan de tocarse recuperan su aplastamiento solas.

const SHAPE_SINGLE: String = "single"
const SHAPE_CIRCLE: String = "circle"
const SHAPE_SEGMENT: String = "segment"
const SHAPE_RECT: String = "rect" ## plancha
const SHAPE_STOMP: String = "stomp" ## bota

var sheet: SheetModel
var grid: HexGrid
var shape: String = SHAPE_SINGLE
var force_per_second: float = 8.0
var resistance: float = 1.0
var recovery_per_second: float = 1.5
## Fracción de la resistencia que recibe al instante una celda a la que se entra arrastrando.
var drag_entry_fraction: float = 1.0
## Radio del golpe en unidades del mundo (círculo) o media longitud del rodillo (segmento).
var radius: float = 0.0
## Fracción de la presión que pasa a las vecinas mientras se aplasta (0 = nada).
var air_share: float = 0.0
## Sesgo del aire hacia la dirección del arrastre (palo de amasar).
var direction_bias: float = 0.0
## Cuánto más rápido cede el centro que el borde (palma): fuerza = 1 + falloff * (1 - d/r).
var center_falloff: float = 0.0

## Plancha: el calor sube la presión de las burbujas cercanas (hasta heat_cap) antes de tocarlas.
var heat_rate: float = 0.0 ## presión por segundo
var heat_cap: float = 1.4
var heat_reach: float = 1.6 ## el aura es la plancha agrandada por este factor
## Bota: pisotón con tiempo de recarga y onda expansiva.
var cooldown: float = 4.0
var cooldown_left: float = 0.0
var wave_k: float = 0.5 ## fracción de la presión pisada que la onda empuja hacia afuera
var wave_reach: float = 2.5 ## en celdas
var last_wave_cells: PackedInt32Array = PackedInt32Array()

## Resultados del último step().
var popped: PackedInt32Array = PackedInt32Array()
var new_pressed: int = 0 ## celdas que empezaron a aplastarse en este step
var last_weights: PackedFloat32Array = PackedFloat32Array()

var _active: Dictionary = {} ## celdas con press > 0 (idx -> true)
var _prev_touched: Dictionary = {} ## celdas tocadas en el step anterior
var _holding: bool = false
var _roller_dir: Vector2 = Vector2(1.0, 0.0) ## orientación del rodillo


func _init(p_sheet: SheetModel, p_grid: HexGrid) -> void:
	sheet = p_sheet
	grid = p_grid


## Carga los parámetros desde los diccionarios de data/ (tools.json "balance" y sheet.json).
func configure(tool_balance: Dictionary, sheet_cfg: Dictionary) -> void:
	force_per_second = Cfg.num(tool_balance, "force_per_second")
	drag_entry_fraction = Cfg.num(tool_balance, "drag_entry_fraction")
	resistance = Cfg.num(sheet_cfg, "resistance")
	recovery_per_second = Cfg.num(sheet_cfg, "recovery_per_second")


func reset_state() -> void:
	_active.clear()
	_prev_touched.clear()
	_holding = false


## Celdas que toca el cursor al moverse de `from` a `to` (forma "single").
## Camina el trayecto en pasos menores que una burbuja para no saltear ninguna.
func cells_along(from: Vector2, to: Vector2) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var dist: float = from.distance_to(to)
	var steps: int = maxi(1, ceili(dist / (grid.bubble_radius * 0.5)))
	var last: int = -2
	for i: int in range(steps + 1):
		var cell: int = grid.world_to_cell(from.lerp(to, float(i) / float(steps)))
		if cell >= 0 and cell != last:
			if not out.has(cell):
				out.append(cell)
			last = cell
	return out


## Celdas tocadas por la herramienta al moverse de `from` a `to`, según su forma.
## Deja los pesos de fuerza por celda en last_weights.
func cells_for(from: Vector2, to: Vector2) -> PackedInt32Array:
	last_weights = PackedFloat32Array()
	if shape == SHAPE_CIRCLE or shape == SHAPE_STOMP:
		return _circle_cells(from, to)
	if shape == SHAPE_RECT:
		return _rect_cells(from, to)
	if shape == SHAPE_SEGMENT:
		return _roller_cells(from, to)
	if radius > 0.0:
		return _circle_cells(from, to)
	var cells: PackedInt32Array = cells_along(from, to)
	for i: int in cells.size():
		last_weights.append(1.0)
	return cells


func roller_direction() -> Vector2:
	return _roller_dir


func _circle_cells(from: Vector2, to: Vector2) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var steps: int = maxi(1, ceili(from.distance_to(to) / maxf(radius * 0.5, grid.bubble_radius)))
	for i: int in range(steps + 1):
		var c: Vector2 = from.lerp(to, float(i) / float(steps))
		for idx: int in grid.cells_in_circle(c, radius):
			if not seen.has(idx):
				seen[idx] = true
				out.append(idx)
				last_weights.append(_falloff_weight(grid.cell_to_world(idx).distance_to(to)))
	return out


func _falloff_weight(dist_to_center: float) -> float:
	if center_falloff <= 0.0 or radius <= 0.0:
		return 1.0
	return maxf(0.2, 1.0 + center_falloff * (1.0 - minf(dist_to_center / radius, 1.0)))


func _plate_rotation(from: Vector2, to: Vector2) -> float:
	var move: Vector2 = to - from
	if move.length() > grid.bubble_radius * 0.2:
		_roller_dir = move.normalized()
	return _roller_dir.angle() + PI * 0.5


func _rect_cells(from: Vector2, to: Vector2) -> PackedInt32Array:
	var rot: float = _plate_rotation(from, to)
	var out: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var steps: int = maxi(1, ceili(from.distance_to(to) / grid.bubble_radius))
	for i: int in range(steps + 1):
		var c: Vector2 = from.lerp(to, float(i) / float(steps))
		for idx: int in grid.cells_in_rect(c, Vector2(radius * 2.0, radius * 0.8), rot):
			if not seen.has(idx):
				seen[idx] = true
				out.append(idx)
				last_weights.append(1.0)
	return out


## Calor de la plancha: sube la presión de las burbujas del aura (sin reventar) hasta heat_cap.
## El aire no se crea de la nada: el calor solo infla hasta un tope menor que la presión máxima.
func apply_heat(center: Vector2, dt: float) -> PackedInt32Array:
	var changed: PackedInt32Array = PackedInt32Array()
	if heat_rate <= 0.0:
		return changed
	var rot: float = _roller_dir.angle() + PI * 0.5
	var size: Vector2 = Vector2(radius * 2.0, radius * 0.8) * heat_reach
	for idx: int in grid.cells_in_rect(center, size, rot):
		if sheet.state[idx] == SheetModel.STATE_POPPED:
			continue
		var room: float = heat_cap - sheet.pressure[idx]
		if room > 0.0:
			sheet.add_pressure_quiet(idx, minf(heat_rate * dt, room))
			changed.append(idx)
	sheet.notify_changed(changed)
	return changed


func tick_cooldown(dt: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - dt)


func stomp_ready() -> bool:
	return cooldown_left <= 0.0


## Pisotón: revienta el círculo y empuja una onda de presión hacia afuera, pagada con el aire de
## lo pisado (wave_k limitado por 1 - chain_k, así el total de aire nunca aumenta). Devuelve lo pisado.
func stomp(center: Vector2, chain_k: float) -> PackedInt32Array:
	last_wave_cells = PackedInt32Array()
	var out: PackedInt32Array = PackedInt32Array()
	if not stomp_ready():
		return out
	cooldown_left = cooldown
	var budget: float = 0.0
	var share: float = minf(wave_k, maxf(0.0, 1.0 - chain_k))
	for idx: int in grid.cells_in_circle(center, radius):
		if sheet.state[idx] != SheetModel.STATE_POPPED:
			sheet.press[idx] = 0.0
			_active.erase(idx)
			out.append(idx)
			budget += sheet.pressure[idx] * share
	_push_wave(center, budget)
	return out


func _push_wave(center: Vector2, budget: float) -> void:
	if budget <= 0.0:
		return
	var reach: float = wave_reach * grid.spacing
	var ring: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_w: float = 0.0
	for idx: int in grid.cells_in_circle(center, radius + reach):
		if sheet.state[idx] == SheetModel.STATE_POPPED:
			continue
		var d: float = grid.cell_to_world(idx).distance_to(center)
		if d <= radius:
			continue
		var w: float = maxf(0.05, 1.0 - (d - radius) / reach)
		ring.append(idx)
		weights.append(w)
		total_w += w
	if ring.is_empty():
		return
	for i: int in ring.size():
		sheet.add_pressure_quiet(ring[i], budget * weights[i] / total_w)
	last_wave_cells = ring
	sheet.notify_changed(ring)


func _roller_cells(from: Vector2, to: Vector2) -> PackedInt32Array:
	var move: Vector2 = to - from
	if move.length() > grid.bubble_radius * 0.2:
		_roller_dir = move.normalized()
	var normal: Vector2 = Vector2(-_roller_dir.y, _roller_dir.x)
	var out: PackedInt32Array = PackedInt32Array()
	var seen: Dictionary = {}
	var steps: int = maxi(1, ceili(move.length() / grid.bubble_radius))
	for i: int in range(steps + 1):
		var c: Vector2 = from.lerp(to, float(i) / float(steps))
		for idx: int in grid.cells_in_segment(c - normal * radius, c + normal * radius, grid.bubble_radius * 0.9):
			if not seen.has(idx):
				seen[idx] = true
				out.append(idx)
				last_weights.append(1.0)
	return out


## Avanza la simulación. `touched` son las celdas bajo la herramienta (vacío si no se aprieta);
## `weights` (opcional) multiplica la fuerza por celda; `dir` es la dirección del arrastre.
## Devuelve las burbujas que alcanzaron la resistencia en este paso (sin repartir su aire).
func step(touched: PackedInt32Array, delta: float, weights: PackedFloat32Array = PackedFloat32Array(),
		dir: Vector2 = Vector2.ZERO) -> PackedInt32Array:
	popped = PackedInt32Array()
	new_pressed = 0
	var changed: PackedInt32Array = PackedInt32Array()
	var now_touched: Dictionary = {}
	for idx: int in touched:
		now_touched[idx] = true
	var dragging: bool = _holding and not touched.is_empty()
	for i: int in touched.size():
		var idx: int = touched[i]
		var w: float = weights[i] if i < weights.size() else 1.0
		_press_cell(idx, delta * w, dragging and not _prev_touched.has(idx), changed, now_touched, dir)
	_recover_untouched(now_touched, delta, changed)
	_holding = not touched.is_empty()
	_prev_touched = now_touched
	if not changed.is_empty():
		sheet.notify_changed(changed)
	return popped


## Revienta celdas de golpe (debug, "pop masivo"). Devuelve las que reventó.
func pop_cells(cells: PackedInt32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for idx: int in cells:
		if sheet.state[idx] != SheetModel.STATE_POPPED:
			sheet.press[idx] = 0.0
			_active.erase(idx)
			out.append(idx)
	sheet.pop_many(out)
	popped = out
	return out


func active_count() -> int:
	return _active.size()


func _press_cell(idx: int, delta: float, entered_dragging: bool, changed: PackedInt32Array,
		now_touched: Dictionary, dir: Vector2) -> void:
	if sheet.state[idx] == SheetModel.STATE_POPPED:
		return
	var before: float = sheet.press[idx]
	if before <= 0.0 and not _active.has(idx):
		new_pressed += 1
	var gain: float = force_per_second * delta
	if entered_dragging:
		gain += drag_entry_fraction * resistance
	var value: float = before + gain
	_squeeze_air(idx, minf(gain, resistance - before) / resistance, now_touched, dir, changed)
	if value >= resistance:
		sheet.press[idx] = 0.0
		_active.erase(idx)
		popped.append(idx)
		return
	sheet.press[idx] = value
	_active[idx] = true
	changed.append(idx)


## Al aplastar sin reventar, la burbuja pasa parte de su aire a las vecinas libres.
func _squeeze_air(idx: int, fraction: float, now_touched: Dictionary, dir: Vector2, changed: PackedInt32Array) -> void:
	if air_share <= 0.0 or fraction <= 0.0:
		return
	var amount: float = maxf(0.0, sheet.pressure[idx] - sheet.min_pressure) * air_share * fraction
	var taken: float = AirModel.spread(sheet, grid, idx, amount, dir, direction_bias, now_touched, changed)
	if taken > 0.0:
		sheet.pressure[idx] -= taken
		sheet.refresh_state(idx)


func _recover_untouched(now_touched: Dictionary, delta: float, changed: PackedInt32Array) -> void:
	var finished: Array[int] = []
	for key: Variant in _active:
		var idx: int = key
		if now_touched.has(idx):
			continue
		var value: float = sheet.press[idx] - recovery_per_second * delta
		if value <= 0.0:
			value = 0.0
			finished.append(idx)
		sheet.press[idx] = value
		changed.append(idx)
	for idx: int in finished:
		_active.erase(idx)
