class_name PopAudioLogic
extends RefCounted
## Lógica pura del audio de reventones (sin nodos): elección de categoría y
## muestra, pool de voces con robo de la más vieja, tono por racha y cambio
## a crepitar masivo (DESIGN.md 6).

const CATEGORY_SMALL: String = "small"
const CATEGORY_LARGE: String = "large"
const CATEGORY_TENSE: String = "tense"
const CATEGORY_SQUISH: String = "squish"
const CATEGORY_CRINKLE: String = "crinkle"
const CATEGORIES: PackedStringArray = ["small", "large", "tense", "squish", "crinkle"]

## categoría -> Array[String] con las rutas de las muestras.
var categories: Dictionary = {}

var max_voices: int = 24
var pitch_variation: float = 0.08
var streak_reset_seconds: float = 0.6
var streak_pitch_per_pop: float = 0.025
var streak_pitch_max: float = 0.6
var crackle_threshold: int = 30
var crackle_rate_for_full_volume: float = 800.0
var crackle_smoothing_per_second: float = 5.0
var large_chance: float = 0.25
var tense_pressure: float = 1.5

var streak: int = 0

var _last_pop_time: float = -1000.0
var _voice_start: PackedFloat64Array = PackedFloat64Array()
var _voice_busy: PackedByteArray = PackedByteArray()
var _crackle_rate: float = 0.0


func _init(p_max_voices: int = 24) -> void:
	set_max_voices(p_max_voices)


func configure(cfg: Dictionary) -> void:
	set_max_voices(Cfg.integer(cfg, "voices"))
	pitch_variation = Cfg.num(cfg, "pitch_variation")
	streak_reset_seconds = Cfg.num(cfg, "streak_reset_seconds")
	streak_pitch_per_pop = Cfg.num(cfg, "streak_pitch_per_pop")
	streak_pitch_max = Cfg.num(cfg, "streak_pitch_max")
	crackle_threshold = Cfg.integer(cfg, "crackle_threshold")
	crackle_rate_for_full_volume = Cfg.num(cfg, "crackle_rate_for_full_volume")
	crackle_smoothing_per_second = Cfg.num(cfg, "crackle_smoothing_per_second")
	large_chance = Cfg.num(cfg, "large_chance")
	tense_pressure = Cfg.num(cfg, "tense_pressure")


func set_max_voices(n: int) -> void:
	max_voices = maxi(1, n)
	_voice_start = PackedFloat64Array()
	_voice_start.resize(max_voices)
	_voice_busy = PackedByteArray()
	_voice_busy.resize(max_voices)


# --- Muestras ---------------------------------------------------------------------

func set_samples(category: String, paths: Array[String]) -> void:
	categories[category] = paths


func has_samples(category: String) -> bool:
	if not categories.has(category):
		return false
	var list: Array = categories[category]
	return not list.is_empty()


## Categoría de un pop según su presión. Tensa si p >= tense_pressure; si no,
## "large" con probabilidad large_chance; si falta la categoría, cae a "small".
func pick_category(pressure: float, rng: RandomNumberGenerator) -> String:
	var wanted: String = CATEGORY_SMALL
	if pressure >= tense_pressure:
		wanted = CATEGORY_TENSE
	elif rng.randf() < large_chance:
		wanted = CATEGORY_LARGE
	if has_samples(wanted):
		return wanted
	return CATEGORY_SMALL


## Elige una muestra al azar de la categoría. "" si no hay ninguna.
func pick_sample(category: String, rng: RandomNumberGenerator) -> String:
	if not has_samples(category):
		return ""
	var list: Array = categories[category]
	return str(list[rng.randi() % list.size()])


# --- Voces ------------------------------------------------------------------------

## Devuelve el índice de una voz libre; si no hay, roba la más vieja.
func acquire_voice(now: float) -> int:
	var oldest: int = 0
	for i: int in max_voices:
		if _voice_busy[i] == 0:
			_take(i, now)
			return i
		if _voice_start[i] < _voice_start[oldest]:
			oldest = i
	_take(oldest, now)
	return oldest


func release_voice(i: int) -> void:
	_voice_busy[i] = 0


func active_voices() -> int:
	var n: int = 0
	for b: int in _voice_busy:
		n += b
	return n


func _take(i: int, now: float) -> void:
	_voice_busy[i] = 1
	_voice_start[i] = now


# --- Tono y racha -------------------------------------------------------------------

## Suma `count` reventones a la racha; si pasó mucho desde el último, la reinicia antes.
func register_pops(count: int, now: float) -> void:
	if count <= 0:
		return
	if now - _last_pop_time > streak_reset_seconds:
		streak = 0
	streak += count
	_last_pop_time = now


## Reinicia la racha si pasó el tiempo sin reventar (llamar cada frame).
func update_streak(now: float) -> void:
	if streak > 0 and now - _last_pop_time > streak_reset_seconds:
		streak = 0


func streak_pitch() -> float:
	return 1.0 + minf(float(streak) * streak_pitch_per_pop, streak_pitch_max)


## Tono final: racha * variación aleatoria de ± pitch_variation.
func pop_pitch(rng: RandomNumberGenerator) -> float:
	return streak_pitch() * (1.0 + rng.randf_range(-pitch_variation, pitch_variation))


# --- Crepitar masivo ----------------------------------------------------------------

## true si hay tantos reventones en un frame que conviene crepitar en vez de voces sueltas.
func should_crackle(pops_in_frame: int) -> bool:
	return pops_in_frame > crackle_threshold


## Actualiza la tasa suavizada de reventones/segundo y devuelve el volumen lineal (0..1).
func update_crackle(pops_in_frame: int, delta: float) -> float:
	if delta <= 0.0:
		return crackle_volume()
	var instant: float = float(pops_in_frame) / delta
	var k: float = 1.0 - exp(-crackle_smoothing_per_second * delta)
	if instant > _crackle_rate:
		_crackle_rate = instant if pops_in_frame > crackle_threshold else lerpf(_crackle_rate, instant, k)
	else:
		_crackle_rate = lerpf(_crackle_rate, instant, k)
	return crackle_volume()


func crackle_volume() -> float:
	return clampf(_crackle_rate / crackle_rate_for_full_volume, 0.0, 1.0)
