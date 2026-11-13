class_name ChainStamp
extends Control
## "CADENA xN": un sello que crece mientras la cadena sigue y golpea al terminar con el total
## ganado. Es el momento más satisfactorio del juego, así que tiene peso.

signal slammed(count: int)

var count: int = 0
var growing: bool = false
var total_text: String = ""

var _slam: float = 0.0
var _hold: float = 0.0
var _fade: float = 0.0
var _shake: Vector2 = Vector2.ZERO


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	material = UiKit.paper_material()


func chain_progress(n: int) -> void:
	count = n
	growing = true
	_hold = 0.0
	_fade = 1.0


func chain_ended(n: int, total: float) -> void:
	count = n
	growing = false
	total_text = "+" + NumberFormat.pops(total, Settings.language)
	_slam = 1.0
	_hold = 1.6
	_fade = 1.0
	slammed.emit(n)


func _process(delta: float) -> void:
	_slam = maxf(0.0, _slam - delta * 3.0)
	if not growing:
		_hold = maxf(0.0, _hold - delta)
		if _hold <= 0.0:
			_fade = maxf(0.0, _fade - delta * 2.5)
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (_slam * 7.0 + (1.5 if growing else 0.0))
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.01 or count < 2:
		return
	var center: Vector2 = Vector2(size.x * 0.5 - 150.0, 250.0) + _shake
	var scale_f: float = 1.0 + minf(float(count) / 60.0, 1.2) + _slam * 0.55
	var w: float = 300.0 * scale_f
	var h: float = 76.0 * scale_f
	var r: Rect2 = Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var label: String = "%s x%d" % [Tx.t("chain"), count]
	UiKit.draw_stamp(self, r, label, UiKit.STAMP_RED, int(30.0 * scale_f), -0.09, _fade)
	if not growing and total_text != "":
		var font: Font = UiKit.font_mono_bold()
		var fs: int = int(26.0 * minf(scale_f, 1.8))
		var ts: Vector2 = font.get_string_size(total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
		var pos: Vector2 = Vector2(center.x - ts.x * 0.5, r.end.y + 34.0)
		draw_string(font, pos + Vector2(2.0, 2.0), total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.PAPER.r, UiKit.PAPER.g, UiKit.PAPER.b, _fade))
		draw_string(font, pos, total_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, _fade))
