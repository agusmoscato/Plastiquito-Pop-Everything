class_name EchoGlow
extends Node3D
## Eco (DESIGN 3.4): antes de volver a inflarse, la burbuja reventada brilla y late cada vez más
## rápido; al reinflarse suena el aire (main.gd). Solo lee los Ecos pendientes de GameSim.

const WARN_SECONDS: float = 1.4 ## cuánto antes de reinflarse empieza a brillar
const MAX_GLOWS: int = 24

var sim: GameSim
var _pool: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D


func bind(p_sim: GameSim) -> void:
	sim = p_sim


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(0.75, 1.0, 0.85, 0.55)
	_mat.emission_enabled = true
	_mat.emission = Color(0.55, 1.0, 0.75)
	_mat.emission_energy_multiplier = 2.2
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.42
	sphere.radial_segments = 16
	sphere.rings = 6
	for i: int in MAX_GLOWS:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_pool.append(mi)


## Intensidad del latido (0..1) cuando faltan `left` segundos para reinflarse: late más rápido al final.
static func pulse(left: float, time_s: float) -> float:
	if left > WARN_SECONDS or left < 0.0:
		return 0.0
	var k: float = 1.0 - left / WARN_SECONDS
	var freq: float = lerpf(2.0, 9.0, k)
	return k * (0.55 + 0.45 * sin(time_s * TAU * freq))


func _process(_delta: float) -> void:
	if sim == null:
		return
	var echoes: Array[Vector2] = sim.pending_echoes()
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var used: int = 0
	for e: Vector2 in echoes:
		if used >= MAX_GLOWS:
			break
		var p: float = pulse(e.y, now)
		if p <= 0.0:
			continue
		var w: Vector2 = sim.grid.cell_to_world(int(e.x))
		var mi: MeshInstance3D = _pool[used]
		mi.visible = true
		mi.position = Vector3(w.x, 0.18, w.y)
		mi.scale = Vector3.ONE * (0.6 + 0.6 * p)
		used += 1
	for i: int in range(used, _pool.size()):
		_pool[i].visible = false
