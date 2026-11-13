extends SceneTree
## Genera el ícono del juego por código: una burbuja celeste brillante sobre fondo transparente.
## Uso: godot --headless -s tools/gen_icon.gd
## Escribe icon.png (256 px) y icon.ico (256, 128, 64, 48, 32, 16 con PNG embebido) en la raíz.

const SIZES: Array[int] = [256, 128, 64, 48, 32, 16]


func _init() -> void:
	var pngs: Array[PackedByteArray] = []
	for size: int in SIZES:
		var img: Image = _draw(size)
		pngs.append(img.save_png_to_buffer())
		if size == 256:
			img.save_png("res://icon.png")
	_write_ico(pngs, "res://icon.ico")
	print("gen_icon: listo")
	quit(0)


## Dibuja la burbuja con supermuestreo 4x4 para bordes suaves.
func _draw(size: int) -> Image:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var ss: int = 4
	for y: int in size:
		for x: int in size:
			var acc: Color = Color(0.0, 0.0, 0.0, 0.0)
			for sy: int in ss:
				for sx: int in ss:
					var u: float = (float(x) + (float(sx) + 0.5) / float(ss)) / float(size)
					var v: float = (float(y) + (float(sy) + 0.5) / float(ss)) / float(size)
					var c: Color = _shade(u, v)
					acc += Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
			var a: float = acc.a / float(ss * ss)
			var rgb: Color = Color(acc.r, acc.g, acc.b) / maxf(acc.a, 0.0001)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	return img


## Color (con alfa) de la burbuja en el punto (u, v) del cuadro 0..1.
func _shade(u: float, v: float) -> Color:
	var p: Vector2 = Vector2(u, v) - Vector2(0.5, 0.5)
	var d: float = p.length() / 0.44 # 1.0 = borde de la burbuja
	if d > 1.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	# Cuerpo: degradado celeste, más claro arriba a la izquierda.
	var t: float = clampf((p.x + p.y) / 0.8 + 0.5, 0.0, 1.0)
	var body: Color = Color(0.62, 0.90, 1.0).lerp(Color(0.12, 0.55, 0.92), t)
	# Borde con fresnel: más brillante y saturado cerca del contorno.
	var rim: float = pow(d, 3.0)
	body = body.lerp(Color(0.85, 0.97, 1.0), rim * 0.55)
	var alpha: float = lerpf(0.88, 1.0, rim)
	# Contorno oscuro fino para que se lea sobre fondos claros.
	if d > 0.93:
		body = body.lerp(Color(0.05, 0.38, 0.75), smoothstep(0.93, 1.0, d))
	# Brillo especular grande arriba a la izquierda.
	var hl: Vector2 = (Vector2(u, v) - Vector2(0.37, 0.33)) / Vector2(0.14, 0.09)
	var spec: float = 1.0 - smoothstep(0.6, 1.0, hl.rotated(-0.6).length())
	body = body.lerp(Color(1.0, 1.0, 1.0), spec * 0.95)
	# Brillito chico abajo a la derecha.
	var hl2: float = (Vector2(u, v) - Vector2(0.64, 0.68)).length() / 0.05
	body = body.lerp(Color(1.0, 1.0, 1.0), (1.0 - smoothstep(0.5, 1.0, hl2)) * 0.5)
	return Color(body.r, body.g, body.b, alpha)


func _write_ico(pngs: Array[PackedByteArray], path: String) -> void:
	var out: PackedByteArray = PackedByteArray()
	out.resize(6 + 16 * pngs.size())
	out.encode_u16(0, 0)
	out.encode_u16(2, 1) # tipo: ícono
	out.encode_u16(4, pngs.size())
	var offset: int = 6 + 16 * pngs.size()
	for i: int in pngs.size():
		var e: int = 6 + 16 * i
		var s: int = SIZES[i]
		out.encode_u8(e, 0 if s >= 256 else s)
		out.encode_u8(e + 1, 0 if s >= 256 else s)
		out.encode_u8(e + 2, 0)
		out.encode_u8(e + 3, 0)
		out.encode_u16(e + 4, 1)
		out.encode_u16(e + 6, 32)
		out.encode_u32(e + 8, pngs[i].size())
		out.encode_u32(e + 12, offset)
		offset += pngs[i].size()
	for png: PackedByteArray in pngs:
		out.append_array(png)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
