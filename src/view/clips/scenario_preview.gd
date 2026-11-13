extends ClipBase
## Capturas de cada escenario (y de la transición) para revisarlos.
## Uso: godot --path . scenes/clips/scenario_preview.tscn -- --shots=<carpeta>

var _dir: String = ""
var _step: int = 0
var _timer: float = 0.0


func _init() -> void:
	duration = 60.0


func setup() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(_dir)
	make_sheet(20, 20, 1)
	precharge(1.0, 1.1, center(), 0.0, 1.0)
	tool_view.visible = false
	cam(center(), 26.0)


func _shot(shot_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_dir, shot_name])
	print("shot: ", shot_name)


func script_step(_time: float, delta: float) -> void:
	_timer += delta
	var names: Array[String] = ["1_mesa", "2_piso", "3_galpon", "4_estacionamiento"]
	if _step < 4:
		if _timer > 1.0:
			_shot(names[_step])
			_step += 1
			_timer = 0.0
			if _step < 4:
				world.apply_phase(_step + 1)
	elif _step == 4:
		world.apply_phase(1)
		_step = 5
		_timer = 0.0
	elif _step == 5 and _timer > 0.6:
		world.transition_to_phase(4, 3.5)
		_step = 6
		_timer = 0.0
	elif _step == 6 and _timer > 1.5:
		_shot("5_transicion_mitad")
		_step = 7
	elif _step == 7 and _timer > 4.5:
		_shot("6_transicion_fin")
		get_tree().quit()
