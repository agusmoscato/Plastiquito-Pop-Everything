extends SceneTree
## Pasa las PNG de una carpeta (recursivo) a JPG: 1600 px de ancho como máximo, calidad 85 y, si
## pasa de 500 KB, baja la calidad hasta entrar. Borra la PNG y su .import.
## Uso: godot --headless --path . -s tools/png_to_jpg.gd -- res://docs/screens

const MAX_W: int = 1600
const MAX_BYTES: int = 500 * 1024


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var root: String = args[0] if args.size() > 0 else "res://docs/screens"
	var n: int = _walk(root)
	print("png_to_jpg: %d archivos convertidos" % n)
	quit(0)


func _walk(dir_path: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	for sub: String in dir.get_directories():
		count += _walk(dir_path.path_join(sub))
	for file: String in dir.get_files():
		if file.get_extension().to_lower() == "png":
			if _convert(dir_path.path_join(file)):
				count += 1
	return count


func _convert(path: String) -> bool:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		print("no se pudo leer ", path)
		return false
	if img.get_width() > MAX_W:
		img.resize(MAX_W, int(float(img.get_height()) * float(MAX_W) / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
	var out: String = path.get_basename() + ".jpg"
	var quality: float = 0.85
	while true:
		img.save_jpg(ProjectSettings.globalize_path(out), quality)
		var size: int = FileAccess.get_file_as_bytes(out).size()
		if size <= MAX_BYTES or quality <= 0.5:
			break
		quality -= 0.07
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".import"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".import"))
	return true
