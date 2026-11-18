extends SceneTree
## Sonidos propios de reventón (síntesis, sin grabaciones de terceros): reemplazan a los ph_* de
## assets/audio/pops/{small,large,tense}/. Modelo de un reventón de plástico de burbujas:
##   1. chasquido: ráfaga de ruido de < 1 ms (la lámina que se rompe), filtrada hacia los agudos;
##   2. resonancias excitadas por ese chasquido: el aire de la burbuja (2-3,5 kHz, corta) y la lámina
##      que flamea (0,7-1,2 kHz) más un cuerpo leve (260-380 Hz). Antes había un "thump" de 110-170 Hz
##      que sonaba a golpe sordo;
##   3. el aire que escapa: un soplido corto de ruido agudo;
##   4. dos o tres micro-crujidos de la lámina que se acomoda (10-60 ms después).
## Las grandes son más graves y largas; las tensas, más brillantes y secas.
## Uso: godot --headless -s tools/gen_pop_sfx.gd    (escribe pop_<categoría>_NN.wav y borra los ph_)

const RATE: int = 44100
const VARIANTS: int = 12
const OUT_POPS: String = "res://assets/audio/pops"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261118
	for category: String in ["small", "large", "tense"]:
		var dir: String = OUT_POPS.path_join(category)
		_remove_placeholders(dir)
		for i: int in VARIANTS:
			_save(make_pop(category, _rng), dir.path_join("pop_%s_%02d.wav" % [category, i]))
	print("gen_pop_sfx: listo")
	quit(0)


## Parámetros por categoría: escala de frecuencias, de duraciones y brillo del chasquido.
static func make_pop(category: String, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var f_scale: float = 1.0
	var t_scale: float = 1.0
	var crack: float = 1.0
	var body: float = 0.35
	match category:
		"large":
			f_scale = rng.randf_range(0.62, 0.75)
			t_scale = rng.randf_range(1.5, 1.8)
			body = 0.6
		"tense":
			f_scale = rng.randf_range(1.15, 1.3)
			t_scale = 0.75
			crack = 1.5
			body = 0.2
		_:
			f_scale = rng.randf_range(0.9, 1.1)
	var n: int = int(0.12 * t_scale * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var exc: PackedFloat32Array = _excitation(n, crack, rng)
	_add(out, _bandpass(exc, rng.randf_range(2200.0, 3400.0) * f_scale, 9.0), 1.0)
	_add(out, _bandpass(exc, rng.randf_range(700.0, 1150.0) * f_scale, 4.0), 0.75)
	_add(out, _bandpass(exc, rng.randf_range(260.0, 380.0) * f_scale, 2.5), body)
	_add(out, _air(n, 0.018 * t_scale, rng), 0.28)
	_add(out, _highpass(exc, 4000.0), 0.6 * crack) # el chasquido seco arriba de todo
	_tail(out, rng, t_scale)
	return _normalize(_fade_out(out, 0.01), 0.92)


## Ráfaga de ruido muy corta (0,3-0,9 ms) con ataque instantáneo: lo que excita las resonancias.
static func _excitation(n: int, crack: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var e: PackedFloat32Array = PackedFloat32Array()
	e.resize(n)
	var len_s: int = int(rng.randf_range(0.0003, 0.0009) * RATE)
	for i: int in mini(len_s * 4, n):
		e[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / float(maxi(len_s, 1))) * crack
	return e


## Pasabanda resonante (biquad, RBJ, ganancia de pico constante).
static func _bandpass(x: PackedFloat32Array, f: float, q: float) -> PackedFloat32Array:
	var w0: float = TAU * minf(f, RATE * 0.45) / float(RATE)
	var alpha: float = sin(w0) / (2.0 * q)
	var a0: float = 1.0 + alpha
	var b0: float = alpha / a0
	var b2: float = -alpha / a0
	var a1: float = -2.0 * cos(w0) / a0
	var a2: float = (1.0 - alpha) / a0
	return _biquad(x, b0, 0.0, b2, a1, a2)


static func _highpass(x: PackedFloat32Array, f: float) -> PackedFloat32Array:
	var w0: float = TAU * f / float(RATE)
	var alpha: float = sin(w0) / (2.0 * 0.707)
	var c: float = cos(w0)
	var a0: float = 1.0 + alpha
	return _biquad(x, (1.0 + c) * 0.5 / a0, -(1.0 + c) / a0, (1.0 + c) * 0.5 / a0, -2.0 * c / a0, (1.0 - alpha) / a0)


static func _biquad(x: PackedFloat32Array, b0: float, b1: float, b2: float, a1: float, a2: float) -> PackedFloat32Array:
	var y: PackedFloat32Array = PackedFloat32Array()
	y.resize(x.size())
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in x.size():
		var v: float = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


## El aire que escapa: ruido agudo con ataque de 1 ms y caída exponencial.
static func _air(n: int, tau: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var w: PackedFloat32Array = PackedFloat32Array()
	w.resize(n)
	for i: int in n:
		var t: float = float(i) / float(RATE)
		w[i] = rng.randf_range(-1.0, 1.0) * minf(t / 0.001, 1.0) * exp(-t / tau)
	return _highpass(w, 3500.0)


## Micro-crujidos de la lámina que se acomoda después del reventón.
static func _tail(out: PackedFloat32Array, rng: RandomNumberGenerator, t_scale: float) -> void:
	for k: int in rng.randi_range(2, 3):
		var start: int = int(rng.randf_range(0.010, 0.060) * t_scale * RATE)
		var amp: float = rng.randf_range(0.05, 0.14)
		for i: int in 120:
			if start + i >= out.size():
				break
			out[start + i] += rng.randf_range(-1.0, 1.0) * exp(-float(i) / 18.0) * amp


static func _add(out: PackedFloat32Array, x: PackedFloat32Array, gain: float) -> void:
	for i: int in mini(out.size(), x.size()):
		out[i] += x[i] * gain


static func _fade_out(s: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var n: int = mini(int(seconds * RATE), s.size())
	for i: int in n:
		s[s.size() - 1 - i] *= float(i) / float(n)
	return s


static func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0
	for v: float in s:
		m = maxf(m, absf(v))
	if m > 0.0:
		for i: int in s.size():
			s[i] = s[i] / m * peak
	return s


static func _remove_placeholders(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.begins_with("ph_") or f.begins_with("pop_"):
			d.remove(f)


static func _save(samples: PackedFloat32Array, path: String) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(ProjectSettings.globalize_path(path))
