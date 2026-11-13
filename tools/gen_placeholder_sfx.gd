extends SceneTree
## Genera sonidos PROVISORIOS (prefijo ph_) para probar el audio sin grabaciones reales.
## Uso: godot --headless -s tools/gen_placeholder_sfx.gd
## Escribe .wav en assets/audio/pops/{small,large,tense,squish,crinkle}/ y un loop de crepitar
## en assets/audio/loops/. Las grabaciones reales reemplazan a estos archivos (se cargan por carpeta).

const RATE: int = 44100
const VARIANTS: int = 10
const OUT_POPS: String = "res://assets/audio/pops"
const OUT_LOOPS: String = "res://assets/audio/loops"
const OUT_UI: String = "res://assets/audio/ui"
const OUT_AMBIENT: String = "res://assets/audio/ambient"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261113
	for category: String in ["small", "large", "tense", "squish", "crinkle"]:
		DirAccess.make_dir_recursive_absolute(OUT_POPS.path_join(category))
		for i: int in VARIANTS:
			var samples: PackedFloat32Array = _make(category)
			_save(samples, OUT_POPS.path_join(category).path_join("ph_%s_%02d.wav" % [category, i]))
	DirAccess.make_dir_recursive_absolute(OUT_LOOPS)
	_save(_make_crackle_loop(), OUT_LOOPS.path_join("ph_crackle_loop.wav"))
	DirAccess.make_dir_recursive_absolute(OUT_UI)
	_save(_tic(), OUT_UI.path_join("ph_tic.wav"))
	_save(_stamp(), OUT_UI.path_join("ph_stamp.wav"))
	_save(_milestone(), OUT_UI.path_join("ph_milestone.wav"))
	_save(_chain_hit(), OUT_UI.path_join("ph_chain_hit.wav"))
	_save(_whoosh(), OUT_UI.path_join("ph_recycle.wav"))
	DirAccess.make_dir_recursive_absolute(OUT_AMBIENT)
	for phase: int in range(1, 5):
		_save(_ambient(phase), OUT_AMBIENT.path_join("ph_ambient_%d.wav" % phase))
	print("gen_placeholder_sfx: listo")
	quit(0)


func _make(category: String) -> PackedFloat32Array:
	match category:
		"small":
			return _pop(0.13, _rng.randf_range(0.007, 0.012), _rng.randf_range(4500.0, 7500.0), _rng.randf_range(110.0, 170.0), 0.35, 0.02)
		"large":
			return _pop(0.28, _rng.randf_range(0.018, 0.03), _rng.randf_range(2500.0, 4200.0), _rng.randf_range(70.0, 100.0), 0.65, 0.05)
		"tense":
			return _tense()
		"squish":
			return _squish()
		_:
			return _crinkle()


