extends SceneTree
## Vista previa de una herramienta: godot --path . -s tools/tool_preview.gd -- <id> <radio> <salida.png> [yaw_cam]
func _init() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tool: Node3D = ToolMeshes.build(args[0], float(args[1]), 0)
	root.add_child(tool)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	# plano de referencia: rejilla de "burbujas" de 1 unidad
	var grid: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	grid.mesh = pm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.9, 0.95)
	grid.material_override = gm
	root.add_child(grid)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	var d: float = float(args[3]) if args.size() > 3 else 14.0
	var view: String = args[4] if args.size() > 4 else "game"
	if view == "top":
		cam.position = Vector3(0, d, 0.001)
		cam.look_at(Vector3.ZERO, Vector3(0, 0, -1))
	elif view == "side":
		cam.position = Vector3(d, d * 0.12, 0)
		cam.look_at(Vector3(0, d * 0.05, 0))
	else: # cámara del juego: inclinada 55°, mirando hacia -Z
		cam.position = Vector3(0, d * sin(deg_to_rad(55.0)), d * cos(deg_to_rad(55.0)))
		cam.look_at(Vector3.ZERO, Vector3.UP)
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[2])
	quit()
