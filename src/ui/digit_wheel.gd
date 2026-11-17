class_name DigitWheel
extends Control
## Un rodillo del odómetro: una ventanita de papel donde el dígito rueda (no salta).

const W: float = 22.0
const H: float = 34.0
const FONT_SIZE: int = 25

var value: float = 0.0 ## 0..10 continuo (la parte entera es el dígito)
var dim: bool = false ## ceros a la izquierda se ven tenues


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Recorte explícito del propio dibujo: el dígito que rueda nunca se dibuja fuera de su ventana
## (si no, se encimaba con el de arriba o el de abajo mientras rodaba).
func _ready() -> void:
	RenderingServer.canvas_item_set_clip(get_canvas_item(), true)
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(Vector2.ZERO, size))


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, W, H), UiKit.PAPER)
	var font: Font = UiKit.font_mono_bold()
	var base: int = int(floorf(value)) % 10
	var frac: float = value - floorf(value)
	var color: Color = UiKit.INK_SOFT if dim else UiKit.INK
	var y0: float = H * 0.5 + 9.0 - frac * H
	var fs: int = FONT_SIZE
	var glyph_w: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var x: float = (W - glyph_w) * 0.5 # centrado: el dígito nunca toca el borde de la ventana
	if frac < 0.001:
		draw_string(font, Vector2(x, y0), str(base), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)
	else:
		draw_string(font, Vector2(x, y0), str(base), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)
		draw_string(font, Vector2(x, y0 + H), str((base + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)
	# Sombreado de cilindro arriba y abajo.
	draw_rect(Rect2(0.0, 0.0, W, 7.0), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(Rect2(0.0, H - 7.0, W, 7.0), Color(0.0, 0.0, 0.0, 0.22))
	draw_line(Vector2(0.0, H * 0.5), Vector2(W, H * 0.5), Color(0.0, 0.0, 0.0, 0.05), 1.0)
