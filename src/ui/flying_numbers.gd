class_name FlyingNumbers
extends Control
## Cada "+N" vuela desde la burbuja reventada hasta el contador por una curva y se suma al llegar.
## Cuando llegan muchos se agrupan, para no ensuciar la pantalla.

signal arrived(value: float)

var target: Vector2 = Vector2(150.0, 80.0)

var _items: Array[Dictionary] = []


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Agrega un "+valor" que sale de `from` (pantalla).
func spawn(from: Vector2, value: float) -> void:
	var dur: float = randf_range(0.55, 0.8)
	var side: float = randf_range(-90.0, 90.0)
	_items.append({"from": from, "value": value, "t": 0.0, "dur": dur, "ctrl": from.lerp(target, 0.35) + Vector2(side, -randf_range(60.0, 140.0))})


func pending() -> int:
	return _items.size()


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for it: Dictionary in _items:
		var t: float = it["t"]
		var dur: float = it["dur"]
		t += delta
		if t >= dur:
			var v: float = it["value"]
			arrived.emit(v)
			continue
		it["t"] = t
		keep.append(it)
	_items = keep
	queue_redraw()


func _draw() -> void:
	var font: Font = UiKit.font_mono_bold()
	for it: Dictionary in _items:
		var t: float = it["t"]
		var dur: float = it["dur"]
		var k: float = t / dur
		var e: float = k * k * (3.0 - 2.0 * k)
		var a: Vector2 = it["from"]
		var c: Vector2 = it["ctrl"]
		var p: Vector2 = a.lerp(c, e).lerp(c.lerp(target, e), e)
		var v: float = it["value"]
		var fs: int = clampi(int(13.0 + log(maxf(v, 1.0)) / log(10.0) * 3.0), 13, 30)
		var text: String = "+" + NumberFormat.pops(v, Settings.language)
		var alpha: float = clampf((1.0 - k) * 2.2, 0.0, 1.0)
		draw_string(font, p + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.PAPER.r, UiKit.PAPER.g, UiKit.PAPER.b, alpha))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, alpha))
