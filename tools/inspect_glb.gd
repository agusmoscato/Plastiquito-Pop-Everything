extends SceneTree
func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var ps: PackedScene = load(path) as PackedScene
		var root: Node = ps.instantiate()
		print("== ", path)
		_walk(root, 0)
	quit()

func _walk(n: Node, d: int) -> void:
	var line: String = "  ".repeat(d) + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		line += " aabb=" + str(mi.get_aabb())
	if n is Skeleton3D:
		var sk: Skeleton3D = n as Skeleton3D
		for i: int in sk.get_bone_count():
			line += "\n" + "  ".repeat(d + 1) + str(i) + " " + sk.get_bone_name(i) + " parent=" + str(sk.get_bone_parent(i)) + " rest=" + str(sk.get_bone_rest(i).origin) + " " + str(sk.get_bone_rest(i).basis.get_euler())
	print(line)
	for c: Node in n.get_children():
		_walk(c, d + 1)
