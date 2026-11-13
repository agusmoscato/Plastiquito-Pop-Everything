class_name AutoRoller
extends RefCounted
## Rodillo automático: recorre la lámina en barridas (de izquierda a derecha y de vuelta, bajando
## una franja por fila) reventando lo que pasa. Lógica pura.

var sheet: SheetModel
var grid: HexGrid
var enabled: bool = false
var speed: float = 3.0 ## celdas por segundo
var half_width: float = 2.0 ## en celdas (media altura de la franja)

var pos: Vector2 = Vector2.ZERO ## posición actual (plano XZ), para dibujarlo
var _dir: float = 1.0
var _row_center: float = 0.0


func _init(p_sheet: SheetModel, p_grid: HexGrid) -> void:
	sheet = p_sheet
	grid = p_grid
	reset()


func reset() -> void:
	_dir = 1.0
	_row_center = half_width * grid.spacing
	pos = Vector2(0.0, _row_center)


## Devuelve las celdas sin reventar que la franja barre durante `dt` segundos.
func step(dt: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not enabled:
		return out
	var before: Vector2 = pos
	var advance: float = speed * grid.spacing * dt
	pos.x += _dir * advance
	var max_x: float = grid.spacing * float(grid.width)
	if pos.x > max_x or pos.x < 0.0:
		_dir = -_dir
		pos.x = clampf(pos.x, 0.0, max_x)
		_row_center += 2.0 * half_width * grid.spacing * 0.9
		if _row_center > grid.row_step * float(grid.height) + half_width * grid.spacing:
			_row_center = half_width * grid.spacing
	pos.y = _row_center
	var reach: float = half_width * grid.spacing
	var a: Vector2 = Vector2(before.x, before.y - reach)
	var b: Vector2 = Vector2(pos.x, pos.y - reach)
	var seg_a: Vector2 = Vector2(minf(before.x, pos.x), pos.y - reach)
	var seg_b: Vector2 = Vector2(maxf(before.x, pos.x), pos.y + reach)
	var center: Vector2 = (seg_a + seg_b) * 0.5
	var size: Vector2 = Vector2(maxf(seg_b.x - seg_a.x, grid.spacing * 0.8), seg_b.y - seg_a.y)
	if a == b:
		center = pos
	for idx: int in grid.cells_in_rect(center, size, 0.0):
		if sheet.state[idx] != SheetModel.STATE_POPPED:
			out.append(idx)
	return out
