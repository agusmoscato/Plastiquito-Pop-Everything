class_name HandsModel
extends RefCounted
## Manitos: dedos fantasma que tocan solos. Cada una toca `rate` veces por segundo una burbuja
## sin reventar elegida al azar (las inteligentes prefieren tensas y especiales: bloqueado hasta la
## Fase 6). Nunca tocan reventadas. Lógica pura.

var sheet: SheetModel
var grid: HexGrid
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var count: int = 0
var rate: float = 0.5 ## toques por segundo por manito
var smart: bool = false

## Último objetivo de cada manito (para dibujarlas tocando en el mundo).
var targets: PackedInt32Array = PackedInt32Array()

var _accum: float = 0.0
var _next_hand: int = 0


func _init(p_sheet: SheetModel, p_grid: HexGrid, seed_value: int = 1) -> void:
	sheet = p_sheet
	grid = p_grid
	rng.seed = seed_value


func set_count(n: int) -> void:
	count = maxi(0, n)
	if targets.size() != count:
		targets.resize(count)
		targets.fill(-1)


## Avanza `dt` segundos. Devuelve las celdas que las manitos revientan en este paso.
func step(dt: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if count <= 0 or rate <= 0.0:
		return out
	_accum += float(count) * rate * dt
	while _accum >= 1.0:
		_accum -= 1.0
		var idx: int = _pick()
		if idx < 0:
			_accum = 0.0
			break
		if not out.has(idx):
			out.append(idx)
		targets[_next_hand % count] = idx
		_next_hand += 1
	return out


func _pick() -> int:
	var best: int = -1
	var best_score: float = -1.0
	var tries: int = 14 if smart else 10
	for i: int in tries:
		var idx: int = rng.randi() % sheet.cell_count()
		var st: int = sheet.state[idx]
		if st == SheetModel.STATE_POPPED:
			continue
		if not smart:
			return idx
		var score: float = 1.0 + (3.0 if st == SheetModel.STATE_TENSE else 0.0) + (5.0 if sheet.type[idx] != 0 else 0.0)
		if score > best_score:
			best_score = score
			best = idx
	return best
