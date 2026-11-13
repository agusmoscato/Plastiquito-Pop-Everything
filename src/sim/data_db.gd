class_name DataDB
extends RefCounted
## Carga y valida los JSON de data/. Los errores se acumulan en `errors`
## con el archivo, la entrada y el campo que fallan.

const PHASES_FILE: String = "phases.json"
const TOOLS_FILE: String = "tools.json"
const BUBBLES_FILE: String = "bubbles.json"
const SHEET_FILE: String = "sheet.json"
const JUICE_FILE: String = "juice.json"
const AUDIO_FILE: String = "audio.json"
const UPGRADES_FILE: String = "upgrades.json"
const ECONOMY_FILE: String = "economy.json"

## Campos requeridos y su tipo (TYPE_*) por archivo.
const PHASE_FIELDS: Dictionary = {
	"id": TYPE_STRING, "number": TYPE_INT, "name_es": TYPE_STRING, "name_en": TYPE_STRING,
	"start_minute": TYPE_INT, "sheet_start": TYPE_DICTIONARY, "sheet_end": TYPE_DICTIONARY,
}
const SIZE_FIELDS: Dictionary = {"width": TYPE_INT, "height": TYPE_INT}
const TOOL_FIELDS: Dictionary = {
	"id": TYPE_STRING, "number": TYPE_INT, "name_es": TYPE_STRING, "name_en": TYPE_STRING,
	"shape": TYPE_STRING, "unlock_phase": TYPE_INT, "balance": TYPE_DICTIONARY,
}
const BUBBLE_FIELDS: Dictionary = {
	"id": TYPE_STRING, "type_id": TYPE_INT, "name_es": TYPE_STRING, "name_en": TYPE_STRING,
	"shape": TYPE_STRING, "unlock_phase": TYPE_INT, "balance": TYPE_DICTIONARY,
}
const SHEET_FIELDS: Dictionary = {
	"default_width": TYPE_INT, "default_height": TYPE_INT, "bubble_radius": TYPE_FLOAT,
	"resistance": TYPE_FLOAT, "recovery_per_second": TYPE_FLOAT,
	"reload_threshold": TYPE_FLOAT, "reload_delay_seconds": TYPE_FLOAT,
	"tense_threshold": TYPE_FLOAT, "max_pressure": TYPE_FLOAT, "min_pressure": TYPE_FLOAT,
	"chain_k": TYPE_FLOAT, "chain_k_max": TYPE_FLOAT, "chain_budget_per_frame": TYPE_INT,
}
const JUICE_FIELDS: Dictionary = {
	"hitstop_ms": TYPE_INT, "hitstop_every_streak": TYPE_INT, "mass_pop_radius": TYPE_FLOAT,
	"shake_per_pop": TYPE_FLOAT, "shake_max_trauma": TYPE_FLOAT, "shake_decay_per_second": TYPE_FLOAT,
	"shake_max_offset": TYPE_FLOAT, "shake_max_angle_degrees": TYPE_FLOAT, "shake_noise_speed": TYPE_FLOAT,
	"particle_pool_size": TYPE_INT, "shards_per_pop": TYPE_INT, "dust_per_pop": TYPE_INT,
	"max_fx_per_frame": TYPE_INT, "pop_anim_inflate_ms": TYPE_INT, "pop_anim_collapse_ms": TYPE_INT,
	"pop_anim_inflate_amount": TYPE_FLOAT, "popped_height": TYPE_FLOAT, "roll_in_seconds": TYPE_FLOAT,
	"finger_hover_height": TYPE_FLOAT, "finger_press_depth": TYPE_FLOAT,
	"finger_spring_stiffness": TYPE_FLOAT, "finger_spring_damping": TYPE_FLOAT,
	"finger_bounce_impulse": TYPE_FLOAT,
}
const AUDIO_FIELDS: Dictionary = {
	"voices": TYPE_INT, "pitch_variation": TYPE_FLOAT, "streak_reset_seconds": TYPE_FLOAT,
	"streak_pitch_per_pop": TYPE_FLOAT, "streak_pitch_max": TYPE_FLOAT, "crackle_threshold": TYPE_INT,
	"crackle_rate_for_full_volume": TYPE_FLOAT, "crackle_smoothing_per_second": TYPE_FLOAT,
	"crackle_min_volume_db": TYPE_FLOAT, "large_chance": TYPE_FLOAT, "tense_pressure": TYPE_FLOAT,
	"max_voices_per_frame": TYPE_INT, "squish_volume_db": TYPE_FLOAT, "pop_volume_db": TYPE_FLOAT,
}
const UPGRADE_FIELDS: Dictionary = {
	"id": TYPE_STRING, "scope": TYPE_STRING, "tool": TYPE_STRING, "kind": TYPE_STRING,
	"name_es": TYPE_STRING, "name_en": TYPE_STRING, "desc_es": TYPE_STRING, "desc_en": TYPE_STRING,
	"base_cost": TYPE_FLOAT, "growth": TYPE_FLOAT, "max_level": TYPE_INT, "per_level": TYPE_FLOAT,
	"effect_type": TYPE_STRING, "unit": TYPE_STRING, "requires": TYPE_DICTIONARY,
}
const ECONOMY_FIELDS: Dictionary = {
	"phase_base_values": TYPE_ARRAY, "phase_sheet_sizes": TYPE_ARRAY, "sheet_start_size": TYPE_INT,
	"milestone_every": TYPE_INT, "milestone_multiplier": TYPE_FLOAT, "combo_window_seconds": TYPE_FLOAT,
	"combo_rates": TYPE_ARRAY, "combo_multipliers": TYPE_ARRAY, "golden_multiplier": TYPE_FLOAT,
	"chance_golden": TYPE_FLOAT, "chance_bomb": TYPE_FLOAT, "chance_line": TYPE_FLOAT,
	"pellet_divisor": TYPE_FLOAT, "pellet_exponent": TYPE_FLOAT, "autosave_seconds": TYPE_FLOAT,
	"reload_delay_manual": TYPE_FLOAT, "reload_delay_auto": TYPE_FLOAT, "chain_stamp_min": TYPE_INT,
}
const TOOL_SHAPES: PackedStringArray = ["cell", "circle", "segment", "rect"]