## Golpe corto de ruido filtrado con envolvente rápida + "thump" grave.
func _pop(duration: float, tau: float, cutoff: float, thump_hz: float, thump_amp: float, thump_tau: float) -> PackedFloat32Array:
	var n: int = int(duration * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var hp_lp: float = 0.0
	var a: float = clampf(2.0 * PI * cutoff / float(RATE), 0.0, 1.0)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(RATE)
		var white: float = _rng.randf_range(-1.0, 1.0)
		lp += a * (white - lp)
		hp_lp += 0.08 * (lp - hp_lp) # quita graves del ruido
		var noise: float = (lp - hp_lp) * exp(-t / tau)
		phase += 2.0 * PI * lerpf(thump_hz, thump_hz * 0.5, minf(t / thump_tau, 1.0)) / float(RATE)
		var thump: float = sin(phase) * exp(-t / thump_tau) * thump_amp
		var attack: float = minf(t / 0.0008, 1.0)
		out[i] = (noise * 1.6 + thump) * attack
	return _normalize(out, 0.9)


func _tense() -> PackedFloat32Array:
	var base: PackedFloat32Array = _pop(0.16, _rng.randf_range(0.005, 0.008), _rng.randf_range(7000.0, 10000.0), _rng.randf_range(200.0, 260.0), 0.22, 0.015)
	# Chasquido agudo extra al inicio.
	for i: int in range(0, 90):
		base[i] += _rng.randf_range(-1.0, 1.0) * exp(-float(i) / 25.0) * 0.8
	return _normalize(base, 0.9)


## Aplastar sin reventar: crujido bajito y gradual.
func _squish() -> PackedFloat32Array:
	var n: int = int(_rng.randf_range(0.25, 0.4) * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var lp: float = 0.0
	var a: float = clampf(2.0 * PI * _rng.randf_range(900.0, 1800.0) / float(RATE), 0.0, 1.0)
	for i: int in n:
		var x: float = float(i) / float(n)
		var env: float = sin(PI * x) * (0.4 + 0.6 * x)
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var crackle: float = 1.0 if _rng.randf() < 0.02 else 0.15
		out[i] = lp * env * crackle
	return _normalize(out, 0.5)


## Plástico arrugado: muchos clics mínimos.
func _crinkle() -> PackedFloat32Array:
	var n: int = int(_rng.randf_range(0.4, 0.6) * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var clicks: int = _rng.randi_range(14, 26)
	for c: int in clicks:
		var start: int = _rng.randi_range(0, n - 400)
		var amp: float = _rng.randf_range(0.2, 1.0) * (1.0 - float(start) / float(n) * 0.5)
		var tau: float = _rng.randf_range(40.0, 140.0)
		for i: int in range(0, 400):
			out[start + i] += _rng.randf_range(-1.0, 1.0) * exp(-float(i) / tau) * amp
	return _normalize(out, 0.6)


## Loop de ~2 s de clics muy densos; los clics que pasan el final dan la vuelta (sin costura).
func _make_crackle_loop() -> PackedFloat32Array:
	var n: int = RATE * 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var clicks: int = 1400
	for c: int in clicks:
		var start: int = _rng.randi_range(0, n - 1)
		var amp: float = _rng.randf_range(0.15, 1.0)
		var tau: float = _rng.randf_range(15.0, 90.0)
		for i: int in range(0, 300):
			out[(start + i) % n] += _rng.randf_range(-1.0, 1.0) * exp(-float(i) / tau) * amp
	return _normalize(out, 0.7)


## Tono con envolvente exponencial, sumado en `out` desde el instante `start_s`.
func _add_tone(out: PackedFloat32Array, start_s: float, freq: float, dur: float, tau: float, amp: float) -> void:
	var first: int = int(start_s * RATE)
	var n: int = int(dur * RATE)
	for i: int in n:
		if first + i >= out.size():
			break
		var t: float = float(i) / float(RATE)
		var env: float = exp(-t / tau) * minf(t / 0.002, 1.0)
		out[first + i] += (sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t)) * env * amp


func _blank(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## Tic suave: aviso de que algo se puede comprar.
func _tic() -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(0.09)
	_add_tone(out, 0.0, 2300.0, 0.09, 0.018, 0.6)
	return _normalize(out, 0.45)


## Ka-chunk del sello de goma: golpe grave + clic seco.
func _stamp() -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(0.28)
	_add_tone(out, 0.0, 95.0, 0.28, 0.06, 1.0)
	_add_tone(out, 0.0, 60.0, 0.28, 0.09, 0.7)
	for i: int in 700:
		out[i] += _rng.randf_range(-1.0, 1.0) * exp(-float(i) / 160.0) * 0.8
	return _normalize(out, 0.85)


## Hito: arpegio corto ascendente.
func _milestone() -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(0.75)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i: int in notes.size():
		_add_tone(out, float(i) * 0.1, notes[i], 0.45, 0.16, 0.6)
	return _normalize(out, 0.7)


## Golpe del sello de cadena: bombo con cola.
func _chain_hit() -> PackedFloat32Array:
	var out: PackedFloat32Array = _blank(0.55)
	_add_tone(out, 0.0, 70.0, 0.55, 0.14, 1.0)
	_add_tone(out, 0.0, 140.0, 0.3, 0.05, 0.5)
	for i: int in 1400:
		out[i] += _rng.randf_range(-1.0, 1.0) * exp(-float(i) / 350.0) * 0.5
	return _normalize(out, 0.9)


## Reciclado: soplido de ruido que sube y baja.
func _whoosh() -> PackedFloat32Array:
	var n: int = int(0.9 * RATE)
	var out: PackedFloat32Array = _blank(0.9)
	var lp: float = 0.0
	for i: int in n:
		var x: float = float(i) / float(n)
		var a: float = clampf(0.02 + 0.5 * sin(PI * x), 0.0, 1.0)
		lp += a * 0.5 * (_rng.randf_range(-1.0, 1.0) - lp)
		out[i] = lp * sin(PI * x)
	return _normalize(out, 0.6)


## Ruido de fondo que cierra sin costura (crossfade de la cola con el principio).
func _loop_noise(n: int, fade: int, cutoff: float) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n + fade)
	var lp: float = 0.0
	var a: float = clampf(2.0 * PI * cutoff / float(RATE), 0.0, 1.0)
	for i: int in n + fade:
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		buf[i] = lp
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		out[i] = buf[i]
	for i: int in fade:
		var w: float = float(i) / float(fade)
		out[i] = buf[i] * w + buf[n + i] * (1.0 - w)
	return out


## Ambiente de cada escenario (loop de 6 s): Mesa = cuarto con reloj, Piso = zumbido de heladera
## y pájaros lejanos, Galpón = zumbido grave y un golpe metálico, Estacionamiento = viento y un auto.
func _ambient(phase: int) -> PackedFloat32Array:
	var n: int = RATE * 6
	var out: PackedFloat32Array = _loop_noise(n, 4000, 300.0 + 150.0 * float(phase))
	for i: int in n:
		out[i] *= 0.5
	if phase == 1:
		for k: int in 6:
			_add_tone(out, float(k) + 0.1, 2400.0, 0.05, 0.008, 0.5)
			_add_tone(out, float(k) + 0.1, 900.0, 0.08, 0.02, 0.2)
	elif phase == 2:
		for i: int in n:
			var t: float = float(i) / float(RATE)
			out[i] += 0.12 * sin(TAU * 55.0 * t) + 0.05 * sin(TAU * 110.0 * t)
		_add_tone(out, 1.6, 3100.0, 0.12, 0.05, 0.22)
		_add_tone(out, 1.75, 3500.0, 0.1, 0.04, 0.2)
		_add_tone(out, 4.2, 2900.0, 0.14, 0.06, 0.2)
	elif phase == 3:
		for i: int in n:
			var t: float = float(i) / float(RATE)
			out[i] += 0.18 * sin(TAU * 50.0 * t) + 0.08 * sin(TAU * 100.0 * t)
		_add_tone(out, 2.7, 1750.0, 0.5, 0.12, 0.35)
	else:
		for i: int in n:
			var t: float = float(i) / float(RATE)
			var gust: float = 0.5 + 0.5 * sin(TAU * t / 6.0 * 2.0)
			out[i] *= 0.4 + 1.2 * gust
			var pass_env: float = exp(-pow((t - 3.0) / 0.7, 2.0))
			out[i] += pass_env * 0.25 * sin(TAU * (90.0 + 25.0 * pass_env) * t)
	return _normalize(out, 0.4)


func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0001
	for v: float in s:
		m = maxf(m, absf(v))
	var g: float = peak / m
	for i: int in s.size():
		s[i] = s[i] * g
	return s


func _save(samples: PackedFloat32Array, path: String) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var err: int = wav.save_to_wav(path)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [path, err])
