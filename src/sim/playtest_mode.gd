class_name PlaytestMode
extends RefCounted
## Decide qué herramientas de desarrollo están disponibles según los feature tags.


## true si es una build de playtest o de release.
static func is_playtest(tags: PackedStringArray) -> bool:
	return tags.has("playtest") or tags.has("release")


## El overlay F3 y el selector de tamaño solo existen fuera de playtest/release.
static func debug_allowed(tags: PackedStringArray) -> bool:
	return not is_playtest(tags)


## Tags relevantes de esta ejecución (consulta al motor; no es pura).
static func current_tags() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for tag: String in ["playtest", "release", "debug", "editor"]:
		if OS.has_feature(tag):
			out.append(tag)
	return out
