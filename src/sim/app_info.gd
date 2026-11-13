class_name AppInfo
extends RefCounted
## Versión del juego. Única fuente: application/config/version en project.godot.


## Extrae config/version de un texto con formato project.godot. "" si no está.
static func parse_version(project_text: String) -> String:
	var rx: RegEx = RegEx.create_from_string(r'(?m)^config/version\s*=\s*"([^"]*)"')
	var m: RegExMatch = rx.search(project_text)
	if m == null:
		return ""
	return m.get_string(1)


## Versión del juego en ejecución (la lee de los ajustes del proyecto).
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
