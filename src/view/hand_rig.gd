class_name HandRig
extends Node3D
## La mano con guante (hand.glb) y sus poses: "point" (señalar), "palm" (palma abierta) y "grab"
## (agarrar). Los ángulos son rotaciones de cada falange alrededor de su eje X local (positivo =
## cierra hacia la palma). La pulsación flexiona la última falange del índice bajo la fuerza.
## El nodo queda con la punta del índice (o el centro de la palma) en el origen, y la escala
## del mundo la pone quien lo usa.

const MODEL: String = "res://assets/models/hand.glb"
const MODEL_GHOST: String = "res://assets/models/hand_ghost.glb"
const FINGERS: Array[String] = ["index", "middle", "ring", "pinky"]
const ACCESSORIES: String = "res://assets/models/accessories.glb"
## Dónde va cada accesorio, en el marco del hueso (Y = eje del dedo o del antebrazo, Z = dorso).
const RING_Y: Dictionary = {"index": 0.032, "middle": 0.030, "ring": 0.026}
const WRIST_Y: Dictionary = {"bracelet": -0.006, "watch": -0.026, "glove": -0.052}
static var _acc_scene: PackedScene


## Ángulos (grados) por dedo: [metacarpo, falange 1, 2, 3]; el pulgar tiene tres valores.
static func pose_data(name: String) -> Dictionary[String, PackedFloat32Array]:
	var d: Dictionary[String, PackedFloat32Array] = {}
	match name:
		"palm":
			for f: String in FINGERS:
				d[f] = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			d["thumb"] = PackedFloat32Array([0.0, 0.0, 0.0])
		"grab":
			d["index"] = PackedFloat32Array([0.0, 36.0, 50.0, 30.0])
			d["middle"] = PackedFloat32Array([0.0, 40.0, 54.0, 30.0])
			d["ring"] = PackedFloat32Array([0.0, 42.0, 56.0, 30.0])
			d["pinky"] = PackedFloat32Array([0.0, 44.0, 58.0, 30.0])
			d["thumb"] = PackedFloat32Array([22.0, 32.0, 26.0])
		_:
			d["index"] = PackedFloat32Array([0.0, 2.0, 4.0, 2.0])
			d["middle"] = PackedFloat32Array([0.0, 40.0, 72.0, 30.0])
			d["ring"] = PackedFloat32Array([0.0, 42.0, 74.0, 30.0])
			d["pinky"] = PackedFloat32Array([0.0, 44.0, 76.0, 30.0])
			d["thumb"] = PackedFloat32Array([8.0, 14.0, 10.0]) # apenas flexionado...
			d["thumb_spread"] = PackedFloat32Array([THUMB_TUCK]) # ...y pegado al costado de los dedos cerrados
	return d


## Aducción del pulgar en "señalar" (grados): se pega al costado de los dedos cerrados en vez de
## apuntar a la lámina (sin esto la mano se leía como una pistola de dos caños).
const THUMB_TUCK: float = 38.0

var pose_name: String = "point"
var skeleton: Skeleton3D
var mesh: MeshInstance3D

var _bones: Dictionary[String, int] = {} ## nombre -> índice
var _angle: Dictionary[String, float] = {} ## nombre -> grados actuales
var _target: Dictionary[String, float] = {}
var _model: Node3D
var _press: float = 0.0
var _pose_rate: float = 18.0


func setup(pose: String, material: Material) -> void:
	var ps: PackedScene = load(MODEL_GHOST if material is ShaderMaterial else MODEL) as PackedScene
	var model: Node3D = ps.instantiate() as Node3D
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	mesh = model.find_child("hand_glove", true, false) as MeshInstance3D
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if material is ShaderMaterial else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i: int in skeleton.get_bone_count():
		_bones[skeleton.get_bone_name(i)] = i
	_model = model
	set_pose(pose, true)
	if not (material is ShaderMaterial): # las manitos fantasma no llevan accesorios: son ayudantes, no la mano del jugador
		attach_accessories(ToolMeshes.equipped, material)


## Pone los accesorios equipados en la mano del jugador (BoneAttachment3D: siguen a los huesos) y, con
## guante, cambia el material y la forma de la mano. `equipped`: ranura -> id (ver Accessories.SLOTS).
func attach_accessories(equipped: Dictionary, material: Material) -> void:
	if equipped.is_empty():
		return
	if _acc_scene == null:
		_acc_scene = load(ACCESSORIES) as PackedScene
	var lib: Node3D = _acc_scene.instantiate() as Node3D
	for slot: String in equipped:
		var id: String = str(equipped[slot])
		var src: MeshInstance3D = lib.find_child(id, true, false) as MeshInstance3D
		if src == null:
			continue
		var holder: BoneAttachment3D = BoneAttachment3D.new()
		holder.name = "acc_" + slot
		var bone: String = "wrist"
		var y: float = 0.0
		if slot.begins_with("ring"):
			var finger: String = Accessories.RING_FINGERS[int(slot.substr(4))]
			bone = finger + "_1"
			y = RING_Y[finger]
		else:
			y = WRIST_Y[slot]
		holder.bone_name = bone
		skeleton.add_child(holder)
		var piece: MeshInstance3D = src.duplicate() as MeshInstance3D
		piece.position = Vector3(0.0, y, 0.0)
		piece.scale = Vector3.ONE * ACC_SCALE # 1,4 veces el tamaño real: se leen desde la cámara de juego
		_make_vivid(piece)
		holder.add_child(piece)
		_sparkle(holder, piece)
		if slot == "glove":
			_dress_glove(id, material)
	lib.free()


