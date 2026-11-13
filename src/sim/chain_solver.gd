class_name ChainSolver
extends RefCounted
## Cola de cadenas con presupuesto de reventones por frame (DESIGN 3.2 y 8).
## Al reventar, una burbuja reparte k * presión entre sus vecinas sin reventar (el resto se
## pierde). Las que llegan a max_pressure se encolan y revientan solas. Las especiales
## encolan más celdas (Bomba: radio 3; Línea: su fila). Repartir la cadena en varios
## frames dibuja la ola.

const TYPE_GOLDEN: int = 1
const TYPE_BOMB: int = 2
const TYPE_LINE: int = 3

var sheet: SheetModel
var grid: HexGrid
var k: float = 0.5 ## fracción de la presión que reparte al reventar (< punto crítico)
var budget_per_frame: int = 40
var bomb_radius: float = 3.0 ## en unidades de celda (se multiplica por el espaciado)

## Eventos del último step()/pop_now(): índice, presión al reventar y tipo.
var events_idx: PackedInt32Array = PackedInt32Array()
var events_pressure: PackedFloat32Array = PackedFloat32Array()
var events_type: PackedByteArray = PackedByteArray()

var _queue: PackedInt32Array = PackedInt32Array()
var _head: int = 0
var _queued: Dictionary = {}


func _init(p_sheet: SheetModel, p_grid: HexGrid) -> void:
	sheet = p_sheet
	grid = p_grid


func is_idle() -> bool:
	return _head >= _queue.size()


func pending() -> int:
	return _queue.size() - _head


func clear_events() -> void:
	events_idx = PackedInt32Array()
	events_pressure = PackedFloat32Array()
	events_type = PackedByteArray()


## Encola una celda para reventar (si no está reventada ni encolada).
func enqueue(idx: int) -> void:
	if sheet.state[idx] == SheetModel.STATE_POPPED or _queued.has(idx):
		return
	_queued[idx] = true
	_queue.append(idx)


## Revienta `idx` ahora (por una herramienta o por la cola), reparte el aire y dispara
## el efecto de su tipo. No hace nada si ya estaba reventada.
func pop_now(idx: int) -> bool:
	if sheet.state[idx] == SheetModel.STATE_POPPED:
		return false
	var p: float = sheet.pressure[idx]
	var t: int = sheet.type[idx]
	sheet.press[idx] = 0.0
	sheet.pop(idx)
	events_idx.append(idx)
	events_pressure.append(p)
	events_type.append(t)
	_release_air(idx, p)
	_trigger_special(idx, t)
	return true


## Procesa hasta `budget_per_frame` reventones de la cola. Devuelve cuántos reventó.
func step() -> int:
	var done: int = 0
	while done < budget_per_frame and _head < _queue.size():
		var idx: int = _queue[_head]
		_head += 1
		_queued.erase(idx)
		if pop_now(idx):
			done += 1
	if _head >= _queue.size():
		_queue = PackedInt32Array()
		_head = 0
	return done


## Reparte k * presión entre las vecinas sin reventar y encola las que llegan al máximo.
func _release_air(idx: int, p: float) -> void:
	var changed: PackedInt32Array = PackedInt32Array()
	AirModel.spread(sheet, grid, idx, k * p, Vector2.ZERO, 0.0, {}, changed)
	for n: int in changed:
		if sheet.pressure[n] >= sheet.max_pressure:
			enqueue(n)
	sheet.notify_changed(changed)


func _trigger_special(idx: int, t: int) -> void:
	if t == TYPE_BOMB:
		var center: Vector2 = grid.cell_to_world(idx)
		for n: int in grid.cells_in_circle(center, bomb_radius * grid.spacing + 0.01):
			enqueue(n)
	elif t == TYPE_LINE:
		_enqueue_row_outward(idx)


## Encola la fila de `idx` en las dos direcciones, alternando para que la ola salga del centro.
func _enqueue_row_outward(idx: int) -> void:
	var c: Vector2i = grid.coords(idx)
	var left: int = c.x - 1
	var right: int = c.x + 1
	while left >= 0 or right < grid.width:
		if right < grid.width:
			enqueue(grid.index(right, c.y))
			right += 1
		if left >= 0:
			enqueue(grid.index(left, c.y))
			left -= 1
