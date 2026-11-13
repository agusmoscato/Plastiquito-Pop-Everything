class_name SheetModel
extends RefCounted
## Estado de la lámina (DESIGN.md 3.1): presión, estado y tipo por burbuja.
## Lógica pura: sin nodos ni acceso a la pantalla.
## TODO(fase 2): aire y cadenas (DESIGN.md 3.2) van en ChainSolver, no acá.

signal cells_changed(indices: PackedInt32Array) ## índices que cambiaron
signal reload_requested ## popped_ratio() llegó al umbral: hay que pedir una lámina nueva

const SAVE_VERSION: int = 1

const STATE_INTACT: int = 0
const STATE_TENSE: int = 1
const STATE_POPPED: int = 2

const TYPE_NORMAL: int = 0

const INITIAL_PRESSURE: float = 1.0

var width: int = 0
var height: int = 0
var pressure: PackedFloat32Array = PackedFloat32Array()
var state: PackedByteArray = PackedByteArray()
var type: PackedByteArray = PackedByteArray()
## Aplastamiento acumulado por burbuja (0 .. resistencia).
var press: PackedFloat32Array = PackedFloat32Array()
## Fracción reventada a partir de la cual se pide lámina nueva (DESIGN 2).
var reload_threshold: float = 0.9

## Motivo del último from_dict() fallido ("" si fue bien).
var last_error: String = ""

var _state_counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _reload_signaled: bool = false


func _init(p_width: int = 0, p_height: int = 0) -> void:
	if p_width > 0 and p_height > 0:
		reset(p_width, p_height)


func reset(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	var n: int = width * height
	pressure = PackedFloat32Array()
	pressure.resize(n)
	pressure.fill(INITIAL_PRESSURE)
	state = PackedByteArray()
	state.resize(n)
	state.fill(STATE_INTACT)
	type = PackedByteArray()
	type.resize(n)
	type.fill(TYPE_NORMAL)
	press = PackedFloat32Array()
	press.resize(n)
	press.fill(0.0)
	_state_counts = PackedInt32Array([n, 0, 0])
	_reload_signaled = false


func cell_count() -> int:
	return width * height


# --- Acceso por campo ------------------------------------------------------------

func get_pressure(idx: int) -> float:
	return pressure[idx]


func set_pressure(idx: int, value: float) -> void:
	pressure[idx] = value
	cells_changed.emit(PackedInt32Array([idx]))


func get_press(idx: int) -> float:
	return press[idx]


func get_state(idx: int) -> int:
	return state[idx]


func set_state(idx: int, value: int) -> void:
	_write_state(idx, value)
	cells_changed.emit(PackedInt32Array([idx]))


func get_type(idx: int) -> int:
	return type[idx]


func set_type(idx: int, value: int) -> void:
	type[idx] = value
	cells_changed.emit(PackedInt32Array([idx]))


func _write_state(idx: int, value: int) -> void:
	_state_counts[state[idx]] -= 1
	state[idx] = value
	_state_counts[value] += 1


# --- Operaciones -------------------------------------------------------------------

## Revienta la burbuja. Devuelve false si ya estaba reventada.
func pop(idx: int) -> bool:
	if state[idx] == STATE_POPPED:
		return false
	_write_state(idx, STATE_POPPED)
	cells_changed.emit(PackedInt32Array([idx]))
	_check_reload()
	return true


## Revienta varias burbujas y avisa una sola vez. Devuelve cuántas reventó.
func pop_many(indices: PackedInt32Array) -> int:
	var changed: PackedInt32Array = PackedInt32Array()
	for idx: int in indices:
		if state[idx] != STATE_POPPED:
			_write_state(idx, STATE_POPPED)
			changed.append(idx)
	if not changed.is_empty():
		cells_changed.emit(changed)
		_check_reload()
	return changed.size()


## Avisa que cambiaron estas celdas (para escrituras directas a los arrays).
func notify_changed(indices: PackedInt32Array) -> void:
	if not indices.is_empty():
		cells_changed.emit(indices)


func _check_reload() -> void:
	if _reload_signaled or popped_ratio() < reload_threshold:
		return
	_reload_signaled = true
	reload_requested.emit()


## Burbujas en estado intacto (0). Las tensas no cuentan.
func count_intact() -> int:
	return _state_counts[STATE_INTACT]


func count_tense() -> int:
	return _state_counts[STATE_TENSE]


func count_popped() -> int:
	return _state_counts[STATE_POPPED]


func popped_ratio() -> float:
	var n: int = cell_count()
	if n == 0:
		return 0.0
	return float(_state_counts[STATE_POPPED]) / float(n)


# --- Guardado ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"width": width,
		"height": height,
		"pressure": Marshalls.raw_to_base64(pressure.to_byte_array()),
		"state": Marshalls.raw_to_base64(state),
		"type": Marshalls.raw_to_base64(type),
		"press": Marshalls.raw_to_base64(press.to_byte_array()),
	}


## Carga desde un diccionario de to_dict(). Devuelve false (sin tocar el estado) si es inválido.
func from_dict(data: Dictionary) -> bool:
	last_error = ""
	for key: String in ["version", "width", "height", "pressure", "state", "type", "press"]:
		if not data.has(key):
			return _fail("falta el campo '%s'" % key)
	var version: int = int(data["version"])
	if version != SAVE_VERSION:
		return _fail("versión no soportada (%d)" % version)
	var w: int = int(data["width"])
	var h: int = int(data["height"])
	var n: int = w * h
	var p_text: String = str(data["pressure"])
	var s_text: String = str(data["state"])
	var t_text: String = str(data["type"])
	var press_text: String = str(data["press"])
	var new_pressure: PackedFloat32Array = Marshalls.base64_to_raw(p_text).to_float32_array()
	var new_state: PackedByteArray = Marshalls.base64_to_raw(s_text)
	var new_type: PackedByteArray = Marshalls.base64_to_raw(t_text)
	var new_press: PackedFloat32Array = Marshalls.base64_to_raw(press_text).to_float32_array()
	if new_pressure.size() != n or new_state.size() != n or new_type.size() != n or new_press.size() != n:
		return _fail("tamaño de arrays inconsistente")
	width = w
	height = h
	pressure = new_pressure
	state = new_state
	type = new_type
	press = new_press
	_recount()
	_reload_signaled = popped_ratio() >= reload_threshold
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false


func _recount() -> void:
	_state_counts = PackedInt32Array([0, 0, 0])
	for s: int in state:
		_state_counts[s] += 1
