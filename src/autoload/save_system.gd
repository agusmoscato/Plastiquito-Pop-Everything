extends Node
## Guardado: JSON en user://save.json, automático cada 30 s y al salir. La lógica de formato
## (versión y migración) vive en GameState; acá solo se lee y escribe el archivo.

const PATH: String = "user://save.json"

var sim: GameSim
var interval: float = 30.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	if sim == null:
		return
	_timer += delta
	if _timer >= interval:
		save_now()


func save_now() -> bool:
	_timer = 0.0
	if sim == null:
		return false
	return write_file(PATH, sim.save_dict())


## Carga el save en `target`. false si no hay archivo o es inválido (la partida queda como estaba).
func load_into(target: GameSim) -> bool:
	var data: Dictionary = read_file(PATH)
	if data.is_empty():
		return false
	return target.load_dict(data)


static func write_file(path: String, data: Dictionary) -> bool:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}
