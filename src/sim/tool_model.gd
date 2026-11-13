class_name ToolModel
extends RefCounted
## Herramienta que aplasta burbujas (por ahora solo la forma "single": el dedo).
## Lógica pura. Cada frame se llama a step() con las celdas tocadas:
## suma fuerza * delta de aplastamiento; al llegar a la resistencia la burbuja revienta.
## Las celdas que dejan de tocarse recuperan su aplastamiento solas.
## TODO(fase 2+): formas circle/segment/rect y aire (DESIGN.md 3.2).

const SHAPE_SINGLE: String = "single"

var sheet: SheetModel
var grid: HexGrid
var shape: String = SHAPE_SINGLE
var force_per_second: float = 8.0
var resistance: float = 1.0
var recovery_per_second: float = 1.5
## Fracción de la resistencia que recibe al instante una celda a la que se entra arrastrando.
var drag_entry_fraction: float = 1.0

## Resultados del último step().
var popped: PackedInt32Array = PackedInt32Array()
var new_pressed: int = 0 ## celdas que empezaron a aplastarse en este step

var _active: Dictionary = {} ## celdas con press > 0 (idx -> true)
var _prev_touched: Dictionary = {} ## celdas tocadas en el step anterior
var _holding: bool = false


func _init(p_sheet: SheetModel, p_grid: HexGrid) -> void:
	sheet = p_sheet
	grid = p_grid


## Carga los parámetros desde los diccionarios de data/ (tools.json "balance" y sheet.json).
func configure(tool_balance: Dictionary, sheet_cfg: Dictionary) -> void:
	force_per_second = float(tool_balance["force_per_second"])
	drag_entry_fraction = float(tool_balance["drag_entry_fraction"])
	resistance = float(sheet_cfg["resistance"])
	recovery_per_second = float(sheet_cfg["recovery_per_second"])


## Celdas que toca el cursor al moverse de `from` a `to` (en el plano XZ).
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


## Avanza la simulación. `touched` son las celdas bajo la herramienta (vacío si no se aprieta).
## Devuelve las burbujas reventadas en este paso.
func step(touched: PackedInt32Array, delta: float) -> PackedInt32Array:
	popped = PackedInt32Array()
	new_pressed = 0
	var changed: PackedInt32Array = PackedInt32Array()
	var now_touched: Dictionary = {}
	var dragging: bool = _holding and not touched.is_empty()
	for idx: int in touched:
		now_touched[idx] = true
		_press_cell(idx, delta, dragging and not _prev_touched.has(idx), changed)
	_recover_untouched(now_touched, delta, changed)
	_holding = not touched.is_empty()
	_prev_touched = now_touched
	if not changed.is_empty():
		sheet.notify_changed(changed)
	if not popped.is_empty():
		sheet.pop_many(popped)
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


func _press_cell(idx: int, delta: float, entered_dragging: bool, changed: PackedInt32Array) -> void:
	if sheet.state[idx] == SheetModel.STATE_POPPED:
		return
	var before: float = sheet.press[idx]
	if before <= 0.0 and not _active.has(idx):
		new_pressed += 1
	var gain: float = force_per_second * delta
	if entered_dragging:
		gain += drag_entry_fraction * resistance
	var value: float = before + gain
	if value >= resistance:
		sheet.press[idx] = 0.0
		_active.erase(idx)
		popped.append(idx)
		return
	sheet.press[idx] = value
	_active[idx] = true
	changed.append(idx)


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
