class_name ToolIcon
extends TextureRect
## Ícono de herramienta o de mejora: imagen pre-renderizada en Blender (art/icons.py), 256 px con fondo
## transparente, luz de estudio, contorno oscuro y encuadre cerrado. Antes era un SubViewport en vivo
## por ícono: a 48 px no se leía y había decenas en la tienda.

const DIR: String = "res://assets/icons/"
## Mejoras: un ícono por categoría (regla, burbuja reventando, estela, manito). El resto de los tipos
## de mejora usa el ícono de su herramienta.
const VARIANT_ICON: Dictionary[String, String] = {
	"size": "up_size",
	"force": "up_force",
	"speed": "up_speed",
	"count": "up_auto",
	"smart": "up_auto",
	"automation": "up_auto",
	"auto_reload": "up_auto",
}

var kind: String = "finger"
var tier: int = 0 ## se conserva por compatibilidad: el ícono no cambia con el nivel
var variant: String = ""


func setup(p_kind: String, px: int, p_tier: int = 0) -> void:
	kind = p_kind
	tier = p_tier
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func set_variant(p_variant: String) -> void:
	variant = p_variant
	_refresh()


func set_tier(p_tier: int) -> void:
	tier = p_tier


## Nombre del archivo (sin extensión) para una herramienta y una variante de mejora.
static func icon_name(p_kind: String, p_variant: String) -> String:
	if VARIANT_ICON.has(p_variant):
		return VARIANT_ICON[p_variant]
	return p_kind


func _refresh() -> void:
	var path: String = DIR + icon_name(kind, variant) + ".png"
	if not ResourceLoader.exists(path):
		path = DIR + "bubble.png"
	texture = load(path) as Texture2D
