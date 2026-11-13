extends Node
## Autoload de audio de reventones. Reparte los sonidos según PopAudioLogic:
## pool de voces, tono por racha y crepitar masivo.
## Las muestras se cargan por carpeta (assets/audio/pops/<categoría>/): alcanza con
## copiar los .ogg/.wav ahí, sin listas en el código.

const POPS_DIR: String = "res://assets/audio/pops"
const LOOPS_DIR: String = "res://assets/audio/loops"
const EXTENSIONS: PackedStringArray = ["ogg", "wav"]

var logic: PopAudioLogic = PopAudioLogic.new()

var _cfg: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {} ## ruta -> AudioStream
var _crackle: AudioStreamPlayer
var _ui_streams: Dictionary = {} ## nombre -> AudioStream (assets/audio/ui)
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next: int = 0
var _ambient_streams: Dictionary = {} ## fase -> AudioStream (assets/audio/ambient)
var _ambient_players: Array[AudioStreamPlayer] = []
var _ambient_active: int = 0
var _ambient_phase: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var db: DataDB = DataDB.new()
	if not db.load_all():
		push_error("PopAudio: data inválida: %s" % "; ".join(db.errors))
		return
	_cfg = db.audio
	logic.configure(_cfg)
	_load_categories()
	_build_voices()
	_build_crackle()
	_load_ui()


func active_voices() -> int:
	return logic.active_voices()


func streak() -> int:
	return logic.streak


## Informa los reventones de este frame (llamar todos los frames, aunque sea 0).
## `max_pressure` es la presión más alta entre las reventadas (decide si suena "tense").
func report_frame(pops: int, max_pressure: float, delta: float) -> void:
	var now: float = _now()
	logic.update_streak(now)
	var volume: float = logic.update_crackle(pops, delta)
	_update_crackle_player(volume)
	if pops <= 0:
		return
	if logic.should_crackle(pops):
		logic.register_pops(pops, now)
		return
	var count: int = mini(pops, Cfg.integer(_cfg, "max_voices_per_frame"))
	for i: int in count:
		logic.register_pops(1, now)
		var category: String = logic.pick_category(max_pressure, _rng)
		_play(category, logic.pop_pitch(_rng), Cfg.num(_cfg, "pop_volume_db") + _rng.randf_range(-2.0, 1.0), "Pops")
	if pops > count:
		logic.register_pops(pops - count, now)


