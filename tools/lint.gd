extends SceneTree
## Carga todos los scripts de src/, tests/ y tools/ con las advertencias de tipos como errores.
## Uso: godot --headless -s tools/lint.gd  (sale con 1 si algún script no compila)

func _initialize() -> void:
	var failed: int = 0
	for dir: String in ["res://src", "res://tests", "res://tools"]:
		for path: String in _scripts_in(dir):
			if path == "res://tools/lint.gd":
				continue # no recargar el script en ejecución
			var s: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if s == null:
				print("LINT FAIL: ", path)
				failed += 1
	print("lint: scripts con error = ", failed)
	var code: int = 0
	if failed > 0:
		code = 1
	quit(code)


func _scripts_in(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(d)))
	return out
