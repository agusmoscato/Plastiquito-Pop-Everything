class_name Odometer
extends Control
## Contador de Pops: rodillo mecánico. Los dígitos ruedan hacia el valor y no saltan.
## Hasta 12 cifras se muestran en rodillos; más allá, texto con sufijo.

const MAX_DIGITS: int = 12

var target: float = 0.0
var shown: float = 0.0

var _wheels: Array[DigitWheel] = []
var _label: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in MAX_DIGITS:
		var w: DigitWheel = DigitWheel.new()
		add_child(w)
		_wheels.append(w)
	_layout(6)


func set_target(value: float) -> void:
	target = maxf(0.0, value)


func snap() -> void:
	shown = target


func _process(delta: float) -> void:
	var diff: float = target - shown
	if absf(diff) < 0.01:
		shown = target
	else:
		# Rueda más rápido cuanto más lejos está; nunca salta de golpe.
		var k: float = 1.0 - exp(-7.0 * delta)
		shown += diff * k
		if absf(target - shown) < 0.5:
			shown = target
	_update_wheels()


func _update_wheels() -> void:
	if shown >= 1.0e12:
		for w: DigitWheel in _wheels:
			w.visible = false
		_label = NumberFormat.pops(shown, Settings.language)
		queue_redraw()
		return
	_label = ""
	var digits: int = maxi(6, str(int(shown)).length())
	_layout(digits)
	for i: int in digits:
		var place: float = pow(10.0, float(digits - 1 - i))
		var digit_f: float = fmod(shown / place, 10.0)
		var w: DigitWheel = _wheels[i]
		var frac: float = digit_f - floorf(digit_f)
		w.value = floorf(digit_f) + smoothstep(0.82, 1.0, frac)
		w.dim = shown < place and i < digits - 1
		w.queue_redraw()


func _layout(digits: int) -> void:
	var x: float = 8.0
	for i: int in MAX_DIGITS:
		var w: DigitWheel = _wheels[i]
		w.visible = i < digits
		if i < digits:
			var group_gap: float = 6.0 if (digits - i) % 3 == 0 and i > 0 else 0.0
			x += group_gap
			w.position = Vector2(x, 7.0)
			x += DigitWheel.W + 2.0
	custom_minimum_size = Vector2(x + 8.0, DigitWheel.H + 14.0)
	size = custom_minimum_size


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.CARDBOARD_DARK)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.25), false, 2.0)
	if _label != "":
		draw_string(UiKit.font_mono_bold(), Vector2(12.0, 32.0), _label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, UiKit.PAPER)
