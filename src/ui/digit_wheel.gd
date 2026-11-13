class_name DigitWheel
extends Control
## Un rodillo del odómetro: una ventanita de papel donde el dígito rueda (no salta).

const W: float = 22.0
const H: float = 34.0

var value: float = 0.0 ## 0..10 continuo (la parte entera es el dígito)
var dim: bool = false ## ceros a la izquierda se ven tenues


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, W, H), UiKit.PAPER)
	var font: Font = UiKit.font_mono_bold()
	var base: int = int(floorf(value)) % 10
	var frac: float = value - floorf(value)
	var color: Color = UiKit.INK_SOFT if dim else UiKit.INK
	var y0: float = H * 0.5 + 9.0 - frac * H
	draw_string(font, Vector2(3.0, y0), str(base), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, color)
	draw_string(font, Vector2(3.0, y0 + H), str((base + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, color)
	# Sombreado de cilindro arriba y abajo.
	draw_rect(Rect2(0.0, 0.0, W, 7.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(0.0, H - 7.0, W, 7.0), Color(0.0, 0.0, 0.0, 0.22))
	draw_line(Vector2(0.0, H * 0.5), Vector2(W, H * 0.5), Color(0.0, 0.0, 0.0, 0.05), 1.0)