var phases: Array[Dictionary] = []
var tools: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var sheet: Dictionary = {}
var juice: Dictionary = {}
var audio: Dictionary = {}
var upgrades: Array[Dictionary] = []
var economy: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


## Carga los tres JSON desde `dir`. Devuelve true si no hubo ningún error.
func load_all(dir: String = "res://data") -> bool:
	errors = PackedStringArray()
	phases = _load_list(dir.path_join(PHASES_FILE), "phases", PHASE_FIELDS)
	tools = _load_list(dir.path_join(TOOLS_FILE), "tools", TOOL_FIELDS)
	bubbles = _load_list(dir.path_join(BUBBLES_FILE), "bubbles", BUBBLE_FIELDS)
	sheet = _load_section(dir.path_join(SHEET_FILE), "sheet", SHEET_FIELDS)
	juice = _load_section(dir.path_join(JUICE_FILE), "juice", JUICE_FIELDS)
	audio = _load_section(dir.path_join(AUDIO_FILE), "audio", AUDIO_FIELDS)
	upgrades = _load_list(dir.path_join(UPGRADES_FILE), "upgrades", UPGRADE_FIELDS)
	economy = _load_section(dir.path_join(ECONOMY_FILE), "economy", ECONOMY_FIELDS)
	_validate_phases()
	_validate_tools()
	_validate_bubbles()
	return errors.is_empty()


func get_phase(id: String) -> Dictionary:
	return _find(phases, id)


func get_tool(id: String) -> Dictionary:
	return _find(tools, id)


func get_upgrade(id: String) -> Dictionary:
	return _find(upgrades, id)


func get_bubble(id: String) -> Dictionary:
	return _find(bubbles, id)


func _find(list: Array[Dictionary], id: String) -> Dictionary:
	for entry: Dictionary in list:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


## Carga un objeto único (no lista) y valida sus campos. Devuelve {} si hay errores.
func _load_section(path: String, key: String, fields: Dictionary) -> Dictionary:
	var root: Variant = _read_json(path)
	if not (root is Dictionary):
		return {}
	var root_dict: Dictionary = root
	if not root_dict.has(key) or not (root_dict[key] is Dictionary):
		errors.append("%s: falta el objeto '%s'" % [path.get_file(), key])
		return {}
	var section: Dictionary = root_dict[key]
	if not _check_fields(section, fields, "%s[%s]" % [path.get_file(), key]):
		return {}
	return section


func _load_list(path: String, key: String, fields: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var root: Variant = _read_json(path)
	if not (root is Dictionary):
		return out
	var root_dict: Dictionary = root
	if not root_dict.has(key) or not (root_dict[key] is Array):
		errors.append("%s: falta la lista '%s'" % [path.get_file(), key])
		return out
	var items: Array = root_dict[key]
	for i: int in items.size():
		var item: Variant = items[i]
		if not (item is Dictionary):
			errors.append("%s: la entrada %d no es un objeto" % [path.get_file(), i])
			continue
		var entry: Dictionary = item
		var label: String = "%s[%d:%s]" % [path.get_file(), i, str(entry.get("id", "?"))]
		if _check_fields(entry, fields, label):
			out.append(entry)
	return out


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: el archivo no existe (%s)" % [path.get_file(), path])
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: JSON inválido en la línea %d: %s" % [path.get_file(), json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Chequea que estén todos los campos con el tipo correcto. Devuelve true si está todo bien.
func _check_fields(entry: Dictionary, fields: Dictionary, label: String) -> bool:
	var ok: bool = true
	for field: String in fields:
		if not entry.has(field):
			errors.append("%s: falta el campo '%s'" % [label, field])
			ok = false
			continue
		var expected: int = fields[field]
		if not _type_matches(typeof(entry[field]), expected):
			errors.append("%s: el campo '%s' tiene un tipo incorrecto" % [label, field])
			ok = false
	return ok


func _type_matches(actual: int, expected: int) -> bool:
	if expected == TYPE_INT or expected == TYPE_FLOAT:
		return actual == TYPE_INT or actual == TYPE_FLOAT # JSON numera todo como float
	return actual == expected


func _validate_phases() -> void:
	for p: Dictionary in phases:
		var label: String = "phases.json[%s]" % str(p["id"])
		var start: Dictionary = p["sheet_start"]
		var end: Dictionary = p["sheet_end"]
		_check_fields(start, SIZE_FIELDS, label + ".sheet_start")
		_check_fields(end, SIZE_FIELDS, label + ".sheet_end")


func _validate_tools() -> void:
	for t: Dictionary in tools:
		if not TOOL_SHAPES.has(str(t["shape"])):
			errors.append("tools.json[%s]: forma desconocida '%s'" % [str(t["id"]), str(t["shape"])])
		_check_unlock(t, "tools.json")


func _validate_bubbles() -> void:
	for b: Dictionary in bubbles:
		_check_unlock(b, "bubbles.json")


func _check_unlock(entry: Dictionary, file: String) -> void:
	var phase_number: int = Cfg.integer(entry, "unlock_phase")
	for p: Dictionary in phases:
		if Cfg.integer(p, "number") == phase_number:
			return
	errors.append("%s[%s]: unlock_phase %d no existe en phases.json" % [file, str(entry["id"]), phase_number])
