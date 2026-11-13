class_name ComboTracker
extends RefCounted
## Combo = ritmo de reventones en una ventana deslizante. Premia el ritmo sostenido:
## el multiplicador sube por escalones y deja de subir pasado el último.

var window_seconds: float = 2.0
var rates: Array = [0.0, 2.0, 4.0, 6.0, 8.0]
var multipliers: Array = [1.0, 1.5, 2.0, 3.0, 5.0]

var _times: PackedFloat64Array = PackedFloat64Array()
var _hits: PackedFloat32Array = PackedFloat32Array()
var _head: int = 0


func configure(cfg: Dictionary) -> void:
	window_seconds = Cfg.num(cfg, "combo_window_seconds")
	var r: Array = cfg["combo_rates"]
	var m: Array = cfg["combo_multipliers"]
	rates = r
	multipliers = m


func reset() -> void:
	_times = PackedFloat64Array()
	_hits = PackedFloat32Array()
	_head = 0


## Registra `hits` golpes (una acción de herramienta cuenta 1 + 0,25 por burbuja extra).
func add(hits: float, now: float) -> void:
	_times.append(now)
	_hits.append(hits)


## Golpes por segundo dentro de la ventana.
func rate(now: float) -> float:
	_trim(now)
	var total: float = 0.0
	for i: int in range(_head, _times.size()):
		total += _hits[i]
	return total / window_seconds


func multiplier(now: float) -> float:
	return Economy.combo_multiplier(rate(now), rates, multipliers)


func _trim(now: float) -> void:
	while _head < _times.size() and _times[_head] < now - window_seconds:
		_head += 1
	if _head > 256 and _head * 2 > _times.size():
		_times = _times.slice(_head)
		_hits = _hits.slice(_head)
		_head = 0
