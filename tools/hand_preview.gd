extends SceneTree
## Vista previa de la mano: godot --path . -s tools/hand_preview.gd -- <salida.png> [pose] [yaw]
func _init() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	var ps: PackedScene = load("res://assets/models/hand.glb") as PackedScene
	var hand: Node3D = ps.instantiate() as Node3D
	root.add_child(hand)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	var mi: MeshInstance3D = hand.find_child("hand_glove", true, false) as MeshInstance3D
	var bb: AABB = mi.global_transform * mi.get_aabb()
	print("global aabb ", bb, " hand xform ", hand.global_transform)
	if args.size() > 4:
		mi.skin = null
		mi.skeleton = NodePath("")
	var c: Vector3 = bb.get_center()
	var view: String = args[3] if args.size() > 3 else "top"
	var d: float = bb.size.length() * 1.3
	cam.position = c + (Vector3(0, d, 0.001) if view == "top" else Vector3(d * 0.7, d * 0.5, d * 0.7))
	cam.look_at(c, Vector3(0, 0, -1) if view == "top" else Vector3.UP)
	if args.size() > 2 and args[1] != "none":
		var sk: Skeleton3D = hand.find_child("Skeleton3D", true, false) as Skeleton3D
		var bone: int = sk.find_bone(args[1])
		sk.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, deg_to_rad(float(args[2]))))
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
