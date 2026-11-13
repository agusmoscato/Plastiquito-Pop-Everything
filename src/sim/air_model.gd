class_name AirModel
extends RefCounted
## Reparto de aire entre vecinas (DESIGN 3.2). El aire repartido nunca supera lo que sale
## de la fuente: lo que excede max_pressure se pierde, así que el total no puede crecer.


## Reparte `amount` entre las vecinas sin reventar de `from_idx`, saltando las de `exclude`.
## Con `bias` > 0 y `dir` != 0 las vecinas en la dirección de `dir` reciben más (palo de amasar).
## Devuelve cuánto salió de la fuente (`amount`, o 0 si no había a quién dárselo).
static func spread(sheet: SheetModel, grid: HexGrid, from_idx: int, amount: float,
		dir: Vector2, bias: float, exclude: Dictionary, changed: PackedInt32Array) -> float:
	if amount <= 0.0:
		return 0.0
	var targets: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var origin: Vector2 = grid.cell_to_world(from_idx)
	var unit: Vector2 = dir.normalized() if dir.length_squared() > 0.0 else Vector2.ZERO
	var total_w: float = 0.0
	for n: int in grid.neighbors(from_idx):
		if sheet.state[n] == SheetModel.STATE_POPPED or exclude.has(n):
			continue
		var w: float = 1.0
		if bias > 0.0 and unit != Vector2.ZERO:
			var to_n: Vector2 = (grid.cell_to_world(n) - origin).normalized()
			w += bias * maxf(0.0, unit.dot(to_n))
		targets.append(n)
		weights.append(w)
		total_w += w
	if targets.is_empty():
		return 0.0
	for i: int in targets.size():
		sheet.add_pressure_quiet(targets[i], amount * weights[i] / total_w)
		changed.append(targets[i])
	return amount
