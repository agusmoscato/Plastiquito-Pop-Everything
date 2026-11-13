class_name ComboMeter
extends Control
## Ritmo de reventones: multiplicador grande en un sello y una barra de ritmo.

var multiplier: float = 1.0
var rate_ratio: float = 0.0
var _punch: float = 0.0
var _last: float = 1.0


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190.0, 96.0)
	size = custom_minimum_size
	material = UiKit.paper_material()


func update_values(mult: float, ratio: float) -> void:
	if mult > _last + 0.01:
		_punch = 1.0
	_last = mult
	multiplier = mult
	rate_ratio = ratio


func _process(delta: float) -> void:
	_punch = maxf(0.0, _punch - delta * 4.5)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 6.0), Vector2(size.x - 10.0, size.y - 12.0))
	UiKit.draw_sheet(self, rect, UiKit.KRAFT, "combo", 1.0, 1.6)
	UiKit.draw_text(self, Vector2(18.0, 28.0), Tx.t("rhythm"), UiKit.font_mono_bold(), 12, UiKit.CARDBOARD_DARK)
	var s: float = 1.0 + _punch * 0.35
	var txt: String = "x" + NumberFormat.decimal(multiplier, 1, Settings.language)
	var font: Font = UiKit.font_title()
	var fs: int = int(34.0 * s)
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var color: Color = UiKit.STAMP_RED if multiplier >= 3.0 else UiKit.INK
	draw_string(font, Vector2(size.x * 0.5 - ts.x * 0.5, 66.0 + (s - 1.0) * 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)
	UiKit.draw_ink_bar(self, Rect2(Vector2(18.0, 76.0), Vector2(size.x - 46.0, 8.0)), rate_ratio, UiKit.INK)