## Sonido de interfaz por nombre ("tic", "stamp", "milestone", "chain_hit", "recycle").
func play_ui(kind: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _ui_streams.get(kind)
	if stream == null or _ui_players.is_empty():
		return
	var p: AudioStreamPlayer = _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Sonido propio de cada especial: misma familia de muestras, tono y volumen distintos.
func play_special(type_id: int) -> void:
	if type_id == 1:
		_play(PopAudioLogic.CATEGORY_TENSE, 1.55, Cfg.num(_cfg, "pop_volume_db") + 3.0, "Pops")
	elif type_id == 2:
		_play(PopAudioLogic.CATEGORY_LARGE, 0.55, Cfg.num(_cfg, "pop_volume_db") + 4.0, "Pops")
	elif type_id == 3:
		_play(PopAudioLogic.CATEGORY_SMALL, 1.3, Cfg.num(_cfg, "pop_volume_db") + 2.0, "Pops")


## Ambiente del escenario de la fase (1..4): pasa de uno al otro con un fundido de 2 s.
func set_ambient(phase: int) -> void:
	if phase == _ambient_phase:
		return
	_ambient_phase = phase
	if _ambient_players.is_empty():
		for i: int in 2:
			var p: AudioStreamPlayer = AudioStreamPlayer.new()
			p.name = "Ambient%d" % i
			p.bus = "Tools" if AudioServer.get_bus_index("Tools") >= 0 else "Master"
			p.volume_db = -80.0
			add_child(p)
			_ambient_players.append(p)
	var stream: AudioStream = _ambient_streams.get(phase)
	if stream == null:
		stream = _load_ambient(phase)
	if stream == null:
		return
	var old: AudioStreamPlayer = _ambient_players[_ambient_active]
	_ambient_active = 1 - _ambient_active
	var nxt: AudioStreamPlayer = _ambient_players[_ambient_active]
	nxt.stream = stream
	nxt.volume_db = -80.0
	nxt.play()
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", -22.0, 2.0)
	tw.tween_property(old, "volume_db", -80.0, 2.0)
	tw.chain().tween_callback(old.stop)


func _load_ambient(phase: int) -> AudioStream:
	for file: String in _list_audio_files("res://assets/audio/ambient"):
		if not file.contains("_%d." % phase):
			continue
		var stream: AudioStream = load("res://assets/audio/ambient".path_join(file)) as AudioStream
		if stream is AudioStreamWAV:
			var wav: AudioStreamWAV = stream
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() >> 1 if wav.format == AudioStreamWAV.FORMAT_16_BITS else wav.data.size()
		_ambient_streams[phase] = stream
		return stream
	return null


func play_squish() -> void:
	_play(PopAudioLogic.CATEGORY_SQUISH, _rng.randf_range(0.92, 1.08), Cfg.num(_cfg, "squish_volume_db"), "Tools")


func play_crinkle() -> void:
	_play(PopAudioLogic.CATEGORY_CRINKLE, _rng.randf_range(0.95, 1.05), -6.0, "Tools")


# --- Internos ------------------------------------------------------------------------

func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _play(category: String, pitch: float, volume_db: float, bus: String) -> void:
	var path: String = logic.pick_sample(category, _rng)
	if path.is_empty() or _voices.is_empty():
		return
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		return
	var idx: int = logic.acquire_voice(_now())
	var player: AudioStreamPlayer = _voices[idx]
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	player.play()


func _on_voice_finished(idx: int) -> void:
	logic.release_voice(idx)


func _build_voices() -> void:
	for i: int in logic.max_voices:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Voice%02d" % i
		p.finished.connect(_on_voice_finished.bind(i))
		add_child(p)
		_voices.append(p)


func _build_crackle() -> void:
	_crackle = AudioStreamPlayer.new()
	_crackle.name = "Crackle"
	_crackle.bus = "Pops" if AudioServer.get_bus_index("Pops") >= 0 else "Master"
	_crackle.volume_db = -80.0
	var stream: AudioStream = _load_loop()
	if stream != null:
		_crackle.stream = stream
	add_child(_crackle)


func _update_crackle_player(volume: float) -> void:
	if _crackle == null or _crackle.stream == null:
		return
	if volume > 0.01:
		var db: float = clampf(linear_to_db(volume), Cfg.num(_cfg, "crackle_min_volume_db"), 0.0)
		_crackle.volume_db = db
		if not _crackle.playing:
			_crackle.play()
	elif _crackle.playing:
		_crackle.stop()


## Carga todos los .ogg/.wav de cada carpeta de categoría.
func _load_categories() -> void:
	for category: String in PopAudioLogic.CATEGORIES:
		var paths: Array[String] = []
		for file: String in _list_audio_files(POPS_DIR.path_join(category)):
			var path: String = POPS_DIR.path_join(category).path_join(file)
			var stream: AudioStream = load(path) as AudioStream
			if stream != null:
				_streams[path] = stream
				paths.append(path)
		logic.set_samples(category, paths)


func _load_ui() -> void:
	for i: int in 4:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "UiVoice%d" % i
		p.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
		add_child(p)
		_ui_players.append(p)
	for file: String in _list_audio_files("res://assets/audio/ui"):
		var stream: AudioStream = load("res://assets/audio/ui".path_join(file)) as AudioStream
		if stream != null:
			var key: String = file.get_basename().trim_prefix("ph_")
			_ui_streams[key] = stream


func _load_loop() -> AudioStream:
	for file: String in _list_audio_files(LOOPS_DIR):
		if not file.contains("crackle"):
			continue
		var stream: AudioStream = load(LOOPS_DIR.path_join(file)) as AudioStream
		if stream is AudioStreamWAV:
			var wav: AudioStreamWAV = stream
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = wav.data.size() >> 1 if wav.format == AudioStreamWAV.FORMAT_16_BITS else wav.data.size()
		elif stream is AudioStreamOggVorbis:
			var ogg: AudioStreamOggVorbis = stream
			ogg.loop = true
		return stream
	return null


## Nombres de archivo de audio de una carpeta; en exports los recursos aparecen como "x.wav.import".
func _list_audio_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir):
		var name: String = file.trim_suffix(".import")
		if EXTENSIONS.has(name.get_extension().to_lower()) and not out.has(name):
			out.append(name)
	out.sort()
	return out
