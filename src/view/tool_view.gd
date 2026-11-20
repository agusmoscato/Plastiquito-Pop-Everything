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
var _rig: HandRig
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
## Tamaño en pantalla (DESIGN 5): con la cámara del juego (`rig`), la herramienta ocupa una fracción fija
## del alto de la pantalla (`tool_screen_fraction` en juice.json), aunque la cámara se aleje con la lámina.
var rig: CameraRig
var screen_fraction: Dictionary = {}
var _base_screen_h: float = 0.0
var _screen_scale: float = 1.0


func configure(juice: Dictionary) -> void:
	hover_height = Cfg.num(juice, "finger_hover_height")
	press_depth = Cfg.num(juice, "finger_press_depth")
	stiffness = Cfg.num(juice, "finger_spring_stiffness")
	damping = Cfg.num(juice, "finger_spring_damping")
	bounce_impulse = Cfg.num(juice, "finger_bounce_impulse")
	if juice.has("tool_screen_fraction"):
		screen_fraction = juice["tool_screen_fraction"]


## Define qué herramienta se muestra, su tamaño en el mundo, el hito (color) y la velocidad (0..1).
func set_tool(id: String, p_radius: float, p_tier: int, speed01: float, force_ratio: float = 1.0) -> void:
	var key: String = "%s|%.2f|%d|%s" % [id, p_radius, p_tier, ToolMeshes.equipped_signature()]
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
	_rig = null
	for n: Node in _holder.find_children("*", "Node3D", true, false):
		if n is HandRig:
			_rig = n as HandRig
	_base_screen_h = screen_height_of(_body)
	if id == "iron":
		_holder.add_child(_make_heat_aura(p_radius))
		_holder.add_child(_make_steam(p_radius))
	if grew:
		_grow = 0.55 # vuelve a 1 con rebote: se ve crecer


## Aura de calor de la plancha: un rectángulo anaranjado translúcido que pulsa sobre la lámina.
func _make_heat_aura(half: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Heat"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(half * 2.0 * 1.6, half * 0.9 * 1.6)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.55, 0.2, 0.35)
	m.albedo_texture = FxPool.soft_dot() # resplandor de calor con bordes suaves (el rectángulo parecía de depuración)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.1)
	m.emission_energy_multiplier = 0.8
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.material = m
	mi.mesh = pm
	mi.position = Vector3(0.0, -0.6, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Vapor que sale de la suela de la plancha: soplos blancos que suben y se abren.
func _make_steam(half: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Steam"
	p.amount = 36
	p.lifetime = 1.1
	p.local_coords = false
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(half * 0.9, 0.05, half * 0.35)
	proc.direction = Vector3.UP
	proc.spread = 25.0
	proc.initial_velocity_min = 0.6
	proc.initial_velocity_max = 1.4
	proc.gravity = Vector3(0.0, 0.4, 0.0)
	proc.scale_min = 0.8
	proc.scale_max = 2.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.2, Color(1.0, 1.0, 1.0, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = ramp
	proc.color_ramp = gt
	p.process_material = proc
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.5, 0.5) * maxf(1.0, half * 0.35)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.95, 0.97, 1.0, 1.0)
	m.albedo_texture = FxPool.soft_dot() # nubecitas redondas (sin textura eran cuadrados blancos)
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, -0.55, 0.0)
	return p


## Alto que ocupa en pantalla un modelo visto con la cámara inclinada del juego (en unidades del mundo).
static func screen_height_of(node: Node3D) -> float:
	var p: float = deg_to_rad(CameraRig.PITCH_DEGREES)
	var up: Vector3 = Vector3(0.0, cos(p), -sin(p)) # el eje vertical de la pantalla, en el mundo
	var span: Vector2 = Vector2(INF, -INF)
	span = _project_span(node, Transform3D.IDENTITY, up, span)
	return maxf(span.y - span.x, 0.0)


## Mínimo y máximo de los vértices de las mallas proyectados sobre `axis` (vértices reales, no la
## caja: con la mano girada 55° la caja inflaba la altura 2-3 veces y la mano quedaba chica).
static func _project_span(node: Node, xf: Transform3D, axis: Vector3, span: Vector2) -> Vector2:
	var out: Vector2 = span
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			for si: int in mesh.get_surface_count():
				var verts: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				var step: int = maxi(1, verts.size() / 4000)
				for vi: int in range(0, verts.size(), step):
					var d: float = (xf * verts[vi]).dot(axis)
					out = Vector2(minf(out.x, d), maxf(out.y, d))
	for c: Node in node.get_children():
		var ct: Transform3D = xf
		if c is Node3D:
			ct = xf * (c as Node3D).transform
		out = _project_span(c, ct, axis, out)
	return out


## Escala para que la herramienta ocupe `fraction` del alto de la pantalla a la distancia `zoom`.
static func screen_scale_for(base_h: float, zoom: float, fraction: float) -> float:
	if base_h <= 0.0001:
		return 1.0
	var view_h: float = 2.0 * zoom * tan(deg_to_rad(CameraRig.FOV) * 0.5)
	return fraction * view_h / base_h


## Mueve el dedo a la posición (x, z) del plano.
func set_cursor(pos: Vector2) -> void:
	_target = pos


func snap_to(pos: Vector2) -> void:
	_target = pos
	position.x = pos.x
	position.z = pos.y


## Dirección del arrastre (el palo de amasar se orienta perpendicular a ella).
func set_drag_direction(dir: Vector2) -> void:
	if (tool_id == "rolling_pin" or tool_id == "iron") and dir.length_squared() > 0.0001:
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
	rotation.y = _yaw if (tool_id == "rolling_pin" or tool_id == "iron") else 0.0
	_press = lerpf(_press, _press_target, 1.0 - exp(-_press_rate * delta))
	_squish_boost = maxf(0.0, _squish_boost - delta * 6.0)
	_grow = lerpf(_grow, 1.0, 1.0 - exp(-9.0 * delta))
	var spring: Vector2 = SpringMath.step(Vector2(_offset, _velocity), stiffness, damping, delta)
	_offset = spring.x
	_velocity = spring.y
	if rig != null:
		var frac: float = screen_fraction.get(tool_id, screen_fraction.get("default", 0.12))
		var want: float = screen_scale_for(_base_screen_h, rig.zoom_distance(), frac)
		_screen_scale = lerpf(_screen_scale, want, 1.0 - exp(-10.0 * delta))
	var hover: float = (hover_height + (0.35 if tool_id != "finger" else 0.0)) * _screen_scale
	# El rebote no crece con la escala de pantalla: en las fases 3-4 la escala llega a ~7 y el pisotón
	# mandaba la bota a la otra punta de la pantalla.
	var bounce_scale: float = minf(_screen_scale, 1.0)
	position.y = maxf(hover - press_depth * _depth_scale * _press * _screen_scale + _offset * bounce_scale, 0.02)
	if _rig != null:
		_rig.set_press(_press)
	if _body == null:
		return
	var squash: float = _press * 0.22 + _squish_boost * 0.08
	var stretch: float = clampf(_velocity * 0.03, -0.12, 0.18)
	var s: Vector3 = Vector3(1.0 + squash - stretch * 0.5, 1.0 - squash + stretch, 1.0 + squash - stretch * 0.5)
	_body.scale = s * _grow * _screen_scale
	var heat: Node3D = _holder.get_node_or_null("Heat") as Node3D
	if heat != null:
		var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		heat.scale = Vector3(pulse, 1.0, pulse)
		heat.position.y = -position.y + 0.04
