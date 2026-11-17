extends GutTest
## La mano con guante (hand.glb) y sus poses. Fija la convención de signo de HandRig (positivo =
## cierra hacia la palma) contra el modelo exportado, y que el contacto quede en el origen.


func _rig(pose: String) -> HandRig:
	var rig: HandRig = HandRig.new()
	rig.setup(pose, StandardMaterial3D.new())
	add_child_autofree(rig)
	return rig


func _bone_pos(rig: HandRig, bone: String) -> Vector3:
	var sk: Skeleton3D = rig.skeleton
	return sk.get_bone_global_pose(sk.find_bone(bone)).origin # espacio del esqueleto


func test_point_pose_closes_fingers_toward_palm() -> void:
	var open: HandRig = _rig("palm")
	var point: HandRig = _rig("point")
	var open_tip: Vector3 = _bone_pos(open, "middle_3")
	var closed_tip: Vector3 = _bone_pos(point, "middle_3")
	# La palma mira hacia -Y (abajo): al cerrar, la falange baja y vuelve hacia la muñeca (+Z).
	assert_lt(closed_tip.y, open_tip.y - 0.01, "el medio se cierra hacia la palma, no hacia el dorso")
	assert_gt(closed_tip.z, open_tip.z + 0.01, "y vuelve hacia la muñeca")


func test_index_stays_extended_in_point_pose() -> void:
	var open: HandRig = _rig("palm")
	var point: HandRig = _rig("point")
	assert_lt(_bone_pos(open, "index_3").distance_to(_bone_pos(point, "index_3")), 0.01)


func test_contact_points_come_from_the_model() -> void:
	var rig: HandRig = _rig("point")
	var model: Node3D = rig.get_child(0) as Node3D
	assert_not_null(model.find_child("contact_point", true, false), "el modelo trae contact_point")
	assert_not_null(model.find_child("contact_palm", true, false), "el modelo trae contact_palm")
	var tip: Vector3 = HandRig.contact_offset(model, "point")
	var palm: Vector3 = HandRig.contact_offset(model, "palm")
	assert_lt(tip.length(), 0.001, "el origen del modelo es la yema del índice")
	assert_gt(tip.distance_to(palm), 0.05, "la yema y la palma están separadas")


func test_ghost_hands_never_overlap() -> void:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0.2), Vector2(0.4, -0.3), Vector2(9, 9)])
	var act: PackedByteArray = PackedByteArray([1, 1, 1, 1])
	var out: PackedVector2Array = AutomationView.separate(pts, act, 2.4)
	for i: int in out.size():
		for j: int in range(i + 1, out.size()):
			assert_gt(out[i].distance_to(out[j]), 2.39, "manitos %d y %d separadas" % [i, j])
	assert_eq(out[3], Vector2(9, 9), "las que ya estaban lejos no se mueven")
