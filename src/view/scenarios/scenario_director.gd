class_name ScenarioDirector
extends Node
## Maneja el escenario de cada fase: piso procedural, objetos, luz, entorno y ambiente sonoro.
## apply() cambia de golpe; transition() hace el cambio suave (3-4 s): el piso se mezcla en el
## shader, la luz y el color de fondo se interpolan y los objetos nuevos crecen mientras los
## viejos se hunden, sin cortes.

## Luz y entorno por fase: Mesa cálida, Piso con luz de ventana, Galpón frío cenital y
## Estacionamiento con atardecer largo.
const SETTINGS: Array[Dictionary] = [
	{"rot": Vector3(-50.0, -30.0, 0.0), "color": Color("#FFC98C"), "energy": 1.0, "amb": Color("#E6C7A0"), "amb_e": 0.45, "bg": Color("#2A1D14"), "shadow": 80.0},
	{"rot": Vector3(-34.0, -68.0, 0.0), "color": Color("#FFF0C8"), "energy": 1.25, "amb": Color("#BFD0E0"), "amb_e": 0.5, "bg": Color("#8B9498"), "shadow": 100.0},
	{"rot": Vector3(-86.0, 0.0, 0.0), "color": Color("#CFE6FF"), "energy": 0.95, "amb": Color("#7F95B8"), "amb_e": 0.3, "bg": Color("#14181F"), "shadow": 140.0},
	{"rot": Vector3(-13.0, -112.0, 0.0), "color": Color("#FF8C3A"), "energy": 1.7, "amb": Color("#E6A28C"), "amb_e": 0.4, "bg": Color("#E9976A"), "shadow": 400.0},
]

## Cuánto más lejos se ve cada fase (la cámara se aleja con cada reciclado que abre fase).
const CAMERA_FACTOR: Array[float] = [1.0, 1.12, 1.3, 1.5]

var phase: int = 1
var props: Node3D

var _light: DirectionalLight3D
var _env: Environment
var _material: ShaderMaterial
var _center: Vector2 = Vector2.ZERO
var _extent: Vector2 = Vector2(20.0, 20.0)
var _from: Dictionary = {}
var _to: Dictionary = {}
var _t: float = 1.0
var _dur: float = 1.0
var _old_props: Node3D
var _new_props: Node3D


func setup(light: DirectionalLight3D, env: Environment, ground_material: ShaderMaterial) -> void:
	_light = light
	_env = env
	_material = ground_material


## Cambia de escenario de golpe.
func apply(new_phase: int, c: Vector2, e: Vector2) -> void:
	phase = clampi(new_phase, 1, 4)
	_center = c
	_extent = e
	_finish_transition()
	_clear_props()
	props = ScenarioProps.build(phase, c, e)
	add_child(props)
	_material.set_shader_parameter("kind_a", phase)
	_material.set_shader_parameter("kind_b", phase)
	_material.set_shader_parameter("blend", 0.0)
	_push(_settings_for(phase))
	_ambient()


## Cambio suave de escenario durante `seconds` segundos.
func transition(new_phase: int, seconds: float, c: Vector2, e: Vector2) -> void:
	var target: int = clampi(new_phase, 1, 4)
	if target == phase and not is_transitioning():
		return
	_finish_transition()
	_center = c
	_extent = e
	_from = _settings_for(phase)
	_to = _settings_for(target)
	_old_props = props
	_new_props = ScenarioProps.build(target, c, e)
	_new_props.scale = Vector3(1.0, 0.001, 1.0)
	add_child(_new_props)
	props = _new_props
	_material.set_shader_parameter("kind_a", phase)
	_material.set_shader_parameter("kind_b", target)
	_material.set_shader_parameter("blend", 0.0)
	phase = target
	_dur = maxf(seconds, 0.1)
	_t = 0.0
	_ambient()


## true si el escenario ya está en `p` con ese tamaño de lámina (no hace falta rearmarlo).
func matches(p: int, e: Vector2) -> bool:
	return phase == p and _extent == e and is_instance_valid(props) and not is_transitioning()


func is_transitioning() -> bool:
	return _t < 1.0


func camera_factor() -> float:
	return CAMERA_FACTOR[phase - 1]


func _process(delta: float) -> void:
	if _t >= 1.0:
		return
	_t = minf(1.0, _t + delta / _dur)
	var k: float = _t * _t * (3.0 - 2.0 * _t)
	_material.set_shader_parameter("blend", k)
	_push(_lerp_settings(_from, _to, k))
	var grow: float = clampf((k - 0.25) / 0.75, 0.0, 1.0)
	if is_instance_valid(_new_props):
		_new_props.scale = Vector3(1.0, maxf(grow, 0.001), 1.0)
	if is_instance_valid(_old_props):
		_old_props.scale = Vector3(1.0, maxf(1.0 - clampf(k / 0.5, 0.0, 1.0), 0.001), 1.0)
	if _t >= 1.0:
		_finish_transition()


func _finish_transition() -> void:
	if is_instance_valid(_old_props):
		_old_props.queue_free()
	_old_props = null
	if is_instance_valid(_new_props):
		_new_props.scale = Vector3.ONE
	_new_props = null
	_t = 1.0
	_material.set_shader_parameter("kind_a", phase)
	_material.set_shader_parameter("kind_b", phase)
	_material.set_shader_parameter("blend", 0.0)
	if not _to.is_empty():
		_push(_to)
		_to = {}


func _clear_props() -> void:
	if is_instance_valid(props):
		props.queue_free()
	props = null


func _settings_for(p: int) -> Dictionary:
	return SETTINGS[clampi(p, 1, 4) - 1]


func _lerp_settings(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var ra: Vector3 = a["rot"]
	var rb: Vector3 = b["rot"]
	var ca: Color = a["color"]
	var cb: Color = b["color"]
	var aa: Color = a["amb"]
	var ab: Color = b["amb"]
	var ba: Color = a["bg"]
	var bb: Color = b["bg"]
	return {
		"rot": ra.lerp(rb, k), "color": ca.lerp(cb, k),
		"energy": lerpf(Cfg.num(a, "energy"), Cfg.num(b, "energy"), k),
		"amb": aa.lerp(ab, k), "amb_e": lerpf(Cfg.num(a, "amb_e"), Cfg.num(b, "amb_e"), k),
		"bg": ba.lerp(bb, k), "shadow": lerpf(Cfg.num(a, "shadow"), Cfg.num(b, "shadow"), k),
	}


func _push(s: Dictionary) -> void:
	var rot: Vector3 = s["rot"]
	var color: Color = s["color"]
	var amb: Color = s["amb"]
	var bg: Color = s["bg"]
	_light.rotation_degrees = rot
	_light.light_color = color
	_light.light_energy = Cfg.num(s, "energy")
	_light.directional_shadow_max_distance = Cfg.num(s, "shadow")
	_env.ambient_light_color = amb
	_env.ambient_light_energy = Cfg.num(s, "amb_e")
	_env.background_color = bg


func _ambient() -> void:
	PopAudio.set_ambient(phase)
