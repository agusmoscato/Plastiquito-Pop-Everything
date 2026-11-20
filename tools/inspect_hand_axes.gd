extends SceneTree
## Mide la mano (hand.glb) en el espacio de cada hueso: secciones del antebrazo y de los dedos, para ubicar
## pulsera, reloj y anillos. Uso: godot --headless -s tools/inspect_hand_axes.gd


func _init() -> void:
	var ps: PackedScene = load("res://assets/models/hand.glb") as PackedScene
	var root: Node3D = ps.instantiate() as Node3D
	var sk: Skeleton3D = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var mi: MeshInstance3D = root.find_child("hand_glove", true, false) as MeshInstance3D
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	print("mesh verts=", verts.size(), " mesh xf=", mi.transform, " sk xf=", sk.transform)
	for bone_name: String in ["forearm", "wrist", "index_1", "middle_1", "ring_1", "pinky_1"]:
		var i: int = sk.find_bone(bone_name)
		var g: Transform3D = sk.get_bone_global_rest(i)
		var inv: Transform3D = g.affine_inverse()
		var length: float = 0.05
		for c: int in sk.get_bone_children(i):
			length = sk.get_bone_rest(c).origin.length()
			break
		print("== ", bone_name, " global_origin=", g.origin, " basis_x=", g.basis.x, " basis_y=", g.basis.y, " basis_z=", g.basis.z, " child_len=", length)
		for frac: float in [0.2, 0.5, 0.8]:
			var ymid: float = length * frac
			var minv: Vector3 = Vector3(1e9, 1e9, 1e9)
			var maxv: Vector3 = Vector3(-1e9, -1e9, -1e9)
			var n: int = 0
			for v: Vector3 in verts:
				var l: Vector3 = inv * (mi.transform * v)
				if absf(l.y - ymid) < 0.004:
					minv = minv.min(l)
					maxv = maxv.max(l)
					n += 1
			print("   y=%.3f n=%d  x:[%.4f %.4f] z:[%.4f %.4f]" % [ymid, n, minv.x, maxv.x, minv.z, maxv.z])
	var cp: Node3D = root.find_child("contact_palm", true, false) as Node3D
	var gw: Transform3D = sk.get_bone_global_rest(sk.find_bone("wrist"))
	print("contact_palm in wrist space: ", gw.affine_inverse() * (cp.transform.origin))
	quit()
