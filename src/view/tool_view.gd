class_name ToolView
extends Node3D
## El dedo: una cápsula de plástico de color que flota sobre el cursor. Al apretar baja y
## se aplasta (squash and stretch); al reventar una burbuja rebota con un resorte.

var hover_height: float = 0.9
var press_depth: float = 0.55
var stiffness: float = 260.0
var damping: float = 16.0
var bounce_impulse: float = 3.5

var _body: Node3D
var _offset: float = 0.0 ## desplazamiento vertical respecto de la altura de reposo
var _velocity: float = 0.0
var _press: float = 0.0 ## 0 suelto .. 1 apretando (suavizado)
var _press_target: float = 0.0
var _squish_boost: float = 0.0 ## aplastamiento extra al empezar a apretar


func _init() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.9
	capsule.radial_segments = 24
	capsule.rings = 8
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.52, 0.42)
	mat.roughness = 0.32
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.6
	capsule.material = mat
	mesh_node.mesh = capsule
	# La punta de la cápsula queda en el origen del cuerpo; se inclina hacia la cámara.
	mesh_node.position = Vector3(0.0, capsule.height * 0.5 - capsule.radius * 0.8, 0.0)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body.add_child(mesh_node)
	_body.rotation_degrees = Vector3(28.0, 0.0, 0.0)


func configure(juice: Dictionary) -> void:
	hover_height = Cfg.num(juice, "finger_hover_height")
	press_depth = Cfg.num(juice, "finger_press_depth")
	stiffness = Cfg.num(juice, "finger_spring_stiffness")
	damping = Cfg.num(juice, "finger_spring_damping")
	bounce_impulse = Cfg.num(juice, "finger_bounce_impulse")


## Mueve el dedo a la posición (x, z) del plano.
func set_cursor(pos: Vector2) -> void:
	position.x = pos.x
	position.z = pos.y


func set_pressing(pressing: bool) -> void:
	if pressing and _press_target < 0.5:
		_squish_boost = 1.0
	_press_target = 1.0 if pressing else 0.0


## Rebote al reventar una burbuja.
func bounce(strength: float = 1.0) -> void:
	_velocity += bounce_impulse * strength


func _process(delta: float) -> void:
	_press = lerpf(_press, _press_target, 1.0 - exp(-22.0 * delta))
	_squish_boost = maxf(0.0, _squish_boost - delta * 6.0)
	var accel: float = -stiffness * _offset - damping * _velocity
	_velocity += accel * delta
	_offset += _velocity * delta
	var y: float = hover_height - press_depth * _press + _offset
	position.y = maxf(y, 0.05)
	# Squash & stretch: apretado se ensancha y baja; al rebotar hacia arriba se estira.
	var squash: float = _press * 0.22 + _squish_boost * 0.08
	var stretch: float = clampf(_velocity * 0.03, -0.12, 0.18)
	_body.scale = Vector3(1.0 + squash - stretch * 0.5, 1.0 - squash + stretch, 1.0 + squash - stretch * 0.5)
