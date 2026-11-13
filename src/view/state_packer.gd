class_name StatePacker
extends RefCounted
## Empaqueta el estado de una burbuja en un píxel RGBA8 (textura de estado del dibujo de lejos).
## R = presión / 2 (0..2), G = aplastamiento 0..1, B = progreso de reventón (0 entera, 1 reventada),
## A = tipo * 32 (0 normal, 1 dorada, 2 bomba, 3 línea, 4 eco). Un píxel por burbuja.

const PRESSURE_MAX: float = 2.0
const TYPE_STEP: int = 32


static func pack(pressure: float, squash: float, pop: float, type_id: int) -> Color:
	var r: int = roundi(clampf(pressure / PRESSURE_MAX, 0.0, 1.0) * 255.0)
	var g: int = roundi(clampf(squash, 0.0, 1.0) * 255.0)
	var b: int = roundi(clampf(pop, 0.0, 1.0) * 255.0)
	var a: int = clampi(type_id, 0, 7) * TYPE_STEP
	return Color8(r, g, b, a)


## Escribe el píxel directamente en un buffer RGBA8 (sin crear Color): la ruta caliente del dibujo de lejos.
static func pack_to(bytes: PackedByteArray, offset: int, pressure: float, squash: float, pop: float, type_id: int) -> void:
	bytes[offset] = roundi(clampf(pressure / PRESSURE_MAX, 0.0, 1.0) * 255.0)
	bytes[offset + 1] = roundi(clampf(squash, 0.0, 1.0) * 255.0)
	bytes[offset + 2] = roundi(clampf(pop, 0.0, 1.0) * 255.0)
	bytes[offset + 3] = clampi(type_id, 0, 7) * TYPE_STEP


static func pressure_of(c: Color) -> float:
	return roundf(c.r * 255.0) / 255.0 * PRESSURE_MAX


static func squash_of(c: Color) -> float:
	return roundf(c.g * 255.0) / 255.0


static func pop_of(c: Color) -> float:
	return roundf(c.b * 255.0) / 255.0


static func type_of(c: Color) -> int:
	return roundi(c.a * 255.0 / float(TYPE_STEP))


## Píxel de una burbuja intacta, normal y sin presionar (valor con el que se rellena la textura).
static func default_pixel() -> Color:
	return pack(1.0, 0.0, 0.0, 0)
