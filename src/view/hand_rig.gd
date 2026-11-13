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
			d["middle"] = PackedFloat32Array([0.0, 50.0, 62.0, 28.0])
			d["ring"] = PackedFloat32Array([0.0, 52.0, 64.0, 28.0])
			d["pinky"] = PackedFloat32Array([0.0, 54.0, 66.0, 28.0])
			d["thumb"] = PackedFloat32Array([28.0, 24.0, 14.0])
	return d


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


func _ready() -> void:
	_place(_model)


## Deja el contacto de la pose en el origen: la punta del índice, o el centro de la palma.
## Las coordenadas salen de la malla importada (la punta del índice queda en z = 0,1538 y la
## malla está corrida 0,0265 en x respecto de la muñeca).
func _place(model: Node3D) -> void:
	var contact: Vector3 = Vector3(0.0, -0.0064, 0.1603)
	if pose_name != "point":
		contact = Vector3(0.0265, -0.0257, 0.279)
	model.position = -contact


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
		skeleton.set_bone_pose_rotation(_bones[key], rest * Quaternion(Vector3.RIGHT, deg_to_rad(deg)))
