extends Node
## Ajustes del jugador, guardados en user://settings.cfg.

const PATH: String = "user://settings.cfg"
const BUSES: PackedStringArray = ["Master", "Pops", "Tools", "UI", "Music"]

## Volumen lineal (0..1) por bus.
var volumes: Dictionary = {"Master": 0.8, "Pops": 1.0, "Tools": 1.0, "UI": 1.0, "Music": 0.0}
var shake_enabled: bool = true
var reduce_motion: bool = false


func _ready() -> void:
	load_settings()
	apply_audio()


func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)


func get_volume(bus: String) -> float:
	var v: float = volumes.get(bus, 1.0)
	return v


func apply_audio() -> void:
	for bus: String in BUSES:
		_apply_bus(bus)


func _apply_bus(bus: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var lin: float = get_volume(bus)
	AudioServer.set_bus_mute(idx, lin <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))


## Sacudida efectiva: apagada si el jugador la apagó o pidió reducir el movimiento.
func shake_allowed() -> bool:
	return shake_enabled and not reduce_motion


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus: String in BUSES:
		cfg.set_value("audio", bus, get_volume(bus))
	cfg.set_value("video", "shake_enabled", shake_enabled)
	cfg.set_value("video", "reduce_motion", reduce_motion)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus: String in BUSES:
		var v: float = cfg.get_value("audio", bus, get_volume(bus))
		volumes[bus] = clampf(v, 0.0, 1.0)
	shake_enabled = cfg.get_value("video", "shake_enabled", shake_enabled)
	reduce_motion = cfg.get_value("video", "reduce_motion", reduce_motion)
