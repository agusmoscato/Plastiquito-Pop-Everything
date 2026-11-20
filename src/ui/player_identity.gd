class_name PlayerIdentity
extends RefCounted
## Quién es el empleado (sección 7 de la 0.7.0): el nombre y la foto de Steam (GodotSteam) si el addon y el
## cliente están, y si no una ficha donde el jugador escribe su nombre ("Empleado N° 4417" si no lo hace) y
## una silueta dibujada. PRIVACIDAD: el nombre y la foto se usan solo en esta PC; nunca se suben ni se
## guardan fuera del guardado local.
## PENDIENTE: el App ID 480 (de prueba de Steam) se usa solo en builds de desarrollo hasta que haya App ID propio.

const DEV_APP_ID: int = 480

static var steam_name: String = ""
static var photo: Image = null ## avatar grande de Steam, tal cual (se estiliza al mostrarlo)
static var _asked: bool = false


## Intenta conectarse a Steam (si el singleton "Steam" de GodotSteam existe). No hace nada en el CI ni sin Steam.
static func try_steam(tags: PackedStringArray) -> void:
	if _asked or not Engine.has_singleton("Steam"):
		return
	_asked = true
	var steam: Object = Engine.get_singleton("Steam")
	if not PlaytestMode.is_playtest(tags): # en desarrollo: App ID de prueba
		OS.set_environment("SteamAppId", str(DEV_APP_ID))
		OS.set_environment("SteamGameId", str(DEV_APP_ID))
	if steam.has_method("steamInitEx"):
		steam.call("steamInitEx")
	elif steam.has_method("steamInit"):
		steam.call("steamInit")
	if steam.has_method("getPersonaName"):
		steam_name = str(steam.call("getPersonaName"))
	if steam.has_signal("avatar_loaded"):
		steam.connect("avatar_loaded", Callable(PlayerIdentity, "_on_avatar_loaded"))
	if steam.has_method("getPlayerAvatar") and steam.has_method("getSteamID"):
		steam.call("getPlayerAvatar", 3, steam.call("getSteamID")) # 3 = avatar grande


static func _on_avatar_loaded(_id: int, size: int, buffer: PackedByteArray) -> void:
	if size > 0 and buffer.size() >= size * size * 4:
		photo = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)


## Foto carnet: un poco desaturada y cálida, con borde de papel (nunca el avatar crudo). Sin foto, la silueta.
static func id_photo(px: int = 128) -> Image:
	var img: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color("#F1EBDC")) # papel
	var inner: int = px - 14
	if photo != null:
		var p: Image = photo.duplicate()
		p.resize(inner, inner, Image.INTERPOLATE_BILINEAR)
		for y: int in inner:
			for x: int in inner:
				var c: Color = p.get_pixel(x, y)
				var g: float = c.get_luminance()
				var s: Color = Color(c.r, c.g, c.b).lerp(Color(g, g, g), 0.35) * Color(1.04, 0.98, 0.9)
				img.set_pixel(x + 7, y + 7, Color(s.r, s.g, s.b, 1.0))
	else:
		_paint_silhouette(img, px)
	return img


static func id_texture(px: int = 128) -> ImageTexture:
	return ImageTexture.create_from_image(id_photo(px))


## Silueta dibujada: fondo gris azulado con cabeza y hombros.
static func _paint_silhouette(img: Image, px: int) -> void:
	var bg: Color = Color("#9DB0BA")
	var ink: Color = Color("#3B4A55")
	for y: int in range(7, px - 7):
		for x: int in range(7, px - 7):
			img.set_pixel(x, y, bg)
	var cx: float = float(px) * 0.5
	var head: Vector2 = Vector2(cx, float(px) * 0.40)
	var hr: float = float(px) * 0.17
	for y: int in range(7, px - 7):
		for x: int in range(7, px - 7):
			var p: Vector2 = Vector2(float(x), float(y))
			var in_head: bool = p.distance_to(head) < hr
			var sh: Vector2 = Vector2(cx, float(px) * 0.98)
			var in_body: bool = (p.distance_to(sh) < float(px) * 0.36) and p.y > float(px) * 0.58
			if in_head or in_body:
				img.set_pixel(x, y, ink)
