extends Node
## Ajustes del jugador, guardados en user://settings.cfg.

signal volume_changed(bus: String, value: float)
signal graphics_changed

const PATH: String = "user://settings.cfg"
const BUSES: PackedStringArray = ["Master", "Pops", "Tools", "UI", "Music"]

## Volumen lineal (0..1) por bus.
var volumes: Dictionary = {"Master": 0.8, "Pops": 1.0, "Tools": 1.0, "UI": 1.0, "Music": 0.0}
var shake_enabled: bool = true
var reduce_motion: bool = false
var language: String = "es" ## "es" o "en"
var discovery_done: bool = false ## ya compró algo: nunca más se señala la tienda
var graphics: int = 2 ## calidad de gráficos: 0 bajo, 1 medio, 2 alto (GraphicsQuality)
var introduced: Dictionary = {} ## lo que ya se presentó con tarjeta (SpecialCard): "1".."4", "-1" veta, "-2" doble film


func _ready() -> void:
	load_settings()
	apply_audio()


func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)
	volume_changed.emit(bus, get_volume(bus))


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
	cfg.set_value("video", "graphics", graphics)
	cfg.set_value("ui", "language", language)
	cfg.set_value("ui", "discovery_done", discovery_done)
	cfg.set_value("ui", "introduced", introduced.keys())
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
	var g: int = cfg.get_value("video", "graphics", graphics)
	graphics = clampi(g, 0, 2)
	language = cfg.get_value("ui", "language", language)
	discovery_done = cfg.get_value("ui", "discovery_done", discovery_done)
	var intro: Array = cfg.get_value("ui", "introduced", [])
	introduced = {}
	for k: Variant in intro:
		introduced[str(k)] = true