const ACC_SCALE: float = 1.4


## Colores más saturados y con algo de brillo propio.
func _make_vivid(piece: MeshInstance3D) -> void:
	var mesh_res: Mesh = piece.mesh
	for i: int in mesh_res.get_surface_count():
		var base: StandardMaterial3D = mesh_res.surface_get_material(i) as StandardMaterial3D
		if base == null:
			continue
		var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
		var c: Color = m.albedo_color
		m.albedo_color = Color.from_hsv(c.h, minf(c.s * 1.35 + 0.1, 1.0), minf(c.v * 1.1 + 0.05, 1.0), c.a)
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.35
		piece.set_surface_override_material(i, m)


## Un destello corto cada tanto (más rápido si la mano se mueve: el brillo se renueva al agarrar o soltar).
func _sparkle(holder: Node, piece: MeshInstance3D) -> void:
	var tw: Tween = holder.create_tween().set_loops()
	tw.tween_interval(randf_range(0.6, 1.8))
	tw.tween_callback(func() -> void: _flash_piece(piece, 1.4))
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: _flash_piece(piece, 0.35))
	tw.tween_interval(1.6)


func _flash_piece(piece: MeshInstance3D, energy: float) -> void:
	if not is_instance_valid(piece):
		return
	for i: int in piece.mesh.get_surface_count():
		var m: StandardMaterial3D = piece.get_surface_override_material(i) as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = energy


## Guante: la mano toma el color del material del guante y, si es de lana, engorda un poco.
func _dress_glove(id: String, material: Material) -> void:
	var sm: StandardMaterial3D = material as StandardMaterial3D
	if sm != null:
		var tint: Dictionary = {"glove_cocina": Color("#E5392E"), "glove_lana": Color("#F08A2E"), "glove_latex": Color("#FFD81F")}
		var c: Color = tint.get(id, Color.WHITE)
		sm.albedo_color = Color.WHITE.lerp(c, 0.92) # toda la mano cambia de color, bien visible
		sm.emission = c.lerp(Color("#B98467"), 0.5)
	if id == "glove_lana":
		mesh.scale = Vector3(1.06, 1.0, 1.06)


func _ready() -> void:
	_place(_model)


## Deja el contacto de la pose en el origen: la yema del índice ("point") o el centro de la palma.
## Los puntos vienen en el modelo como nodos vacíos (contact_point y contact_palm, ver art/models/hand.py).
func _place(model: Node3D) -> void:
	model.position = -contact_offset(model, pose_name)


static func contact_offset(model: Node3D, pose: String) -> Vector3:
	var node: Node3D = model.find_child("contact_point" if pose == "point" else "contact_palm", true, false) as Node3D
	return node.position if node != null else Vector3.ZERO


func set_pose(name: String, immediate: bool = false) -> void:
	pose_name = name
	var pose: Dictionary[String, PackedFloat32Array] = pose_data(name)
	for f: String in FINGERS:
		var a: PackedFloat32Array = pose[f]
		for k: int in 4:
			_target["%s_%s" % [f, "meta" if k == 0 else str(k)]] = a[k]
	var th: PackedFloat32Array = pose["thumb"]
	for k: int in 3:
		_target["thumb_%d" % (k + 1)] = th[k]
	_target["thumb_spread"] = pose["thumb_spread"][0] if pose.has("thumb_spread") else 0.0
	if immediate:
		_angle = _target.duplicate()
		_apply()


## 0 suelto .. 1 apretando: la última falange del índice se flexiona.
func set_press(p: float) -> void:
	_press = p


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-_pose_rate * delta)
	for key: String in _target:
		var cur: float = _angle[key] if _angle.has(key) else 0.0
		_angle[key] = lerpf(cur, _target[key], k)
	_apply()


func _apply() -> void:
	if skeleton == null:
		return
	for key: String in _angle:
		if key == "thumb_spread":
			continue
		var deg: float = _angle[key]
		if pose_name == "point":
			if key == "index_3":
				deg += 34.0 * _press
			elif key == "index_2":
				deg += 12.0 * _press
			elif key == "index_1":
				deg += 6.0 * _press
		elif pose_name == "palm" and key.ends_with("_1"):
			deg += 5.0 * _press
		var rest: Quaternion = skeleton.get_bone_rest(_bones[key]).basis.get_rotation_quaternion()
		# En los huesos exportados, +X local dobla hacia el dorso: se invierte para que los ángulos
		# de pose_data (positivo = cierra hacia la palma) se cumplan (test_hand_rig lo verifica).
		var q: Quaternion = rest * Quaternion(Vector3.RIGHT, -deg_to_rad(deg))
		if key == "thumb_1":
			var spread: float = _angle.get("thumb_spread", 0.0)
			q = q * Quaternion(Vector3.FORWARD, deg_to_rad(spread)) # sentido fijado por test_hand_rig
		skeleton.set_bone_pose_rotation(_bones[key], q)
