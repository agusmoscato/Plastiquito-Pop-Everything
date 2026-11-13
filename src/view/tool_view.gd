class_name ToolView
extends Node3D
## La herramienta en el mundo (dedo, palma o palo de amasar) flotando sobre el cursor.
## Al apretar baja y se aplasta (squash and stretch); al reventar rebota con un resorte.
## Las mejoras se ven acá: el tamaño la agranda, la velocidad hace que siga el cursor más
## rápido y cada hito de 25 niveles le cambia el color o el material.

var hover_height: float = 0.9
var press_depth: float = 0.55
var stiffness: float = 260.0
var damping: float = 16.0
var bounce_impulse: float = 3.5

var tool_id: String = "finger"
var radius: float = 0.0
var tier: int = 0

var _holder: Node3D
var _body: Node3D
var _offset: float = 0.0 ## desplazamiento vertical respecto de la altura de reposo
var _velocity: float = 0.0
var _press: float = 0.0 ## 0 suelto .. 1 apretando (suavizado)
var _press_target: float = 0.0
var _squish_boost: float = 0.0
var _target: Vector2 = Vector2.ZERO
var _follow: float = 30.0
var _grow: float = 1.0 ## animación de "crece" al subir de tamaño
var _yaw: float = 0.0
var _yaw_target: float = 0.0
var _built_key: String = ""
var _press_rate: float = 22.0
var _depth_scale: float = 1.0


func configure(juice: Dictionary) -> void:
	hover_height = Cfg.num(juice, "finger_hover_height")
	press_depth = Cfg.num(juice, "finger_press_depth")
	stiffness = Cfg.num(juice, "finger_spring_stiffness")
	damping = Cfg.num(juice, "finger_spring_damping")
	bounce_impulse = Cfg.num(juice, "finger_bounce_impulse")


## Define qué herramienta se muestra, su tamaño en el mundo, el hito (color) y la velocidad (0..1).
func set_tool(id: String, p_radius: float, p_tier: int, speed01: float, force_ratio: float = 1.0) -> void:
	var key: String = "%s|%.2f|%d" % [id, p_radius, p_tier]
	_follow = lerpf(16.0, 60.0, clampf(speed01, 0.0, 1.0))
	_press_rate = 22.0 * clampf(0.8 + 0.12 * force_ratio, 0.8, 2.2) # más fuerza: aprieta más rápido y más hondo
	_depth_scale = clampf(0.85 + 0.05 * force_ratio, 0.85, 1.25)
	if key == _built_key:
		return
	var grew: bool = id == tool_id and p_radius > radius
	tool_id = id
	radius = p_radius
	tier = p_tier
	_built_key = key
	if _holder != null:
		_holder.queue_free()
	_holder = ToolMeshes.build(id, p_radius, p_tier)
	add_child(_holder)
	_body = _holder.get_node("Body") as Node3D
	if grew:
		_grow = 0.55 # vuelve a 1 con rebote: se ve crecer


## Mueve el dedo a la posición (x, z) del plano.
func set_cursor(pos: Vector2) -> void:
	_target = pos


func snap_to(pos: Vector2) -> void:
	_target = pos
	position.x = pos.x
	position.z = pos.y


## Dirección del arrastre (el palo de amasar se orienta perpendicular a ella).
func set_drag_direction(dir: Vector2) -> void:
	if tool_id == "rolling_pin" and dir.length_squared() > 0.0001:
		var n: Vector2 = Vector2(-dir.y, dir.x).normalized()
		_yaw_target = atan2(-n.y, n.x)


func set_pressing(pressing: bool) -> void:
	if pressing and _press_target < 0.5:
		_squish_boost = 1.0
	_press_target = 1.0 if pressing else 0.0


## Rebote al reventar una burbuja.
func bounce(strength: float = 1.0) -> void:
	_velocity += bounce_impulse * strength


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-_follow * delta)
	position.x = lerpf(position.x, _target.x, k)
	position.z = lerpf(position.z, _target.y, k)
	_yaw = lerp_angle(_yaw, _yaw_target, 1.0 - exp(-14.0 * delta))
	rotation.y = _yaw if tool_id == "rolling_pin" else 0.0
	_press = lerpf(_press, _press_target, 1.0 - exp(-_press_rate * delta))
	_squish_boost = maxf(0.0, _squish_boost - delta * 6.0)
	_grow = lerpf(_grow, 1.0, 1.0 - exp(-9.0 * delta))
	var accel: float = -stiffness * _offset - damping * _velocity
	_velocity += accel * delta
	_offset += _velocity * delta
	var hover: float = hover_height + (0.35 if tool_id != "finger" else 0.0)
	position.y = maxf(hover - press_depth * _depth_scale * _press + _offset, 0.05)
	if _body == null:
		return
	var squash: float = _press * 0.22 + _squish_boost * 0.08
	var stretch: float = clampf(_velocity * 0.03, -0.12, 0.18)
	var s: Vector3 = Vector3(1.0 + squash - stretch * 0.5, 1.0 - squash + stretch, 1.0 + squash - stretch * 0.5)
	_body.scale = s * _grow
