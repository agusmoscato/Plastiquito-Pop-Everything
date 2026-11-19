class_name BubbleCursor
extends RefCounted
## El puntero del mouse es una burbujita (domo celeste con brillo y contorno de tinta), dibujada
## por código. Se usa en los menús y sobre la interfaz; sobre la lámina se esconde y se ve la mano.

const SIZE: int = 30


## Imagen de la burbuja, de `px` de lado, con borde suavizado.
static func image(px: int) -> Image:
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(float(px), float(px)) * 0.5
	var r: float = float(px) * 0.5 - 2.0
	var shine: Vector2 = c + Vector2(-r * 0.36, -r * 0.38)
	for y: int in px:
		for x: int in px:
			img.set_pixel(x, y, _pixel(Vector2(float(x) + 0.5, float(y) + 0.5), c, r, shine))
	return img


static func _pixel(p: Vector2, c: Vector2, r: float, shine: Vector2) -> Color:
	var d: float = p.distance_to(c)
	if d > r + 1.0:
		return Color(0, 0, 0, 0)
	var edge: float = clampf(r + 1.0 - d, 0.0, 1.0) # borde suavizado
	var fill: Color = UiKit.BUBBLE_BLUE
	var k: float = d / r
	fill = fill.lerp(Color(1, 1, 1), 0.25 * (1.0 - k)) # el centro más claro: se ve inflada
	var col: Color = Color(fill.r, fill.g, fill.b, 0.82)
	if d > r - 2.2: # contorno de tinta
		col = Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 1.0)
	var s: float = p.distance_to(shine)
	if s < r * 0.26:
		col = col.lerp(Color(1, 1, 1, 1), clampf((r * 0.26 - s) / 1.5, 0.0, 0.95))
	col.a *= edge
	return col


## Pone la burbujita como puntero normal y como puntero de botón.
static func apply() -> void:
	var tex: ImageTexture = ImageTexture.create_from_image(image(SIZE))
	var hot: Vector2 = Vector2(float(SIZE), float(SIZE)) * 0.5
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hot)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, hot)


## Vuelve al puntero del sistema (al salir: si no, la textura queda viva hasta después del renderizador).
static func clear() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)


## Los menús siempre muestran el puntero (el juego lo esconde sobre la lámina).
static func show() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
