extends GutTest
## Regla de CLAUDE.md: ningún script del juego, de las herramientas ni de los tests mueve el cursor o el teclado
## reales de Windows (el bot de humo usa solo Input.parse_input_event).

const FORBIDDEN: Array[String] = ["warp_mouse(", "mouse_set_mode(", "warp_mouse_position("]


func _scripts_in(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(d)))
	return out


func test_nothing_moves_the_real_cursor() -> void:
	var checked: int = 0
	for dir: String in ["res://src", "res://tools", "res://tests"]:
		for path: String in _scripts_in(dir):
			if path == "res://tests/test_no_real_input.gd":
				continue
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for i: int in lines.size():
				var code: String = lines[i].split("#")[0] # los comentarios pueden nombrarlo
				for bad: String in FORBIDDEN:
					assert_false(code.contains(bad), "%s:%d usa %s (mueve el cursor real)" % [path, i + 1, bad])
			checked += 1
	assert_gt(checked, 50, "se revisaron los scripts")
