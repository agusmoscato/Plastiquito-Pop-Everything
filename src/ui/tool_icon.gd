class_name ToolIcon
extends SubViewportContainer
## Ícono EN VIVO: la herramienta 3D real en un SubViewport chico, girando lento.
## No usa sets de íconos: es el mismo modelo que se ve en el mundo (ToolMeshes).

var kind: String = "finger"
var tier: int = 0

var _spin: Node3D
var _vp: SubViewport


func setup(p_kind: String, px: int, p_tier: int = 0) -> void:
	kind = p_kind
	tier = p_tier
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.size = Vector2i(px, px)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.93, 1.0)
	env.ambient_light_energy = 0.7
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 1.2
	_vp.add_child(light)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0.0, 2.4, 3.6)
	cam.rotation_degrees = Vector3(-26.0, 0.0, 0.0)
	_vp.add_child(cam)
	_spin = Node3D.new()
	_vp.add_child(_spin)
	_spin.add_child(_make_model())
	_spin.position = Vector3(0.0, 0.1, 0.0)


func set_tier(p_tier: int) -> void:
	if p_tier == tier or _spin == null:
		return
	tier = p_tier
	for c: Node in _spin.get_children():
		c.queue_free()
	_spin.add_child(_make_model())


func _make_model() -> Node3D:
	if kind == "bubble":
		var root: Node3D = Node3D.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = BubbleMesh.build(1.0, 0.9, 10, 24)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.82, 1.0, 0.65)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.rim_enabled = true
		m.rim = 0.8
		mi.material_override = m
		root.add_child(mi)
		return root
	var model: Node3D = ToolMeshes.build(kind, 1.2, tier)
	return model


func _process(delta: float) -> void:
	if _spin != null:
		_spin.rotation.y += delta * 0.8
